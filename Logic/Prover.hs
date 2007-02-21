{- |
Module      :  $Header$
Description :  General datastructures for theorem prover interfaces
Copyright   :  (c) Till Mossakowski, Klaus L�ttich, Uni Bremen 2002-2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  till@tzi.de
Stability   :  provisional
Portability :  portable

General datastructures for theorem prover interfaces

-}
{- todo:
  - separate GoalStatus into its own Module
    and specifify the whole SZS Ontology with appropiate types and functions
    (http://www.cs.miami.edu/~tptp/cgi-bin/DVTPTP2WWW/view_file.pl?Category=Documents&File=SZSOntology)
  - clarify how a G_theory can be fed into proveCMDLautomatic etc.
    currently, we use mapTheoryStatus, but that is a hack
-}

module Logic.Prover where

import qualified Common.OrderedMap as OMap
import qualified Data.Map as Map
import qualified Data.Set as Set

import qualified Common.AS_Annotation as AS_Anno
import Common.Utils
import Common.ProofUtils
import Data.Dynamic
import Common.Result
import Common.Doc
import Common.DocUtils

import Data.List
import Data.Maybe (isJust)

import qualified Control.Concurrent as Concurrent

-- * sentence packing

data SenStatus a tStatus = SenStatus
     { value :: a
     , isAxiom :: Bool
     -- , wasTheorem :: Bool -- will be set to True when status of isAxiom 
                             -- changes from False to True
     , isDef :: Bool
     , thmStatus :: [tStatus]
     } deriving Show

instance (Show b, Pretty a) => Pretty (SenStatus a b) where
    pretty = printSenStatus pretty

printSenStatus :: (a -> Doc) -> SenStatus a b  -> Doc
printSenStatus fA = fA . value

emptySenStatus :: SenStatus a b
emptySenStatus = SenStatus
   { value = error "emptySenStatus"
   , isDef = False
   , isAxiom = True
   , thmStatus = [] }

instance Eq a => Eq (SenStatus a b) where
    d1 == d2 = (value d1, isAxiom d1, isDef d1) ==
               (value d2, isAxiom d2, isDef d2)

instance Ord a => Ord (SenStatus a b) where
    d1 <= d2 = (value d1, isAxiom d1, isDef d1) <=
               (value d2, isAxiom d2, isDef d2)

instance Pretty a => Pretty (OMap.ElemWOrd a) where
    pretty = printOMapElemWOrd pretty

printOMapElemWOrd :: (a -> Doc) -> OMap.ElemWOrd a -> Doc
printOMapElemWOrd fA = fA . OMap.ele

type ThSens a b = OMap.OMap String (SenStatus a b)

noSens :: ThSens a b
noSens = OMap.empty

mapThSensStatus :: (b->c) -> ThSens a b -> ThSens a c
mapThSensStatus f = OMap.map (mapStatus f)

-- | join and disambiguate
--
-- * separate Axioms from Theorems
--
-- * don't merge sentences with same key but different contents?
joinSens :: (Ord a,Eq b) => ThSens a b -> ThSens a b -> ThSens a b
joinSens s1 s2 = let l1 = sortBy (comparing snd) $ Map.toList s1
                     updN n (_, e) = (n, e)
                     m = OMap.size s1
                     l2 = map (\ (x,e) ->
                                    (x,e {OMap.order = m + OMap.order e })) $
                          sortBy (comparing snd) $ Map.toList s2
                 in Map.fromList $ mergeSens l1 $
                         genericDisambigSens fst updN (OMap.keysSet s1) l2
    where mergeSens [] l2 = l2
          mergeSens l1 [] = l1
          mergeSens l1@((k1, e1) : r1) l2@((k2, e2) : r2) =
              case compare e1 e2 of
              LT -> (k1, e1) : mergeSens r1 l2
              EQ -> (k1, e1 { OMap.ele = (OMap.ele e1)
                                        { thmStatus =
                                              union (thmStatus $ OMap.ele e1)
                                                  (thmStatus $ OMap.ele e2)}})
                         : mergeSens r1 r2
              GT -> (k2, e2) : mergeSens l1 r2

diffSens :: (Ord a,Eq b) => ThSens a b -> ThSens a b -> ThSens a b
diffSens s1 s2 = let
    l1 = sortBy (comparing snd) $ Map.toList s1
    l2 = sortBy (comparing snd) $ Map.toList s2
    in Map.fromList $ diffS l1 l2
    where diffS [] _ = []
          diffS l1 [] = l1
          diffS l1@((k1, e1) : r1) l2@((_, e2) : r2) =
              case compare e1 e2 of
              LT -> (k1, e1) : diffS r1 l2
              EQ -> diffS r1 r2
              GT -> diffS l1 r2

mapValue :: (a -> b) -> SenStatus a c -> SenStatus b c
mapValue f d = d { value = f $ value d }

mapStatus :: (b -> c) -> SenStatus a b -> SenStatus a c
mapStatus f d = d { thmStatus = map f $ thmStatus d }

markAsAxiom :: Ord a => Bool -> ThSens a b -> ThSens a b
markAsAxiom b = OMap.map (\d -> d { isAxiom = b})

markAsGoal :: Ord a => ThSens a b -> ThSens a b
markAsGoal = markAsAxiom False

toNamedList :: ThSens a b -> [AS_Anno.Named a]
toNamedList = map (uncurry toNamed) . OMap.toList

toNamed :: String -> SenStatus a b -> AS_Anno.Named a
toNamed k s = AS_Anno.NamedSen
              { AS_Anno.sentence = value s
              , AS_Anno.senName  = k
              , AS_Anno.isDef    = isDef s
              , AS_Anno.isAxiom  = isAxiom s}

-- | putting Sentences from a list into a map
toThSens :: Ord a => [AS_Anno.Named a] -> ThSens a b
toThSens = OMap.fromList . map
    ( \ v -> (AS_Anno.senName v,
              emptySenStatus { value   = AS_Anno.sentence v
                             , isAxiom = AS_Anno.isAxiom v
                             , isDef   = AS_Anno.isDef v }))
    . disambiguateSens Set.empty . nameSens

-- | theories with a signature and sentences with proof states
data Theory sign sen proof_tree =
    Theory sign (ThSens sen (Proof_status proof_tree))

mapTheoryStatus :: (a->b) -> Theory sign sentence a
                   -> Theory sign sentence b
mapTheoryStatus f (Theory sig thSens) =
  Theory sig (mapThSensStatus (mapProofStatus f) thSens)

-- | theory morphisms between two theories
data TheoryMorphism sign sen mor proof_tree = TheoryMorphism
    { t_source :: Theory sign sen proof_tree
    , t_target :: Theory sign sen proof_tree
    , t_morphism :: mor }

-- e.g. the file name, or the script itself, or a configuration string
data Tactic_script = Tactic_script String deriving (Eq, Ord, Show)

-- | enumeration type representing the status of a goal
data GoalStatus = Open
                | Disproved
                | Proved (Maybe Bool) -- ^ Just True means consistent;
                                      -- Nothing means don't know
                      --
                      -- needed for automated theorem provers like SPASS;
                      -- provers like Isabelle set it to Nothing
     deriving (Eq,Ord)

instance Show GoalStatus where
    show gs = case gs of
              Open -> "Open"
              Disproved -> "Disproved"
              Proved mc -> "Proved" ++
                           maybe "" (\ c -> "("++
                                            (if c then "" else "in") ++
                                            "consistent)") mc

-- | data type representing the proof status for a goal or
data Proof_status proof_tree =
       Proof_status { goalName :: String
                    , goalStatus :: GoalStatus
                    , usedAxioms :: [String] -- ^ used axioms
                    , proverName :: String -- ^ name of prover
                    , proofTree :: proof_tree
                    , tacticScript :: Tactic_script }
     | Consistent Tactic_script
     deriving (Show,Eq,Ord)

-- | constructs an open proof status with basic information filled in;
-- make sure to set proofTree to a useful value before you access it, because
-- its default value is 'undefined'
openProof_status :: Ord pt =>
                    String -- ^ name of the goal
                 -> String -- ^ name of the prover
                 -> pt
                 -> Proof_status pt
openProof_status goalname provername proof_tree =
    Proof_status { goalName = goalname
                 , goalStatus = Open
                 , usedAxioms = []
                 , proverName = provername
                 , proofTree = proof_tree
                 , tacticScript = Tactic_script ""}

mapProofStatus :: (a->b) -> Proof_status a -> Proof_status b
mapProofStatus f st = st {proofTree = f $ proofTree st}

{-
instance Eq a => Ord (Proof_status a) where
    Open _ <= _ = True
    Disproved _ <= x = case x of
                       Open _ -> False
                       _ -> True
    Proved _ _ _ _ _ <= x = case x of
                            Proved _ _ _ _ _ -> True
                            _ -> False
    _ <= _ = False

-- Ord instance must match Eq instance!
instance Eq a => Eq (Proof_status a) where
    a == b = compare a b == EQ
-}

isProvedStat :: Proof_status proof_tree -> Bool
isProvedStat pst = case pst of
                   Consistent _ -> False
                   _ -> isProvedGStat . goalStatus $ pst

isProvedGStat :: GoalStatus -> Bool
isProvedGStat gs = case gs of
                   Proved _ -> True
                   _ -> False

goalUsedInProof :: Monad m => Proof_status proof_tree -> m Bool
goalUsedInProof pst =
    case goalStatus pst of
    Proved m -> maybe (fail "don't know if goal was used") return m
    _ -> fail "not a proof"

-- | different kinds of prover interfaces
data ProverKind = ProveGUI | ProveCMDLautomatic | ProveCMDLinteractive

-- | determine if a prover kind is implemented
hasProverKind :: ProverKind -> ProverTemplate x y -> Bool
hasProverKind pk pt = 
    case pk of
    ProveGUI -> isJust $ proveGUI pt
    ProveCMDLautomatic -> isJust (proveCMDLautomatic pt) && 
                          isJust (proveCMDLautomaticBatch pt)
    ProveCMDLinteractive -> isJust $ proveCMDLinteractive pt

-- | prover or consistency checker
data ProverTemplate theory proof_tree = Prover
    { prover_name :: String,
      prover_sublogic :: String,
      proveGUI :: Maybe (String -> theory -> IO ([Proof_status proof_tree])),
      -- input: theory name, theory (incl. goals)
      -- output: proof status for goals and lemmas
      proveCMDLautomatic :: Maybe (String -> Tactic_script
                         -> theory -> IO (Result ([Proof_status proof_tree]))),
      -- blocks until a result is determined
      -- input: theory name, Tactic_script,
      --        theory (incl. goals, but only the first one is tried)
      -- output: proof status for goals and lemmas
      proveCMDLinteractive :: Maybe (String -> Tactic_script
                         -> theory -> IO (Result ([Proof_status proof_tree]))),
      -- input, output: see above
      proveCMDLautomaticBatch :: 
          Maybe (Bool -> Bool
                 -> Concurrent.MVar (Result [Proof_status proof_tree]) 
                 -> String -> Tactic_script -> theory 
                 -> IO (Concurrent.ThreadId,Concurrent.MVar ()))
      -- input: 1. True means include proven theorems in subsequent 
      --           proof attempts;
      --        2. True means save problem file for each goal;
      --        2. reference to a Result with an empty list (return []),
      --           used to store the result of the batch run;
      --        3. theory name;
      --        4. default Tactic_script,
      --        5. theory (incl. goals and 
      --                   Open SenStatus for individual tactic_scripts)
      -- output: fst --> identifier of the batch thread for killing it,
      --                 after each proof attempt the result is stored in the 
      --                 IOref
      --         snd --> MVar to wait for the end of the thread
    }

type Prover sign sentence proof_tree =
    ProverTemplate (Theory sign sentence proof_tree) proof_tree

emptyProverTemplate :: ProverTemplate x y
emptyProverTemplate = Prover 
              { prover_name = error "Empty proverTemplate name"
              , prover_sublogic = error "Empty proverTemplate sublogic"
              , proveGUI = Nothing
              , proveCMDLautomatic = Nothing
              , proveCMDLinteractive = Nothing 
              , proveCMDLautomaticBatch = Nothing }

type ConsChecker sign sentence morphism proof_tree =
  ProverTemplate (TheoryMorphism sign sentence morphism proof_tree) proof_tree

proverTc :: TyCon
proverTc = mkTyCon "Logic.Prover.ProverTemplate"

instance (Typeable a, Typeable b) => Typeable (ProverTemplate a b) where
    typeOf p = mkTyConApp proverTc
               [typeOf ((error "Logic.Prover" :: ProverTemplate a b -> a) p),
                typeOf ((error "Logic.Prover" :: ProverTemplate a b -> b) p)]

