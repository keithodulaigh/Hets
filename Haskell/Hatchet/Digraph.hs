
module Haskell.Hatchet.Digraph(

	-- At present the only one with a "nice" external interface
	stronglyConnComp, stronglyConnCompR, SCC(..),

	Graph, Vertex, Edge,
	graphFromEdges, buildG, transposeG, reverseE, outdegree, indegree,

	Tree(..), Forest,
	showTree, showForest, preorder,

	dfs, dff,
	topSort,
	components,
	scc,
	back, cross, forward,
	reachable, path,
	bcc

    ) where

-- \# include "HsVersions.h"

------------------------------------------------------------------------------
-- A version of the graph algorithms described in:
-- 
-- ``Lazy Depth-First Search and Linear Graph Algorithms in Haskell''
--   by David King and John Launchbury
-- 
-- Also included is some additional code for printing tree structures ...
------------------------------------------------------------------------------


-- \#define ARR_ELT		(COMMA)

-- import Util	( sortLt )

-- Extensions
import GHC.Arr
import Control.Monad.ST

-- std interfaces
import Data.Maybe
import Data.Array
import Data.List










data SCC vertex = AcyclicSCC vertex
	        | CyclicSCC  [vertex]

stronglyConnComp
	:: Ord key
	=> [(node, key, [key])]		-- The graph; its ok for the
					-- out-list to contain keys which arent
					-- a vertex key, they are ignored
	-> [SCC node]

stronglyConnComp edges
  = map get_node (stronglyConnCompR edges)
  where
    get_node (AcyclicSCC (n, _, _)) = AcyclicSCC n
    get_node (CyclicSCC triples)     = CyclicSCC [n | (n,_,_) <- triples]

-- The "R" interface is used when you expect to apply SCC to
-- the (some of) the result of SCC, so you dont want to lose the dependency info
stronglyConnCompR
	:: Ord key
	=> [(node, key, [key])]		-- The graph; its ok for the
					-- out-list to contain keys which arent
					-- a vertex key, they are ignored
	-> [SCC (node, key, [key])]

stronglyConnCompR [] = []  -- added to avoid creating empty array in graphFromEdges -- SOF
stronglyConnCompR edges
  = map decode forest
  where
    (graph, vertex_fn) = graphFromEdges edges
    forest	       = scc graph
    decode (Node v []) | mentions_itself v = CyclicSCC [vertex_fn v]
		       | otherwise	   = AcyclicSCC (vertex_fn v)
    decode other = CyclicSCC (dec other [])
		 where
		   dec (Node v ts) vs = vertex_fn v : foldr dec vs ts
    mentions_itself v = v `elem` (graph ! v)










type Vertex  = Int
type Table a = Array Vertex a
type Graph   = Table [Vertex]
type Bounds  = (Vertex, Vertex)
type Edge    = (Vertex, Vertex)



vertices :: Graph -> [Vertex]
vertices  = indices

edges    :: Graph -> [Edge]
edges g   = [ (v, w) | v <- vertices g, w <- g!v ]

mapT    :: (Vertex -> a -> b) -> Table a -> Table b
mapT f t = array (bounds t) [ (,) v (f v (t!v)) | v <- indices t ]

buildG :: Bounds -> [Edge] -> Graph
buildG bounds edges = accumArray (flip (:)) [] bounds edges

transposeG  :: Graph -> Graph
transposeG g = buildG (bounds g) (reverseE g)

reverseE    :: Graph -> [Edge]
reverseE g   = [ (w, v) | (v, w) <- edges g ]

outdegree :: Graph -> Table Int
outdegree  = mapT numEdges
             where numEdges v ws = length ws

indegree :: Graph -> Table Int
indegree  = outdegree . transposeG




graphFromEdges
	:: Ord key
	=> [(node, key, [key])]
	-> (Graph, Vertex -> (node, key, [key]))
graphFromEdges edges
  = (graph, \v -> vertex_map ! v)
  where
    max_v      	    = length edges - 1
    bounds          = (0,max_v) :: (Vertex, Vertex)
    sorted_edges    = sortLt lt edges
    edges1	    = zipWith (,) [0..] sorted_edges

    graph	    = array bounds [(,) v (mapMaybe key_vertex ks) | (,) v (_,    _, ks) <- edges1]
    key_map	    = array bounds [(,) v k			   | (,) v (_,    k, _ ) <- edges1]
    vertex_map	    = array bounds edges1

    (_,k1,_) `lt` (_,k2,_) = case k1 `compare` k2 of { LT -> True; other -> False }

    -- key_vertex :: key -> Maybe Vertex
    -- 	returns Nothing for non-interesting vertices
    key_vertex k   = find 0 max_v 
		   where
		     find a b | a > b 
			      = Nothing
		     find a b = case compare k (key_map ! mid) of
				   LT -> find a (mid-1)
				   EQ -> Just mid
				   GT -> find (mid+1) b
			      where
			 	mid = (a + b) `div` 2









data Tree a   = Node a (Forest a)
type Forest a = [Tree a]

mapTree              :: (a -> b) -> (Tree a -> Tree b)
mapTree f (Node x ts) = Node (f x) (map (mapTree f) ts)



instance Show a => Show (Tree a) where
  showsPrec p t s = showTree t ++ s

showTree :: Show a => Tree a -> String
showTree  = drawTree . mapTree show

showForest :: Show a => Forest a -> String
showForest  = unlines . map showTree

drawTree        :: Tree String -> String
drawTree         = unlines . draw

draw (Node x ts) = grp this (space (length this)) (stLoop ts)
 where this          = s1 ++ x ++ " "

       space n       = take n (repeat ' ')

       stLoop []     = [""]
       stLoop [t]    = grp s2 "  " (draw t)
       stLoop (t:ts) = grp s3 s4 (draw t) ++ [s4] ++ rsLoop ts

       rsLoop [t]    = grp s5 "  " (draw t)
       rsLoop (t:ts) = grp s6 s4 (draw t) ++ [s4] ++ rsLoop ts

       grp fst rst   = zipWith (++) (fst:repeat rst)

       [s1,s2,s3,s4,s5,s6] = ["- ", "--", "-+", " |", " `", " +"]










type Set s    = STArray s Vertex Bool

mkEmpty      :: Bounds -> ST s (Set s)
mkEmpty bnds  = newSTArray bnds False

contains     :: Set s -> Vertex -> ST s Bool
contains m v  = readSTArray m v

include      :: Set s -> Vertex -> ST s ()
include m v   = writeSTArray m v True



dff          :: Graph -> Forest Vertex
dff g         = dfs g (vertices g)

dfs          :: Graph -> [Vertex] -> Forest Vertex
dfs g vs      = prune (bounds g) (map (generate g) vs)

generate     :: Graph -> Vertex -> Tree Vertex
generate g v  = Node v (map (generate g) (g!v))

prune        :: Bounds -> Forest Vertex -> Forest Vertex
prune bnds ts = runST (mkEmpty bnds  >>= \m ->
                       chop m ts)

chop         :: Set s -> Forest Vertex -> ST s (Forest Vertex)
chop m []     = return []
chop m (Node v ts : us)
              = contains m v >>= \visited ->
                if visited then
                  chop m us
                else
                  include m v >>= \_  ->
                  chop m ts   >>= \as ->
                  chop m us   >>= \bs ->
                  return (Node v as : bs)














--preorder            :: Tree a -> [a]
preorder (Node a ts) = a : preorderF ts

preorderF           :: Forest a -> [a]
preorderF ts         = concat (map preorder ts)

preOrd :: Graph -> [Vertex]
preOrd  = preorderF . dff

tabulate        :: Bounds -> [Vertex] -> Table Int
tabulate bnds vs = array bnds (zipWith (,) vs [1..])

preArr          :: Bounds -> Forest Vertex -> Table Int
preArr bnds      = tabulate bnds . preorderF








--postorder :: Tree a -> [a]
postorder (Node a ts) = postorderF ts ++ [a]

postorderF   :: Forest a -> [a]
postorderF ts = concat (map postorder ts)

postOrd      :: Graph -> [Vertex]
postOrd       = postorderF . dff

topSort      :: Graph -> [Vertex]
topSort       = reverse . postOrd








components   :: Graph -> Forest Vertex
components    = dff . undirected

undirected   :: Graph -> Graph
undirected g  = buildG (bounds g) (edges g ++ reverseE g)






scc  :: Graph -> Forest Vertex
scc g = dfs g (reverse (postOrd (transposeG g)))








tree              :: Bounds -> Forest Vertex -> Graph
tree bnds ts       = buildG bnds (concat (map flat ts))
		   where
		     flat (Node v rs) = [ (v, w) | Node w us <- ts ] ++
                    		        concat (map flat ts)

back              :: Graph -> Table Int -> Graph
back g post        = mapT select g
 where select v ws = [ w | w <- ws, post!v < post!w ]

cross             :: Graph -> Table Int -> Table Int -> Graph
cross g pre post   = mapT select g
 where select v ws = [ w | w <- ws, post!v > post!w, pre!v > pre!w ]

forward           :: Graph -> Graph -> Table Int -> Graph
forward g tree pre = mapT select g
 where select v ws = [ w | w <- ws, pre!v < pre!w ] \\ tree!v








reachable    :: Graph -> Vertex -> [Vertex]
reachable g v = preorderF (dfs g [v])

path         :: Graph -> Vertex -> Vertex -> Bool
path g v w    = w `elem` (reachable g v)








bcc :: Graph -> Forest [Vertex]
bcc g = (concat . map bicomps . map (do_label g dnum)) forest
 where forest = dff g
       dnum   = preArr (bounds g) forest

do_label :: Graph -> Table Int -> Tree Vertex -> Tree (Vertex,Int,Int)
do_label g dnum (Node v ts) = Node (v,dnum!v,lv) us
 where us = map (do_label g dnum) ts
       lv = minimum ([dnum!v] ++ [dnum!w | w <- g!v]
                     ++ [lu | Node (u,du,lu) xs <- us])

bicomps :: Tree (Vertex,Int,Int) -> Forest [Vertex]
bicomps (Node (v,dv,lv) ts)
      = [ Node (v:vs) us | (l,Node vs us) <- map collect ts]

collect :: Tree (Vertex,Int,Int) -> (Int, Tree [Vertex])
collect (Node (v,dv,lv) ts) = (lv, Node (v:vs) cs)
 where collected = map collect ts
       vs = concat [ ws | (lw, Node ws us) <- collected, lw<dv]
       cs = concat [ if lw<dv then us else [Node (v:ws) us]
                        | (lw, Node ws us) <- collected ]




--- from the module Util

sortLt :: (a -> a -> Bool)              -- Less-than predicate
       -> [a]                           -- Input list
       -> [a]                           -- Result list

sortLt lt l = qsort lt   l []

-- qsort is stable and does not concatenate.
qsort :: (a -> a -> Bool)       -- Less-than predicate
      -> [a]                    -- xs, Input list
      -> [a]                    -- r,  Concatenate this list to the sorted input list
      -> [a]                    -- Result = sort xs ++ r

qsort lt []     r = r
qsort lt [x]    r = x:r
qsort lt (x:xs) r = qpart lt x xs [] [] r

-- qpart partitions and sorts the sublists
-- rlt contains things less than x,
-- rge contains the ones greater than or equal to x.
-- Both have equal elements reversed with respect to the original list.

qpart lt x [] rlt rge r =
    -- rlt and rge are in reverse order and must be sorted with an
    -- anti-stable sorting
    rqsort lt rlt (x : rqsort lt rge r)

qpart lt x (y:ys) rlt rge r =
    if lt y x then
        -- y < x
        qpart lt x ys (y:rlt) rge r
    else
        -- y >= x
        qpart lt x ys rlt (y:rge) r

-- rqsort is as qsort but anti-stable, i.e. reverses equal elements
rqsort lt []     r = r
rqsort lt [x]    r = x:r
rqsort lt (x:xs) r = rqpart lt x xs [] [] r

rqpart lt x [] rle rgt r =
    qsort lt rle (x : qsort lt rgt r)

rqpart lt x (y:ys) rle rgt r =
    if lt x y then
        -- y > x
        rqpart lt x ys rle (y:rgt) r
    else
        -- y <= x
        rqpart lt x ys (y:rle) rgt r


