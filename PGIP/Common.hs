{- |
Module      :$Header$
Copyright   : uni-bremen and Razvan Pascanu
Licence     : similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  : r.pascanu@iu-bremen.de
Stability   : provisional
Portability : portable

Toghether with PGIP.Utils, PGIP.Common contains all the auxiliary functions
used throughout the interactive interface. The reason for dividing these
functions in two files was that otherwise we would've get a circular 
inclusion (for example Proof.Automatic requieres some of these auxiliary 
functions, but some other functions -- that appear now in PGIP.Common -- 
require some functions from Proof.Automatic)


-} 

module PGIP.Common where
                      


import Syntax.AS_Library
import Static.DevGraph
import Static.DGToSpec
import Proofs.InferBasic
import Common.DocUtils
import Common.Result
import Common.Taxonomy
import Common.Lib.Set
import Logic.Logic
import Logic.Grothendieck
import GUI.Taxonomy
import Data.Maybe
import Data.Graph.Inductive.Graph
import Comorphisms.LogicGraph
import PGIP.Utils
import Events
import Destructible
import qualified Logic.Prover as P
import qualified Common.OrderedMap as OMap
    
-- | The datatype CmdParam contains all the possible parameters a command of
-- the interface might have. It is used to create one function that returns
-- the parameters after parsing no matter what command is parsed
data CmdParam =
   Path                          String 
 | Formula                       String 
 | UseProver                     String
 | Goals                         [GOAL]
 | ParsedComorphism             [String]
 | AxiomSelectionWith           [String]
 | AxiomSelectionExcluding      [String]
 | Formulas                     [String]
 | ProofScript                   String
 | ParamErr                      String
 | NoParam
 deriving (Eq,Show)


-- | The datatype Status contains the current status of the interpeter at any
-- moment in time
data Status = 
   OutputErr  String
 | CmdInitialState
-- Env stores the graph loaded 
 | Env     LIB_NAME LibEnv
-- Selected stores the graph goals selected with Infer Basic command
 | Selected [GraphGoals]
-- AllGoals stores all goals contained by the graph at any moment in time
 | AllGoals [GraphGoals]
-- Comorph stores  a certain comorphism to be used
 | Comorph [String]
-- Prover stores the Id of the prover that needs to be used
 | Prover String
-- Address stores the current library loaded so that the correct promter can
-- be generated
 | Address String


 



-- | The function checks if the first string is a prefix of the second.
prefix :: String -> String -> Bool
prefix w1 w2 
 = case w1 of 
     x1:l1 -> case w2 of
               x2:l2 -> if (x1==x2) then (prefix l1 l2)
                                    else False
               []    -> False
     [] -> True

-- | The function returns the name of all nodes from the given list
getNameList :: [GDataNode] -> [String]
getNameList ls
 = case ls of
     (_, (DGNode thName _ _ _ _ _ _ )):l -> (showName thName):(getNameList l)
     (_, (DGRef  thName _ _ _ _ _ )):l   -> (showName thName):(getNameList l)
     []                                  -> []

-- | The function checks if the word 'wd' is a prefix of the name of 
-- any of the nodes in the list, if so it returns the list of the 
-- names otherwise it returns the empty list
checkWord :: String -> [String] -> [String]
checkWord wd allNodes
 = case allNodes of
     str:l -> 
                         if (prefix wd str)
                                then 
                                  if (str=="")
                                     then checkWord wd l
                                     else (str:(checkWord wd l))
                                else checkWord wd l
     []                   -> [] 
 
-- | The function flips a string around
reverseOrder :: String -> String -> String
reverseOrder ls wd
 = case ls of
      [] ->  wd
      x:l -> reverseOrder l (x:wd)

-- | The function categorizes the commands after the
-- type of arguments it should expect
prefixType ::String -> Int
prefixType wd
 = case wd of
     "dg auto" -> 1
     "dg glob-subsume" -> 1
     "dg glob-decomp" -> 1
     "dg loc-infer" -> 1
     "dg loc-decomp" -> 1
     "dg comp" -> 1
     "dg comp-new" -> 1
     "dg hide-thm" -> 1
     "dg basic"  -> 3
     "node-number" -> 2
     "info" -> 3
     "show-concept" -> 2
     "show-taxonomy" -> 2
     "show-theory" -> 2 
     _           -> 0


arrowNext :: String -> Bool 
arrowNext ls =
  case ls of 
     ' ':l -> arrowNext l
     '-':l -> case l of
                '>':_ -> True
                _ -> False
     _ -> False

afterArrow :: String -> String
afterArrow ls =
    case ls of
      ' ':l -> afterArrow l
      '-':l -> afterArrow l
      '>':l -> afterArrow l
      smth  -> smth
-- | The function checks if a word still has white spaces or not
hasWhiteSpace :: String -> Bool
hasWhiteSpace ls 
 = case ls of
       []    -> False
       ' ':l -> if (arrowNext l) then hasWhiteSpace (afterArrow l)
                                 else True
       '\t':_-> True
       '\n':_-> True
       '\r':_-> True
       ';':_ -> True
       ',':_ -> True
       _:l   -> hasWhiteSpace l


-- | The function tries to obtain only the incomplete word
-- removing the command name
getSuffix :: String -> String
getSuffix wd
 = if (hasWhiteSpace wd) then getSuffix (tail wd)
                         else wd

-- | The function given a string tries to obtain the command
-- name and remove the incomplete word from the end
getShortPrefix :: String -> String -> IO String
getShortPrefix wd tmp
 = if (hasWhiteSpace wd) 
         then if (hasWhiteSpace (tail wd))
                  then do
                        getShortPrefix (tail wd) ((head wd):tmp)
                  else if ((prefixType (reverseOrder tmp [])) > 0)
                             then return (reverseOrder tmp [])
                             else getShortPrefix (reverseOrder tmp []) []
        else return []


getLongPrefix :: String -> String -> String
getLongPrefix wd tmp
 = if (hasWhiteSpace wd)
          then getLongPrefix (tail wd) ((head wd):tmp)
          else reverseOrder tmp []
-- | The function simply adds the string as a prefix to any
-- word from the given list
addWords ::[String] -> String -> [String]
addWords ls wd
 = case ls of
      x:l  -> (wd++x):(addWords l wd)
      []   -> []

-- | The function 'pgipCompletionFn' given the current status and an incomplete
-- word provides a list of possible words completions
pgipCompletionFn :: [Status] -> String -> IO [String]
pgipCompletionFn state wd
 = case state of
    (Env ln libEnv):rest -> 
      case rest of
       (AllGoals allGoals):_ -> do
        let dgraph= lookupDGraph ln libEnv
        pref <- getShortPrefix wd []
        if ((prefixType pref)> 0) 
         then do
          let values = if ((prefixType pref)==1)
               then getGoalNameFromList allGoals (labNodes dgraph)
               else
                   if ((prefixType pref)==2)
                    then  getNameList (labNodes dgraph)
                    else ((getNameList (labNodes dgraph)) ++
                           (getGoalNameFromList allGoals (labNodes dgraph)))
          let list = checkWord (getSuffix wd) values
          if (list==[]) then return []
                        else return (addWords list (getLongPrefix wd []))
         else
          return []
       _:l -> pgipCompletionFn ((Env ln libEnv):l) wd
       []  -> return []
    (AllGoals allGoals):rest -> 
      case rest of 
       (Env ln libEnv):_ -> do
         let dgraph= lookupDGraph ln libEnv
         pref <- getShortPrefix wd []
         if ((prefixType pref)> 0) 
          then do
           let values = if ((prefixType pref)==1)
                                then getGoalNameFromList allGoals (labNodes dgraph)
                                else
                                 getNameList (labNodes dgraph)
           let list = checkWord (getSuffix wd) values 
           if (list==[]) then return []
                        else return (addWords list (getLongPrefix wd []))
          else
           return []
       _:l -> pgipCompletionFn ((AllGoals allGoals):l) wd
       []  -> return []
    _:l               ->    pgipCompletionFn l wd
    []                -> return []


-- | The function 'getNodeList' returns from a list of graph goals just
-- the nodes as [GDataNode]
getNodeList :: [GraphGoals] -> [GDataNode]
getNodeList ls =
       case ls of 
            (GraphEdge _):l  -> getNodeList l
            (GraphNode x):l  -> x:(getNodeList l)
            []               -> []

-- | The function 'update' returns the updated version of 'status' with the
-- values from 'val' (i.e replaces any value from 'status' with the one from
-- 'val' if they are of the same type otherwise just adds the values from 'val'
update::[Status] -> [Status] -> [Status]
update val status
 = case val of
    []                  ->  status
    (Env x y):l         -> 
      case status of
       []                 -> update l [Env x y]
       CmdInitialState:ls -> update ((Env x y):l) ls
       (OutputErr xx):_   -> (OutputErr xx):[]
       (Env _ _):ls       -> update l ((Env x y):ls)
       (Selected xx):ls   -> update l ((Selected xx):(update [Env x y] ls))
       (AllGoals xx):ls   -> update l ((AllGoals xx):(update [Env x y] ls))
       (Comorph xx):ls    -> update l ((Comorph xx):(update [Env x y] ls))
       (Prover xx):ls     -> update l ((Prover xx):(update [Env x y] ls))
       (Address xx):ls    -> update l ((Address xx):(update [Env x y] ls))
    (Selected x):l -> 
      case status of
       []                 -> update l [Selected x]
       CmdInitialState:ls -> update ((Selected x):l) ls
       (OutputErr xx):_   -> (OutputErr xx):[]
       (Env xx yy):ls     -> update l ((Env xx yy):(update [Selected x] ls))
       (Selected _):ls    -> update l ((Selected x):ls)
       (AllGoals xx):ls   -> update l ((AllGoals xx):(update [Selected x] ls))
       (Comorph xx):ls    -> update l ((Comorph xx):(update [Selected x] ls))
       (Prover xx):ls     -> update l ((Prover xx):(update [Selected x] ls))
       (Address xx):ls    -> update l ((Address xx):(update [Selected x] ls))
    (AllGoals x):l -> 
      case status of
       []                 -> update  l [AllGoals x] 
       CmdInitialState:ls -> update  ((AllGoals x):l) ls 
       (OutputErr xx):_   -> (OutputErr xx):[]
       (Env xx yy):ls     -> update l ((Env xx yy):(update [AllGoals x] ls))
       (Selected xx):ls   -> update l ((Selected xx):(update [AllGoals x] ls))
       (AllGoals _):ls    -> update l ((AllGoals x):ls)
       (Comorph xx):ls    -> update l ((Comorph xx):(update [AllGoals x] ls))
       (Prover xx):ls     -> update l ((Prover xx): (update [AllGoals x] ls))
       (Address xx):ls    -> update l ((Address xx):(update [AllGoals x] ls))
    (Comorph x):l -> 
      case status of
       []                 -> update l [Comorph x]
       CmdInitialState:ls -> update ((Comorph x):l) ls
       (OutputErr xx):_   -> (OutputErr xx):[]
       (Env xx yy):ls     -> update l ((Env xx yy):(update [Comorph x] ls))
       (Selected xx):ls   -> update l ((Selected xx):(update [Comorph x] ls))
       (AllGoals xx):ls   -> update l ((AllGoals xx):(update [Comorph x] ls))
       (Comorph _):ls     -> update l ((Comorph x):ls)
       (Prover xx):ls     -> update l ((Prover xx):(update  [Comorph x] ls))
       (Address xx):ls    -> update l ((Address xx):(update [Comorph x] ls))
    (Prover x):l    -> 
      case status of
       []                 -> update l [Prover x]
       CmdInitialState:ls -> update ((Prover x):l) ls
       (OutputErr xx):_   -> (OutputErr xx):[]
       (Env xx yy):ls     -> update l ((Env xx yy):(update [Prover x] ls))
       (Selected xx):ls   -> update l ((Selected xx):(update [Prover x] ls))
       (AllGoals xx):ls   -> update l ((AllGoals xx):(update [Prover x] ls))
       (Comorph xx):ls    -> update l ((Comorph xx):(update [Prover x] ls))
       (Prover _):ls      -> update l ((Prover x):ls)
       (Address xx):ls    -> update l ((Address xx):(update [Prover x] ls))
    (Address x):l   ->
      case status of
       []                 -> update l [Address x]
       CmdInitialState:ls -> update ((Address x):l) ls
       (OutputErr xx):_   -> (OutputErr xx):[]
       (Env xx yy):ls     -> update l ((Env xx yy):(update [Address x] ls))
       (Selected xx):ls   -> update l ((Selected xx):(update [Address x] ls))
       (AllGoals xx):ls   -> update l ((AllGoals xx):(update [Address x] ls))
       (Comorph xx):ls    -> update l ((Comorph xx):(update [Address x] ls))
       (Prover xx):ls     -> update l ((Prover xx):(update [Address x] ls))
       (Address _):ls     -> update l ((Address x):ls)
    (OutputErr x):_       -> (OutputErr x):[]
    CmdInitialState:l     -> update l status



-- | The function 'printNodeTheoryFromList' prints on the screen the theory
-- of all nodes in the [GraphGoals] list
printNodeTheoryFromList :: [GraphGoals]-> IO()
printNodeTheoryFromList ls =
                case ls of 
                     (GraphNode x):l -> do 
                                         printNodeTheory (GraphNode x)
                                         result<- printNodeTheoryFromList l
                                         return result
                     _:l   -> do
                                result <-printNodeTheoryFromList l
                                return result
                     []    -> return ()

-- | The function 'printNodeTheory' given a GraphGoal prints on the screen
-- the theory of the node if the goal is a node or 'Not a node !' otherwise
printNodeTheory :: GraphGoals -> IO()
printNodeTheory arg =
  case arg of
   GraphNode (_,(DGNode _ theTh _ _ _ _ _)) -> 
                    putStr  ((showDoc theTh "\n") ++ "\n")
   GraphNode (_,(DGRef _ _ _ theTh _ _)) ->
                    putStr  ((showDoc theTh "\n") ++ "\n")
   _      -> putStr "Not a node!\n" 


-- | The function 'findNode' finds to node with the number 'nb' in the goal list
findNode :: Int -> [GDataNode] ->Maybe GraphGoals
findNode nb ls
 = case ls of
           (x,labelInfo):l -> 
                       if (x==nb) then  
                            Just (GraphNode (x,labelInfo))
                                  else
                            findNode nb l
           []  -> Nothing

-- | The function returns the name of all goals from the list (it
-- requires all the nodes from the graph as a parameter as well)
getGoalNameFromList :: [GraphGoals] -> [GDataNode] -> [String]
getGoalNameFromList ls allNodes =
  case ls of 
       (GraphNode x):l -> (getGoalName (GraphNode x)):
                               (getGoalNameFromList l allNodes)
       (GraphEdge (x,y,_)):l ->
                     let x1 = fromJust $ findNode x allNodes
                         y1 = fromJust $ findNode y allNodes
                     in ((getGoalName x1)++" -> "++(getGoalName y1)):
                              (getGoalNameFromList l allNodes)
       []              -> []

-- | The function returns the name of the goal if it is a node
getGoalName ::GraphGoals -> String
getGoalName x 
 = case x of 
       (GraphNode (_,(DGNode thName _ _ _ _ _ _))) -> showName thName
       (GraphNode (_,(DGRef  thName _ _ _ _ _)))   -> showName thName
       _                                           -> "Not a node !"

-- | The function 'printInfoFromList' given a GraphGoal list prints the 
-- name of all goals (node or edge)
printNamesFromList :: [GraphGoals] ->[GDataNode]-> IO()
printNamesFromList ls allNodes =
   case ls of
        (GraphNode x):l -> do
              printNodeInfo (GraphNode x)
              putStr "\n"
              result <-printNamesFromList l allNodes
              return result
        (GraphEdge (x,y,_)):l      -> do 
              let x1 = fromJust $ findNode x allNodes
              let y1 = fromJust $ findNode y allNodes
              printNodeInfo x1
              putStr " -> "
              printNodeInfo y1
              putStr "\n"
              result<- printNamesFromList l allNodes
              return result
        []              -> return ()

-- | The function prints the number of all nodes provided as
-- graph goals
printNodeNumberFromList :: [GraphGoals]-> IO()
printNodeNumberFromList ls =
  case ls of 
     (GraphNode x):l -> do
               printNodeNumber (GraphNode x)
               putStr "\n"
               result <- printNodeNumberFromList l
               return result
     _:l        -> do 
               result <- printNodeNumberFromList l
               return result
     []         -> return ()

-- | The function prints the number of the graph goal if it is a node
printNodeNumber:: GraphGoals -> IO()
printNodeNumber x =
  case x of
     GraphNode (nb, (DGNode tname _ _ _ _ _ _)) ->
        putStr ("Node "++(showName tname)++" has number "++(show nb))
     GraphNode (nb, (DGRef tname _ _ _ _ _)) ->
                  putStr ("Node "++(showName tname)++" has number "++(show nb))
     _               -> putStr "Not a node !\n"

-- | The function 'printNodeInfoFromList' given a GraphGoal list prints the 
-- name of all node goals
printInfoFromList :: [GraphGoals] -> [GDataNode] -> IO()
printInfoFromList ls allNodes=
   case ls of
        (GraphNode x):l -> do
              putStr "Name : "
              printNodeInfo (GraphNode x)
              putStr "\n"
              putStr "Origin : "
              printNodeOrigin (GraphNode x)
              putStr "\n"
              putStr "Sublogic : "
              printNodeSublogic (GraphNode x)
              putStr "\n"
              putStr "Number of axioms : "
              printNodeNumberAxioms (GraphNode x)
              putStr "\n"
              putStr "Number of symbols in the signature : "
              printNodeNumberSymbols (GraphNode x)
              putStr "\n"
              putStr "Number of unproven theorems : "
              printNodeNumberUnprovenThm (GraphNode x)
              putStr "\n"
              putStr "Number of proven theorems : "
              printNodeNumberProvenThm (GraphNode x)
              putStr "\n\n"
              result <-printInfoFromList l allNodes
              return result
        (GraphEdge (x,y,labelData)):l      -> do 
              let x1 = fromJust $ findNode x allNodes
              let y1 = fromJust $ findNode y allNodes
              putStr "Name : "
              printNodeInfo x1
              putStr " -> "
              printNodeInfo y1
              putStr "\n"
              putStr "Origin : "
              printEdgeOrigin (GraphEdge (x,y,labelData))
              putStr "\n"
              putStr "Sublogic of source : "
              printNodeSublogic x1
              putStr "\n"
              putStr "Sublogic of target : "
              printNodeSublogic y1
              putStr "\n"
              putStr "Homogeneous : "
              printEdgeHomogeneous (GraphEdge (x,y,labelData))
              putStr "\n"
              putStr "Type : "
              printEdgeType (GraphEdge (x,y,labelData))
              putStr "\n\n"
              result<- printInfoFromList l allNodes
              return result
        []              -> return ()
-- | The function 'printNodeInfo' given a GraphGoal prints the name of the node
-- if it is a graph node otherwise prints 'Not a node !'
printNodeInfo :: GraphGoals -> IO()
printNodeInfo x =
       case x of
          GraphNode (_, (DGNode tname _ _ _ _ _ _)) -> 
                                        putStr (( showName tname))
          GraphNode (_, (DGRef tname _ _ _ _ _ )) ->
                                        putStr (( showName tname))
          _                          -> putStr "Not a node!\n"

-- | The function, give an edge as a graph goal prints the type of the edge
printEdgeType :: GraphGoals -> IO()
printEdgeType x =
  case x of
    GraphEdge (_,_,dglab) ->
       case (getDGLinkType dglab) of
           "globaldef"   -> putStr "global definition"
           "def"         -> putStr "local definition"
           "hidingdef"   -> putStr "hiding definitions"
           "hetdef"      -> putStr "het definition"
           "proventhm"   -> putStr "global proven theorem"
           "unproventhm" -> putStr "global unproven theorem"
           "localproventhm" ->putStr "local proven theorem"
           "localunproventhm" -> putStr "local unproven theorem"
           "hetproventhm"   -> putStr "het global proven theorem"
           "hetunproventhm" -> putStr "het global unproven theorem"
           "hetlocalproventhm" -> putStr "het local proven theorem"
           "hetlocalunproventhm" -> putStr "het local unproven theorem"
           "unprovenhidingthm" -> putStr "unproven hiding theorem"
           "provenhidingthm" -> putStr "proven hiding theorem"
           _                 -> putStr "unknown type"
    _ -> putStr "Not an edge !"

-- | The function give an edge as a graph goal prints the origin of the edge
printEdgeOrigin :: GraphGoals -> IO ()
printEdgeOrigin x =
  case x of 
     GraphEdge(_, _, (DGLink _ _ tOrigin)) ->
          putStr $ show tOrigin
     _ -> putStr "No origin found !"

-- | The function given an edge as a graph goal prints True if it is 
-- homogeneaus and false otherwise
printEdgeHomogeneous :: GraphGoals -> IO()
printEdgeHomogeneous x =
  case x of
     GraphEdge (_, _ ,(DGLink tmorph _ _)) ->
            if (isHomogeneous tmorph) then putStr "True"
                                      else putStr "False"
     _        -> putStr "Not an edge !" 

-- | The function prints the origin of the node given as graph goal
printNodeOrigin :: GraphGoals -> IO()
printNodeOrigin x =
  case x of
    GraphNode (_ ,(DGNode _ _ _ _ torigin _ _)) ->
                putStr (show torigin)
    _        -> putStr "Node does not have an origin"

-- | The function prints the sublogic of the node given as graph goal
printNodeSublogic :: GraphGoals -> IO ()
printNodeSublogic x =
  case x of 
     GraphNode (_, (DGNode _ tTh _ _ _ _ _)) ->
              putStr (show (sublogicOfTh tTh))
     GraphNode (_, (DGRef _ _ _ tTh _ _)) ->
              putStr (show (sublogicOfTh tTh))
     _ -> putStr "Node does not have a sublogic"

-- | The funcion prints the number of axioms of the node given as graph goal
printNodeNumberAxioms :: GraphGoals -> IO ()
printNodeNumberAxioms input =
  case input of
    GraphNode (_, (DGNode _ (G_theory x y _) _ _ _ _ _)) ->
         putStr $ show (size(sym_of x y))
    GraphNode (_, (DGRef _ _ _ (G_theory x y _) _ _)) ->
         putStr $ show (size (sym_of x y))
    _ -> putStr "Not a node ! \n"


-- | The function checks if a list is emty or not (same as null)
emtyList :: forall a.[a] -> Bool
emtyList ls =
  case ls of 
      [] -> True
      _  -> False

-- | The function adds to the given number the number of symbols found in the 
-- given list (sentences from the theory of the node)
countSymbols :: [P.SenStatus a b]->Int -> Int
countSymbols ls nb
 = case ls of 
       [] -> nb
       x:l -> if (P.isAxiom x)  then countSymbols l (nb+1)
                             else countSymbols l nb

-- | The function adds to the given number the number of unproven theorems 
-- found in the list
countUnprovenThm :: [P.SenStatus a b] -> Int -> Int
countUnprovenThm ls nb
 = case ls of
       []   -> nb
       x:l  -> if (emtyList (P.thmStatus x)) then countUnprovenThm l (nb+1)
                                  else countUnprovenThm l nb

-- | The function adds to the given number the number of proven theorems
-- found in the list
countProvenThm :: [P.SenStatus a b] -> Int -> Int
countProvenThm ls nb
 = case ls of
    []  -> nb
    x:l -> if (emtyList (P.thmStatus x)) then countProvenThm l nb
                                             else countProvenThm l (nb+1)


-- | From a list of sentences and SenStatus the function returns only 
-- the list of SenStatus
extractSenStatus :: [(String, P.SenStatus a b)] -> [P.SenStatus a b]
extractSenStatus ls =
  case ls of
      []       ->  []
      (_,b):l  ->  b:(extractSenStatus l)


-- | The function prints the number of symbols of the node theory given 
-- as a graph goal
printNodeNumberSymbols :: GraphGoals ->  IO ()
printNodeNumberSymbols input =
  case input of
      GraphNode (_, (DGNode _ (G_theory _ _ x) _ _ _ _ _)) ->
           putStr $ show (countSymbols (extractSenStatus (OMap.toList x)) 0)
      GraphNode (_, (DGRef _ _ _ (G_theory _ _ x) _ _)) ->
           putStr $ show (countSymbols (extractSenStatus (OMap.toList x)) 0)
      _  -> putStr "Not a node ! \n"


-- | The function prints the number of unproven theorems of the node theory
-- given as a graph goal
printNodeNumberUnprovenThm :: GraphGoals -> IO ()
printNodeNumberUnprovenThm input =
 case input of 
     GraphNode (_, (DGNode _ (G_theory _ _ x) _ _ _ _ _)) ->
        putStr $ show (countUnprovenThm (extractSenStatus (OMap.toList x)) 0)
     GraphNode (_, (DGRef _ _ _ (G_theory _ _ x) _ _)) ->
        putStr $ show (countUnprovenThm (extractSenStatus (OMap.toList x)) 0)
     _  -> putStr "Not a node ! \n"

-- | The function prints the number of proven theorems of the node theory
-- given as a graph goal
printNodeNumberProvenThm :: GraphGoals -> IO ()
printNodeNumberProvenThm input =
 case input of
     GraphNode (_, (DGNode _ (G_theory _ _ x) _ _ _ _ _))->
        putStr $ show (countProvenThm (extractSenStatus (OMap.toList x)) 0)
     GraphNode (_, (DGRef _ _ _ (G_theory _ _ x) _ _)) ->
        putStr $ show (countProvenThm (extractSenStatus (OMap.toList x)) 0)
     _  -> putStr "Not a node ! \n"

-- | The function 'printNodeTaxonomyFromList' given a GraphGoals list generates
-- the 'kind' type of Taxonomy Graphs of all goal nodes from the list
printNodeTaxonomyFromList :: TaxoGraphKind -> [GraphGoals]->LibEnv -> LIB_NAME -> IO()
printNodeTaxonomyFromList kind ls libEnv ln =
             case ls of
                   (GraphNode x):l -> 
                       do 
                          printNodeTaxonomy kind (GraphNode x) libEnv ln
                          result <- printNodeTaxonomyFromList kind l libEnv ln
                          return result
                   _:l -> 
                       do
                          result <- printNodeTaxonomyFromList kind l libEnv ln
                          return result
                   []  -> return ()


-- | The function 'printNodeTaxonomy' given just a GraphGoal generates
-- the 'kind' type of Taxonomy Graphs if the goal is a node otherwise
-- it prints on the screen 'Not a node !'
printNodeTaxonomy :: TaxoGraphKind -> GraphGoals -> LibEnv -> LIB_NAME ->IO()
printNodeTaxonomy kind x libEnv ln =
   case x of 
     GraphNode (n, (DGNode tname _ _ _ _ _ _)) -> do
             let theTh = computeTheory libEnv ln n
             case theTh of
                Result _ (Just thTh) ->
                        do graph <- displayGraph kind (showName tname) thTh
                           case graph of
                               Just g -> sync (destroyed g)
                               _ -> return () 
                Result _ _ ->
                           putStr "Error computing the theory of the node!\n"
     GraphNode (n, (DGRef tname _ _ _ _ _ )) -> do
             let theTh = computeTheory libEnv ln n
             case theTh of 
                Result _ (Just thTh) -> 
                        do graph <- displayGraph kind (showName tname) thTh 
                           case graph of
                              Just g -> sync (destroyed g)
                              _ -> return ()
                Result _ _ ->
                           putStr "Error computing the theory of the node!\n"
     _            -> putStr "Not a node!\n"
        
-- | The function proveNodes applies basicInferenceNode for proving to
-- all nodes in the graph goal list
proveNodes :: [GraphGoals] -> LIB_NAME ->LibEnv -> IO LibEnv
proveNodes ls ln libEnv
     = case ls of
        (GraphNode (nb, _)):l -> 
           do
             result <- basicInferenceNode False logicGraph (ln,nb) ln libEnv
             case result of 
                  Result _ (Just nwEnv)  -> proveNodes l ln nwEnv
                  _                      -> proveNodes l ln libEnv
        _:l                   -> proveNodes l ln libEnv
        []                    -> return libEnv

