{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder, Uni Bremen 2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

supply folding on CASL terms and formulas

-}

module CASL.Fold where

import Common.Id
import CASL.AS_Basic_CASL


data Record f a b = Record
    { foldQuantification :: FORMULA f -> QUANTIFIER -> [VAR_DECL] -> 
                          a -> [Pos] -> a
    , foldConjunction :: FORMULA f -> [a] -> [Pos] -> a
    , foldDisjunction :: FORMULA f -> [a] -> [Pos] -> a
    , foldImplication :: FORMULA f -> a  -> a  -> Bool -> [Pos] -> a
    , foldEquivalence :: FORMULA f -> a  -> a  -> [Pos] -> a
    , foldNegation :: FORMULA f -> a  -> [Pos] -> a
    , foldTrue_atom :: FORMULA f -> [Pos] -> a
    , foldFalse_atom :: FORMULA f -> [Pos] -> a
    , foldPredication :: FORMULA f -> PRED_SYMB -> [b] -> [Pos] -> a
    , foldDefinedness :: FORMULA f -> b -> [Pos] -> a
    , foldExistl_equation :: FORMULA f -> b -> b -> [Pos] -> a
    , foldStrong_equation :: FORMULA f -> b -> b -> [Pos] -> a
    , foldMembership :: FORMULA f -> b -> SORT -> [Pos] -> a
    , foldMixfix_formula :: FORMULA f -> b -> a
    , foldUnparsed_formula :: FORMULA f -> String -> [Pos] -> a
    , foldSort_gen_ax :: FORMULA f -> [Constraint] -> Bool -> a
    , foldExtFORMULA :: FORMULA f -> f -> a
    , foldSimple_id :: TERM f -> SIMPLE_ID -> b
    , foldQual_var :: TERM f -> VAR -> SORT -> [Pos] -> b
    , foldApplication :: TERM f -> OP_SYMB -> [b] -> [Pos] -> b
    , foldSorted_term :: TERM f ->  b -> SORT -> [Pos] -> b
    , foldCast :: TERM f -> b -> SORT -> [Pos] -> b
    , foldConditional :: TERM f -> b -> a -> b -> [Pos] -> b
    , foldUnparsed_term :: TERM f -> String -> [Pos] -> b
    , foldMixfix_qual_pred :: TERM f -> PRED_SYMB -> b
    , foldMixfix_term :: TERM f -> [b] -> b
    , foldMixfix_token :: TERM f -> Token -> b
    , foldMixfix_sorted_term :: TERM f -> SORT -> [Pos] -> b
    , foldMixfix_cast :: TERM f -> SORT -> [Pos] -> b
    , foldMixfix_parenthesized :: TERM f -> [b] -> [Pos] -> b
    , foldMixfix_bracketed :: TERM f -> [b] -> [Pos] -> b
    , foldMixfix_braced :: TERM f -> [b] -> [Pos] -> b
    }

idRecord :: Record f (FORMULA f) (TERM f)
idRecord = Record
    { foldQuantification = \ _ -> Quantification  
    , foldConjunction = \ _ -> Conjunction  
    , foldDisjunction = \ _ -> Disjunction  
    , foldImplication = \ _ -> Implication  
    , foldEquivalence = \ _ -> Equivalence  
    , foldNegation = \ _ -> Negation  
    , foldTrue_atom = \ _ -> True_atom  
    , foldFalse_atom = \ _ -> False_atom  
    , foldPredication = \ _ -> Predication  
    , foldDefinedness = \ _ -> Definedness  
    , foldExistl_equation = \ _ -> Existl_equation  
    , foldStrong_equation = \ _ -> Strong_equation  
    , foldMembership = \ _ -> Membership  
    , foldMixfix_formula = \ _ -> Mixfix_formula  
    , foldUnparsed_formula = \ _ -> Unparsed_formula  
    , foldSort_gen_ax = \ _ -> Sort_gen_ax  
    , foldExtFORMULA = \ _ -> ExtFORMULA  
    , foldSimple_id = \ _ -> Simple_id  
    , foldQual_var = \ _ -> Qual_var  
    , foldApplication = \ _ -> Application  
    , foldSorted_term = \ _ -> Sorted_term  
    , foldCast = \ _ -> Cast  
    , foldConditional = \ _ -> Conditional  
    , foldUnparsed_term = \ _ -> Unparsed_term  
    , foldMixfix_qual_pred = \ _ -> Mixfix_qual_pred  
    , foldMixfix_term = \ _ -> Mixfix_term  
    , foldMixfix_token = \ _ -> Mixfix_token  
    , foldMixfix_sorted_term = \ _ -> Mixfix_sorted_term  
    , foldMixfix_cast = \ _ -> Mixfix_cast  
    , foldMixfix_parenthesized = \ _ -> Mixfix_parenthesized  
    , foldMixfix_bracketed = \ _ -> Mixfix_bracketed  
    , foldMixfix_braced = \ _ -> Mixfix_braced  
    }

mapFormula :: Record f a b -> FORMULA f -> a
mapFormula r f = case f of 
   Quantification q vs e ps -> foldQuantification r f q vs (mapFormula r e) ps
   Conjunction fs ps -> foldConjunction r f (map (mapFormula r) fs) ps
   Disjunction fs ps -> foldDisjunction r f (map (mapFormula r) fs) ps
   Implication f1 f2 b ps -> foldImplication r f (mapFormula r f1)
      (mapFormula r f2) b ps
   Equivalence f1 f2 ps -> foldEquivalence r f (mapFormula r f1)
      (mapFormula r f2) ps
   Negation e ps -> foldNegation r f (mapFormula r e) ps
   True_atom ps -> foldTrue_atom r f ps
   False_atom ps -> foldFalse_atom  r f ps
   Predication p ts ps -> foldPredication r f p (map (mapTerm r) ts) ps
   Definedness t ps -> foldDefinedness r f (mapTerm r t) ps
   Existl_equation t1 t2 ps -> foldExistl_equation r f (mapTerm r t1) 
      (mapTerm r t2) ps
   Strong_equation t1 t2 ps -> foldStrong_equation r f (mapTerm r t1) 
      (mapTerm r t2) ps 
   Membership t s ps -> foldMembership r f (mapTerm r t) s ps
   Mixfix_formula t -> foldMixfix_formula r f (mapTerm r t)
   Unparsed_formula s ps -> foldUnparsed_formula r f s ps
   Sort_gen_ax cs b -> foldSort_gen_ax r f cs b
   ExtFORMULA e -> foldExtFORMULA r f e

mapTerm :: Record f a b -> TERM f -> b
mapTerm r t = case t of
   Simple_id i -> foldSimple_id r t i
   Qual_var v s ps -> foldQual_var r t v s ps 
   Application o ts ps -> foldApplication r t o (map (mapTerm r) ts) ps
   Sorted_term st s ps -> foldSorted_term r t (mapTerm r st) s ps
   Cast ct s ps -> foldCast r t (mapTerm r ct) s ps
   Conditional t1 f t2 ps -> foldConditional r t (mapTerm r t1)
      (mapFormula r f) (mapTerm r t2) ps
   Unparsed_term s ps -> foldUnparsed_term r t s ps
   Mixfix_qual_pred p -> foldMixfix_qual_pred r t p
   Mixfix_term ts -> foldMixfix_term r t (map (mapTerm r) ts)
   Mixfix_token s -> foldMixfix_token r t s
   Mixfix_sorted_term s ps -> foldMixfix_sorted_term r t s ps
   Mixfix_cast s ps -> foldMixfix_cast r t s ps
   Mixfix_parenthesized ts ps -> foldMixfix_parenthesized r t
      (map (mapTerm r) ts) ps
   Mixfix_bracketed ts ps -> foldMixfix_bracketed r t
      (map (mapTerm r) ts) ps
   Mixfix_braced ts ps -> foldMixfix_braced r t
      (map (mapTerm r) ts) ps
