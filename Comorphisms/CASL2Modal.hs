{- |
Module      :  $Header$
Copyright   :  (c) Till Mossakowski and Uni Bremen 2004
Licence     :  All rights reserved.

Maintainer  :  hets@tzi.de
Stability   :  provisional
Portability :  non-portable (imports Logic.Logic)

   
   The embedding comorphism from CASL to ModalCASL.

-}

module Comorphisms.CASL2Modal where

import Logic.Logic
import Logic.Comorphism
import qualified Common.Lib.Set as Set
import Common.AS_Annotation

-- CASL
import CASL.Logic_CASL 
import CASL.Sublogic
import CASL.Sign
import CASL.AS_Basic_CASL
import CASL.Morphism

-- ModalCASL
import Modal.Logic_Modal
import Modal.AS_Modal
import Modal.ModalSign

-- | The identity of the comorphism
data CASL2Modal = CASL2Modal deriving (Show)

instance Language CASL2Modal -- default definition is okay

instance Comorphism CASL2Modal
               CASL CASL_Sublogics
               CASLBasicSpec CASLFORMULA SYMB_ITEMS SYMB_MAP_ITEMS
               CASLSign 
               CASLMor
               Symbol RawSymbol ()
               Modal ()
               M_BASIC_SPEC ModalFORMULA SYMB_ITEMS SYMB_MAP_ITEMS
               MSign 
               ModalMor
               Symbol RawSymbol () where
    sourceLogic CASL2Modal = CASL
    sourceSublogic CASL2Modal = CASL_SL
                      { has_sub = True, 
                        has_part = True,
                        has_cons = True,
                        has_eq = True,
                        has_pred = True,
                        which_logic = FOL
                      }
    targetLogic CASL2Modal = Modal
    targetSublogic CASL2Modal = ()
    map_sign CASL2Modal sig = let e = mapSig sig in Just (e, [])
    map_morphism CASL2Modal = Just . mapMor
    map_sentence CASL2Modal _ = Just . mapSen
    map_symbol CASL2Modal = Set.single . mapSym

mapSig :: CASLSign -> MSign
mapSig sign = 
     (emptySign emptyModalSign) {sortSet = sortSet sign
	       , sortRel = sortRel sign
               , opMap = opMap sign
	       , assocOps = assocOps sign
	       , predMap = predMap sign
               , varMap = varMap sign
	       , sentences = map (mapNamed mapSen) $ sentences sign
	       , envDiags = envDiags sign }

mapMor :: CASLMor -> ModalMor
mapMor m = Morphism {msource = mapSig $ msource m
	           , mtarget = mapSig $ mtarget m
                   , sort_map = sort_map m
                   , fun_map = fun_map m
                   , pred_map = pred_map m
	           , extended_map = ()}


mapSym :: Symbol -> Symbol
mapSym = id  -- needs to be changed once modal symbols are added


mapSen :: CASLFORMULA -> ModalFORMULA
mapSen f = case f of 
    Quantification q vs frm ps ->
	Quantification q vs (mapSen frm) ps
    Conjunction fs ps -> 
        Conjunction (map mapSen fs) ps 
    Disjunction fs ps -> 
        Disjunction (map mapSen fs) ps
    Implication f1 f2 b ps ->
	Implication (mapSen f1) (mapSen f2) b ps
    Equivalence f1 f2 ps -> 
	Equivalence (mapSen f1) (mapSen f2) ps
    Negation frm ps -> Negation (mapSen frm) ps
    True_atom ps -> True_atom ps
    False_atom ps -> False_atom ps
    Existl_equation t1 t2 ps -> 
	Existl_equation (mapTERM t1) (mapTERM t2) ps
    Strong_equation t1 t2 ps -> 
	Strong_equation (mapTERM t1) (mapTERM t2) ps
    Predication pn as qs ->
        Predication pn (map mapTERM as) qs
    Definedness t ps -> Definedness (mapTERM t) ps
    Membership t ty ps -> Membership (mapTERM t) ty ps
    Sort_gen_ax constrs -> Sort_gen_ax constrs
    _ -> error "CASL2Modal.mapSen"

mapTERM :: TERM () -> TERM M_FORMULA
mapTERM t = case t of
    Qual_var v ty ps -> Qual_var v ty ps
    Application opsym as qs  -> Application opsym (map mapTERM as) qs
    Sorted_term trm ty ps -> Sorted_term (mapTERM trm) ty ps 
    Cast trm ty ps -> Cast (mapTERM trm) ty ps 
    Conditional t1 f t2 ps -> 
       Conditional (mapTERM t1) (mapSen f) (mapTERM t2) ps
    _ -> error "CASL2Modal.mapTERM"
