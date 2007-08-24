{- |
Module      :  $Header$
Description :  replace casts with explicit projection functions
Copyright   :  (c) Christian Maeder, Uni Bremen 2005-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

Replace casts with explicit projection functions


This module replaces Cast(s) with explicit projection
   functions.  Don't do this after simplification since crucial sort
   information may be missing

   Membership test are replaced with Definedness formulas

   projection names may be also made unique by appending the source
   and target sort
-}

module CASL.Project where

import CASL.AS_Basic_CASL
import CASL.Overload
import CASL.Fold
import Common.Id

project :: FunKind -> Range -> TERM f -> SORT -> TERM f
project fk pos argument result_type = let argument_type = term_sort argument in
    if argument_type == result_type then argument else
    Application (projOpSymb fk pos argument_type result_type)
                    [argument] nullRange

projOpSymb :: FunKind -> Range -> SORT -> SORT -> OP_SYMB
projOpSymb fk pos s1 s2 =
    Qual_op_name projName (Op_type fk [s1] s2 pos) pos

projRecord :: FunKind -> (f -> f) -> Record f (FORMULA f) (TERM f)
projRecord fk mf = (mapRecord mf)
     { foldCast = \ _ st s ps -> project fk ps st s
     , foldMembership = \ _ t s ps -> Definedness (project fk ps t s) ps
     }

projTerm :: FunKind -> (f -> f) -> TERM f -> TERM f
projTerm fk = foldTerm . projRecord fk

projFormula :: FunKind -> (f -> f) -> FORMULA f -> FORMULA f
projFormula fk = foldFormula . projRecord fk

stripComps :: Id -> Id
stripComps (Id ts _ ps) = Id ts [] ps

uniqueProjName :: OP_TYPE -> Id
uniqueProjName t = case t of
    Op_type _ [from@(Id _ fcs _)] to@(Id _ tcs _) ps -> Id
        [Token (showId projName "_" ++ showId (stripComps from) "_"
                ++ showId (stripComps to) "") ps]
        (if fcs == tcs then fcs else fcs ++ tcs) ps
    _ -> error "CASL.Project.uniqueProjName"

bottom :: Id
bottom = genName "bottom"

uniqueBotName :: OP_TYPE -> Id
uniqueBotName t = case t of
    Op_type _ [] to@(Id _ tcs _) ps -> Id
        [Token (showId bottom "_" ++ showId (stripComps to) "") ps] tcs ps
    _ -> error "CASL.Project.uniqueBotName"

projectUnique :: FunKind -> Range -> TERM f -> SORT -> TERM f
projectUnique fk pos argument result_type =
    let argument_type = term_sort argument in
    if argument_type == result_type then argument else
    Application (uniqueProjOpSymb fk pos argument_type result_type)
                    [argument] nullRange

uniqueProjOpSymb :: FunKind -> Range -> SORT -> SORT -> OP_SYMB
uniqueProjOpSymb fk pos s1 s2 = let t = Op_type fk [s1] s2 pos in
    Qual_op_name (uniqueProjName t) t pos

rename :: OP_SYMB -> OP_SYMB
rename o = case o of
    Qual_op_name i t r -> Qual_op_name
        (if i == projName then uniqueProjName t
         else if i == bottom then uniqueBotName t
              else i) t r
    _ -> o

renameRecord :: (f -> f) -> Record f (FORMULA f) (TERM f)
renameRecord mf = (mapRecord mf)
     { foldApplication = \ _ o args r -> Application (rename o) args r
     }

renameTerm :: (f -> f) -> TERM f -> TERM f
renameTerm = foldTerm . renameRecord

renameFormula :: (f -> f) -> FORMULA f -> FORMULA f
renameFormula = foldFormula . renameRecord
