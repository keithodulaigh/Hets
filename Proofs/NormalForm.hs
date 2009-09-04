{- |
Module      :  $Header$
Description :  compute the normal forms of all nodes in development graphs
Copyright   :  (c) Christian Maeder, DFKI GmbH 2009
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(Logic)

compute normal forms
-}

module Proofs.NormalForm
    ( normalFormLibEnv
    , normalForm
    , freeness
    ) where

import Logic.Logic

import Static.DevGraph
import Static.WACocone

import Proofs.EdgeUtils
import Proofs.ComputeColimit

import Common.Id
import Common.LibName
import Common.Result

import Data.Graph.Inductive.Graph as Graph
import Common.Lib.Graph
import qualified Data.Map as Map
import Data.List (nub)
import Control.Monad

import Logic.Grothendieck
import Static.GTheory

import Logic.Coerce
import Logic.Comorphism
import Logic.Prover(toNamedList, toThSens)
import Logic.ExtSign
import Common.ExtSign

normalFormRule :: DGRule
normalFormRule = DGRule "NormalForm"

-- | compute normal form for a library and imported libs
normalForm :: LIB_NAME -> LibEnv -> Result LibEnv
normalForm ln le = normalFormLNS (dependentLibs ln le) le

-- | compute norm form for all libraries
normalFormLibEnv :: LibEnv -> Result LibEnv
normalFormLibEnv le = normalFormLNS (getTopsortedLibs le) le

normalFormLNS :: [LIB_NAME] -> LibEnv -> Result LibEnv
normalFormLNS lns libEnv = foldM (\ le ln -> do
  let dg = lookupDGraph ln le
  newDg <- normalFormDG le dg
  return $ Map.insert ln
    (groupHistory dg normalFormRule newDg) le)
  libEnv lns

normalFormDG :: LibEnv -> DGraph -> Result DGraph
normalFormDG libEnv dgraph = foldM (\ dg (node, nodelab) ->
  if labelHasHiding nodelab then case dgn_nf nodelab of
    Just _ -> return dg -- already computed
    Nothing -> if isDGRef nodelab then do
        -- the normal form of the node
        -- is a reference to the normal form of the node it references
        -- careful: here not refNf, but a new Node which references refN
       let refLib = dgn_libname nodelab
           refNode = dgn_node nodelab
           refGraph' = lookupDGraph refLib libEnv
           refLabel = labDG refGraph' refNode
       case dgn_nf refLabel of
         Nothing -> warning dg
           (getDGNodeName refLabel ++ " (node " ++ show refNode
            ++ ") from '" ++ show (getLIB_ID refLib)
            ++ "' without normal form") nullRange
         Just refNf -> do
           let refNodelab = labDG refGraph' refNf
               -- the label of the normal form ^
               nfNode = getNewNodeDG dg
               -- the new reference node in the old graph ^
               refLab = refNodelab
                 { dgn_name = extName "NormalForm" $ dgn_name nodelab
                 , dgn_nf = Just nfNode
                 , dgn_sigma = Just $ ide $ dgn_sign refNodelab
                 , nodeInfo = newRefInfo refLib refNf
                 , dgn_lock = Nothing }
               newLab = nodelab{
                   dgn_nf = Just nfNode,
                   dgn_sigma = dgn_sigma $ labDG refGraph' $ dgn_node nodelab
                 }
               chLab = SetNodeLab nodelab (node, newLab)
               changes = [InsertNode (nfNode, refLab), chLab]
               newGraph = changesDGH dgraph changes
           return newGraph
      else do
        let gd = insNode (node, dgn_theory nodelab) empty
            g0 = Map.fromList [(node, node)]
            (diagram, g) = computeDiagram dg [node] (gd, g0)
            fsub = finalSubcateg diagram
            Result ds res = gWeaklyAmalgamableCocone fsub
            es = map (\ d -> if isErrorDiag d then d { diagKind = Warning }
                             else d) ds
        appendDiags es
        case res of
          Nothing -> warning dg
                ("cocone failure for " ++ getDGNodeName nodelab
                 ++ " (node " ++ shows node ")") nullRange
          Just (sign, mmap) -> do
            -- we don't know that node is in fsub
            -- if it's not, we have to find a tip accessible from node
            -- and dgn_sigma = edgeLabel(node, tip); mmap (g Map.! tip)
            morNode <- if node `elem` nodes fsub then let
                        gn = Map.findWithDefault (error "gn") node g
                        phi = Map.findWithDefault (error "mor") gn mmap
                       in return phi else let
                          leaves = filter (\x -> outdeg fsub x == 0) $
                                     nodes fsub
                          paths =  map (\(x, Result _ (Just f)) -> (x,f)) $
                                      map (\x ->
                                              (x, dijkstra diagram node x)) $
                                      filter (\x -> node `elem` subgraph
                                                      diagram x) leaves
                                          in
                            case paths of
                             [] -> fail "node should reach a tip"
                             (xn, xf) : _ -> comp xf $ mmap Map.! xn
            let nfNode = getNewNodeDG dg -- new node for normal form
                info = nodeInfo nodelab
                ConsStatus c cp pr = node_cons_status info
                nfLabel = newInfoNodeLab
                  (extName "NormalForm" $ dgn_name nodelab)
                  info
                  { node_origin = DGNormalForm node
                  , node_cons_status = mkConsStatus c }
                  sign
                newLab = nodelab -- the new label for node
                     { dgn_nf = Just nfNode
                     , dgn_sigma = Just morNode
                     , nodeInfo = info
                         { node_cons_status = ConsStatus None cp pr }
                     }
            -- add the nf to the label of node
                chLab = SetNodeLab nodelab (node, newLab)
            -- insert the new node and add edges from the predecessors
                insNNF = InsertNode (nfNode, nfLabel)
                makeEdge src tgt m = (src, tgt, DGLink { dgl_morphism = m
                                              , dgl_type = globalDef
                                              , dgl_origin = DGLinkProof
                                              , dgl_id = defaultEdgeId
                                              })
                insStrMor = map (\ (x, f) -> InsertEdge $ makeEdge x nfNode f)
                  $ nub $ map (\ (x, y) -> (g Map.! x, y))
                  $ (node, morNode) : Map.toList mmap
                allChanges = chLab : insNNF : insStrMor
            return $ changesDGH dg allChanges
  else return dg) dgraph $ topsortedNodes dgraph -- only change relevant nodes

{- | computes the diagram associated to a node N in a development graph,
   adding common origins for multiple occurences of nodes, whenever
   needed
-}
computeDiagram :: DGraph -> [Node] -> (GDiagram, Map.Map Node Node)
               -> (GDiagram, Map.Map Node Node)
  -- as described in the paper for now
computeDiagram dgraph nodeList (gd, g) =
 case nodeList of
  [] -> (gd, g)
  _ ->
   let -- defInEdges is list of pairs (n, edges of target g(n))
       defInEdges = map (\n -> (n,filter (\e@(s,t,_) -> s /= t &&
                         liftE (liftOr isGlobalDef isHidingDef) e) $
                        innDG dgraph $ g Map.! n))  nodeList
       -- TO DO: no local links, and why edges with s=t are removed
       --        add normal form nodes
       -- sources of each edge must be added as new nodes
       nodeIds = zip (newNodes (length $ concatMap snd defInEdges) gd)
                     $ concatMap (\(n,l) -> map (\x -> (n,x)) l ) defInEdges
       newLNodes = zip (map fst nodeIds) $
                   map (\ (s,_,_) -> dgn_theory $ labDG dgraph s) $
                   concatMap snd defInEdges
       g0 = Map.fromList $
                     map (\ (newS, (_newT, (s,_t, _))) -> (newS,s)) nodeIds
       morphEdge (n1,(n2, (_, _, el))) =
         if isHidingDef $ dgl_type el
            then (n2, n1, (x, dgl_morphism el))
            else (n1, n2, (x, dgl_morphism el))
         where EdgeId x = dgl_id el
       newLEdges = map morphEdge nodeIds
       gd' = insEdges newLEdges $ insNodes newLNodes gd
       g' = Map.union g g0
   in computeDiagram dgraph (map fst nodeIds) (gd', g')

finalSubcateg :: GDiagram -> GDiagram
finalSubcateg graph = let
    leaves = filter (\(n,_) -> outdeg graph n == 0)$ labNodes graph
 in buildGraph graph (map fst leaves) leaves [] $ nodes graph

subgraph :: Gr a b -> Node -> [Node]
subgraph graph node = let
   descs nList descList =
    case nList of
      [] -> descList
      _ -> let
             newDescs = concatMap (\x -> pre graph x) nList
             nList' = filter (\x -> not $ x `elem` nList) newDescs
             descList' = nub $ descList ++ newDescs
           in descs nList' descList'
 in descs [node] []

buildGraph :: GDiagram -> [Node]
           -> [LNode G_theory]
           -> [LEdge (Int, GMorphism)]
           -> [Node]
           -> GDiagram
buildGraph oGraph leaves nList eList nodeList =
 case nodeList of
  [] -> mkGraph nList eList
  n:nodeList' ->
     case outdeg oGraph n of
      1 -> buildGraph oGraph leaves nList eList nodeList'
       -- the node is simply removed
      0 -> buildGraph oGraph leaves nList eList nodeList'
       -- the leaves have already been added to nList
      _ -> let
            Just l = lab oGraph n
            nList' = (n, l):nList
            accesLeaves = filter (\x -> n `elem` subgraph oGraph x) leaves
            eList' = map ( \(x, Result _ (Just y)) -> (n,x,(1::Int,y))) $
                     map (\x -> (x, dijkstra oGraph n x)) accesLeaves
           in buildGraph oGraph leaves nList' (eList ++ eList') nodeList'
       -- branch, must add n to the nList and edges in eList

freeness :: LIB_NAME -> LibEnv -> Result LibEnv
freeness ln le = do
  let dg = lookupDGraph ln le
  newDg <- freenessDG le dg
  return $ Map.insert ln
    (groupHistory dg normalFormRule newDg) le

freenessDG :: LibEnv -> DGraph -> Result DGraph
freenessDG le dgraph = foldM (
 \ dg edge@(m, n, x) ->
    case dgl_type x of
     FreeOrCofreeDefLink _ _ -> do
      let phi = dgl_morphism x
          gth= dgn_theory $ labDG dg m
      case gth of
       G_theory lid sig _ sen _ -> do
        case phi of
         GMorphism cid _ _ mor1 _ -> do
          mor <- coerceMorphism (targetLogic cid) lid "free" mor1
          (sigK, iota, axK) <- quotient_term_algebra lid mor $ toNamedList sen
          let thK = G_theory lid (makeExtSign lid sigK)
                             startSigId (toThSens axK) startThId
          let thM' = noSensGTheory lid sig startSigId
              iotaM' = gEmbed $ mkG_morphism lid iota
          incl <- subsig_inclusion lid (plainSign sig) sigK
          let inclM = gEmbed $ mkG_morphism lid incl
      -- m' with signature = sig, no sentences
      -- remove x
      -- add nodes
      -- k  with signature = sigK, sentences axK
      -- global def links from m and m' to k, mapped with incl, resp iota
      -- hiding def link from k to n, labeled with inclusion
              m' = getNewNodeDG dg -- new node
              nodelab = labDG dg m
              info = nodeInfo nodelab
              ConsStatus c cp pr = node_cons_status info
              labelM' = newInfoNodeLab
                  (extName "NormalForm" $ dgn_name nodelab)
                  info
                  { node_origin = DGNormalForm m
                  , node_cons_status = mkConsStatus c }
                  thM'
            -- insert the new node and add edges from the predecessors
              insM' = InsertNode (m', labelM')
              k = (getNewNodeDG dg) + 1
              labelK = newInfoNodeLab
                  (extName "NormalForm" $ dgn_name nodelab)
                  info
                  { node_origin = DGNormalForm m
                  , node_cons_status = mkConsStatus c }
                  thK
              insK = InsertNode (k, labelK)
              insE = [InsertEdge (m,k,DGLink { dgl_morphism = inclM
                                              , dgl_type = globalDef
                                              , dgl_origin = DGLinkProof
                                              , dgl_id = defaultEdgeId
                                              }),
                     InsertEdge (m',k,DGLink { dgl_morphism = iotaM'
                                              , dgl_type = globalDef
                                              , dgl_origin = DGLinkProof
                                              , dgl_id = defaultEdgeId
                                              }),
                     InsertEdge (k, n,DGLink { dgl_morphism = inclM
                                              , dgl_type = hidingThm inclM
                                              , dgl_origin = DGLinkProof
                                              , dgl_id = defaultEdgeId
                                              })]
              del = DeleteEdge edge
              allChanges = del:insM' : insK : insE
          return $ changesDGH dg allChanges
     _ -> return dg
 ) dgraph $ labEdgesDG dgraph

