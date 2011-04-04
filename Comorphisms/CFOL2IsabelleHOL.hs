{-# LANGUAGE MultiParamTypeClasses, TypeSynonymInstances #-}
{- |
Module      :  $Header$
Description :  embedding from CASL (CFOL) to Isabelle-HOL
Copyright   :  (c) Till Mossakowski and Uni Bremen 2003-2005
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable (imports Logic.Logic)

The embedding comorphism from CASL to Isabelle-HOL.
-}

module Comorphisms.CFOL2IsabelleHOL
    ( CFOL2IsabelleHOL (..)
    , transTheory
    , transVar
    , typeToks
    , mapSen
    , IsaTheory
    , SignTranslator
    , FormulaTranslator
    , getAssumpsToks
    , formTrCASL
    , quantifyIsa
    , quantify
    , transFORMULA
    , transSort
    , transRecord
    , transOpSymb
    ) where

import Logic.Logic
import Logic.Comorphism

import CASL.Logic_CASL
import CASL.AS_Basic_CASL
import CASL.Sublogic as SL
import CASL.Sign
import CASL.Morphism
import CASL.Quantification
import CASL.Fold
import CASL.Induction
import CASL.ToDoc

import Isabelle.IsaSign as IsaSign
import Isabelle.IsaConsts
import Isabelle.Logic_Isabelle
import Isabelle.Translate

import Common.AS_Annotation
import Common.Id
import Common.ProofTree
import Common.Utils

import qualified Data.Map as Map
import qualified Data.Set as Set
import Data.List
import Data.Maybe

-- | The identity of the comorphism
data CFOL2IsabelleHOL = CFOL2IsabelleHOL deriving Show

-- Isabelle theories
type IsaTheory = (IsaSign.Sign, [Named IsaSign.Sentence])

-- extended signature translation
type SignTranslator f e = CASL.Sign.Sign f e -> e -> IsaTheory -> IsaTheory

-- extended signature translation for CASL
sigTrCASL :: SignTranslator () ()
sigTrCASL _ _ = id

-- extended formula translation
type FormulaTranslator f e = CASL.Sign.Sign f e -> Set.Set String -> f -> Term

-- extended formula translation for CASL
formTrCASL :: FormulaTranslator () ()
formTrCASL _ _ = error "CFOL2IsabelleHOL: No extended formulas allowed in CASL"

instance Language CFOL2IsabelleHOL where
  language_name CFOL2IsabelleHOL = "CASL2Isabelle"

instance Comorphism CFOL2IsabelleHOL
               CASL CASL_Sublogics
               CASLBasicSpec CASLFORMULA SYMB_ITEMS SYMB_MAP_ITEMS
               CASLSign
               CASLMor
               Symbol RawSymbol ProofTree
               Isabelle () () IsaSign.Sentence () ()
               IsaSign.Sign
               IsabelleMorphism () () () where
    sourceLogic CFOL2IsabelleHOL = CASL
    sourceSublogic CFOL2IsabelleHOL = SL.cFol
    targetLogic CFOL2IsabelleHOL = Isabelle
    mapSublogic cid sl = if sl `isSubElem` sourceSublogic cid
                       then Just () else Nothing
    map_theory CFOL2IsabelleHOL = return . transTheory sigTrCASL formTrCASL
    map_morphism = mapDefaultMorphism
    map_sentence CFOL2IsabelleHOL sign =
      return . mapSen formTrCASL sign (typeToks sign)
    has_model_expansion CFOL2IsabelleHOL = True
    is_weakly_amalgamable CFOL2IsabelleHOL = True
    isInclusionComorphism CFOL2IsabelleHOL = True

-- -------------------------- Signature -----------------------------
baseSign :: BaseSig
baseSign = Main_thy

typeToks :: CASL.Sign.Sign f e -> Set.Set String
typeToks = Set.map (`showIsaTypeT` baseSign) . sortSet

transTheory :: FormExtension f => SignTranslator f e ->
               FormulaTranslator f e ->
               (CASL.Sign.Sign f e, [Named (FORMULA f)])
                   -> IsaTheory
transTheory trSig trForm (sign, sens) =
  trSig sign (extendedInfo sign) (IsaSign.emptySign {
    baseSig = baseSign,
    tsig = emptyTypeSig {arities =
               Set.fold (\ s -> let s1 = showIsaTypeT s baseSign in
                                 Map.insert s1 [(isaTerm, [])])
                               Map.empty (sortSet sign)},
    constTab = Map.foldWithKey insertPreds
                (Map.foldWithKey insertOps Map.empty
                $ opMap sign) $ predMap sign,
    domainTab = dtDefs},
         map (\ (s, n) -> makeNamed ("ga_induction_" ++ show n) $ myMapSen s)
              (number gens) ++
         map (mapNamed myMapSen) real_sens)
     -- for now, no new sentences
  where
    gens =
        map (inductionScheme . fst) genTypes
    tyToks = typeToks sign
    myMapSen = mkSen . transFORMULA sign tyToks trForm (getAssumpsToks sign)
    (real_sens, sort_gen_axs) = foldr ( \ s (rs, cs) -> case sentence s of
                Sort_gen_ax c b -> (rs, (c, b) : cs)
                _ -> (s : rs, cs)) ([], []) sens
    unique_sort_gen_axs = nubOrdOn (Set.fromList . map newSort . fst)
                          sort_gen_axs
    (freeTypes, genTypes) = partition snd unique_sort_gen_axs
    dtDefs = makeDtDefs sign tyToks $ map fst freeTypes
    ga = globAnnos sign
    insertOps op ts m = if isSingleton ts then
      let t = Set.findMin ts in Map.insert
              (mkIsaConstT False ga (length $ opArgs t) op baseSign tyToks)
              (transOpType t) m
      else foldl (\ m1 (t, i) -> Map.insert
             (mkIsaConstIT False ga (length $ opArgs t) op i baseSign tyToks)
             (transOpType t) m1) m $ number $ Set.toList ts
    insertPreds pre ts m = if isSingleton ts then
      let t = Set.findMin ts in Map.insert
              (mkIsaConstT True ga (length $ predArgs t) pre baseSign tyToks)
              (transPredType t) m
      else foldl (\ m1 (t, i) -> Map.insert
             (mkIsaConstIT True ga (length $ predArgs t) pre i baseSign tyToks)
             (transPredType t) m1) m $ number $ Set.toList ts

makeDtDefs :: CASL.Sign.Sign f e -> Set.Set String -> [[Constraint]]
           -> [[(Typ, [(VName, [Typ])])]]
makeDtDefs sign = map . makeDtDef sign

makeDtDef :: CASL.Sign.Sign f e -> Set.Set String -> [Constraint]
          -> [(Typ, [(VName, [Typ])])]
makeDtDef sign tyToks constrs = map makeDt srts where
    (srts, ops, _maps) = recover_Sort_gen_ax constrs
    makeDt s = (transSort s, map makeOp (filter (hasTheSort s) ops))
    makeOp opSym = (transOpSymb sign tyToks opSym, transArgs opSym)
    hasTheSort s (Qual_op_name _ ot _) = s == res_OP_TYPE ot
    hasTheSort _ _ = error "CFOL2IsabelleHOL.hasTheSort"
    transArgs (Qual_op_name _ ot _) = map transSort $ args_OP_TYPE ot
    transArgs _ = error "CFOL2IsabelleHOL.transArgs"

transSort :: SORT -> Typ
transSort s = Type (showIsaTypeT s baseSign) [] []

transOpType :: OpType -> Typ
transOpType ot = mkCurryFunType (map transSort $ opArgs ot)
                 $ transSort (opRes ot)

transPredType :: PredType -> Typ
transPredType pt = mkCurryFunType (map transSort $ predArgs pt) boolType

-- ---------------------------- Formulas ------------------------------

getAssumpsToks :: CASL.Sign.Sign f e -> Set.Set String
getAssumpsToks sign = Map.foldWithKey ( \ i ops s ->
    Set.union s $ Set.unions
        $ map ( \ (_, o) -> getConstIsaToks i o baseSign)
              $ number $ Set.toList ops)
    (Map.foldWithKey ( \ i prds s ->
    Set.union s $ Set.unions
        $ map ( \ (_, o) -> getConstIsaToks i o baseSign)
              $ number $ Set.toList prds) Set.empty $ predMap sign)
    $ opMap sign

transVar :: Set.Set String -> VAR -> String
transVar toks v = let
    s = showIsaConstT (simpleIdToId v) baseSign
    renVar t = if Set.member t toks then renVar $ "X_" ++ t else t
    in renVar s

quantifyIsa :: String -> (String, Typ) -> Term -> Term
quantifyIsa q (v, _) phi =
  termAppl (conDouble q) (Abs (mkFree v) phi NotCont)

quantify :: Set.Set String -> QUANTIFIER -> (VAR, SORT) -> Term -> Term
quantify toks q (v, t) phi =
  quantifyIsa (qname q) (transVar toks v, transSort t) phi
  where
  qname Universal = allS
  qname Existential = exS
  qname Unique_existential = ex1S

transOpSymb :: CASL.Sign.Sign f e -> Set.Set String -> OP_SYMB -> VName
transOpSymb sign tyToks (Qual_op_name op ot _) = let
  ga = globAnnos sign
  l = length $ args_OP_TYPE ot in
  fromMaybe (error $ "CASL2Isabelle unknown op: " ++ show op) $ do
         ots <- Map.lookup op (opMap sign)
         if isSingleton ots
             then return $ mkIsaConstT False ga l op baseSign tyToks
             else do
               i <- elemIndex (toOpType ot) (Set.toList ots)
               return $ mkIsaConstIT False ga l op (i + 1) baseSign tyToks
transOpSymb _ _ (Op_name _) = error "CASL2Isabelle: unqualified operation"

transPredSymb :: CASL.Sign.Sign f e -> Set.Set String -> PRED_SYMB -> VName
transPredSymb sign tyToks (Qual_pred_name p pt@(Pred_type args _) _) = let
  ga = globAnnos sign
  l = length args in
             -- for predicate names in induction schemes
  fromMaybe (mkIsaConstT True ga (-1) p baseSign tyToks) $ do
         pts <- Map.lookup p (predMap sign)
         if isSingleton pts
             then return $ mkIsaConstT True ga l p baseSign tyToks
             else do
                   i <- elemIndex (toPredType pt) (Set.toList pts)
                   return $ mkIsaConstIT True ga l p (i + 1) baseSign tyToks
transPredSymb _ _ (Pred_name _) = error "CASL2Isabelle: unqualified predicate"

mapSen :: FormulaTranslator f e -> CASL.Sign.Sign f e -> Set.Set String
       -> FORMULA f -> Sentence
mapSen trForm sign tyToks =
    mkSen . transFORMULA sign tyToks trForm (getAssumpsToks sign)

transRecord :: CASL.Sign.Sign f e -> Set.Set String -> FormulaTranslator f e
            -> Set.Set String -> Record f Term Term
transRecord sign tyToks tr toks = Record
    { foldQuantification = \ _ qu vdecl phi _ ->
          foldr (quantify toks qu) phi (flatVAR_DECLs vdecl)
    , foldConjunction = \ _ phis _ ->
          if null phis then true else foldr1 binConj phis
    , foldDisjunction = \ _ phis _ ->
          if null phis then false else foldr1 binDisj phis
    , foldImplication = \ _ phi1 phi2 _ _ -> binImpl phi1 phi2
    , foldEquivalence = \ _ phi1 phi2 _ -> binEqv phi1 phi2
    , foldNegation = \ _ phi _ -> termAppl notOp phi
    , foldTrue_atom = \ _ _ -> true
    , foldFalse_atom = \ _ _ -> false
    , foldPredication = \ _ psymb args _ ->
          foldl termAppl (con $ transPredSymb sign tyToks psymb) args
    , foldDefinedness = \ _ _ _ -> true -- totality assumed
    , foldExistl_equation = \ _ t1 t2 _ -> binEq t1 t2 -- equal types assumed
    , foldStrong_equation = \ _ t1 t2 _ -> binEq t1 t2 -- equal types assumed
    , foldMembership = \ _ _ _ _ -> true -- no subsorting assumed
    , foldMixfix_formula = error "transRecord: Mixfix_formula"
    , foldSort_gen_ax = error "transRecord: Sort_gen_ax"
    , foldQuantOp = error "transRecord: QuantOp"
    , foldQuantPred = error "transRecord: QuantPred"
    , foldExtFORMULA = \ _ -> tr sign tyToks
    , foldQual_var = \ _ v _ _ -> mkFree $ transVar toks v
    , foldApplication = \ _ opsymb args _ ->
          foldl termAppl (con $ transOpSymb sign tyToks opsymb) args
    , foldSorted_term = \ _ t _ _ -> t -- no subsorting assumed
    , foldCast = \ _ t _ _ -> t -- no subsorting assumed
    , foldConditional = \ _ t1 phi t2 _ -> -- equal types assumed
          If phi t1 t2 NotCont
    , foldMixfix_qual_pred = error "transRecord: Mixfix_qual_pred"
    , foldMixfix_term = error "transRecord: Mixfix_term"
    , foldMixfix_token = error "transRecord: Mixfix_token"
    , foldMixfix_sorted_term = error "transRecord: Mixfix_sorted_term"
    , foldMixfix_cast = error "transRecord: Mixfix_cast"
    , foldMixfix_parenthesized = error "transRecord: Mixfix_parenthesized"
    , foldMixfix_bracketed = error "transRecord: Mixfix_bracketed"
    , foldMixfix_braced = error "transRecord: Mixfix_braced"
    , foldExtTERM = error "transRecord: ExtTERM"
    }

transFORMULA :: CASL.Sign.Sign f e -> Set.Set String -> FormulaTranslator f e
             -> Set.Set String -> FORMULA f -> Term
transFORMULA sign tyToks tr = foldFormula . transRecord sign tyToks tr
