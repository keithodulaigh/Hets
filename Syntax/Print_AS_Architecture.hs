{-|

Module      :  $Header$
Copyright   :  (c) Klaus L�ttich, Uni Bremen 2002-2004
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  luettich@tzi.de
Stability   :  provisional
Portability :  non-portable(Grothendieck)

Printing the Architechture stuff of HetCASL.
-}

module Syntax.Print_AS_Architecture where

import Common.Doc
import Common.DocUtils
import Common.PrettyPrint
import Common.Keywords
import Common.PPUtils()

import Syntax.AS_Architecture
import Syntax.Print_AS_Structured

instance PrettyPrint ARCH_SPEC where
    printText0 = toOldText

instance Pretty ARCH_SPEC where
    pretty a = case a of
        Basic_arch_spec aa ab _ -> fsep $ keyword (unitS ++ sS)
               : punctuate semi (map pretty aa)
               ++ [keyword resultS, pretty ab]
        Arch_spec_name aa -> pretty aa
        Group_arch_spec aa _ -> specBraces $ pretty aa

instance PrettyPrint UNIT_REF where
    printText0 = toOldText

instance Pretty UNIT_REF where
    pretty (Unit_ref aa ab  _) =
        fsep [structSimpleId aa, keyword toS, pretty ab]

instance PrettyPrint UNIT_DECL_DEFN where
    printText0 = toOldText

instance Pretty UNIT_DECL_DEFN where
    pretty ud = case ud of
        Unit_decl aa ab ac _ ->
            fsep $ [structSimpleId aa, colon, pretty ab] ++
                 if null ac then [] else
                     keyword givenS : punctuate comma (map pretty ac)
        Unit_defn aa ab _ -> fsep $ [structSimpleId aa, equals, pretty ab]

instance PrettyPrint UNIT_SPEC where
    printText0 = toOldText

instance Pretty UNIT_SPEC where
    pretty u = case u of
        Unit_type aa ab _ ->
          let ab' = pretty ab
          in if null aa then ab' else fsep $
             punctuate (space <> cross) (map pretty aa) ++ [funArrow, ab']
        Spec_name aa -> pretty aa
        Closed_unit_spec aa _ -> fsep [keyword closedS, pretty aa]

instance PrettyPrint REF_SPEC where
    printText0 = toOldText

instance Pretty REF_SPEC where
    pretty rs = case rs of
        Unit_spec u -> pretty u
        Refinement b u m r _ -> fsep $
            [(if b then empty else keyword behaviourallyS <> space)
            <> keyword refinedS, pretty u]
            ++ (if null m then [] else keyword viaS :
                punctuate comma (map pretty m))
            ++ [keyword toS, pretty r]
        Arch_unit_spec aa _ ->
            fsep [keyword archS <+> keyword specS, pretty aa]
        Compose_ref aa _ -> case aa of
            [] -> empty
            x : xs -> sep $ pretty x :
               map ( \ s -> keyword thenS <+> pretty s) xs
        Component_ref aa _ ->
            specBraces $ fsep $ punctuate comma $ map pretty aa

instance PrettyPrint UNIT_EXPRESSION where
    printText0 = toOldText

instance Pretty UNIT_EXPRESSION where
    pretty (Unit_expression aa ab _) =
        let ab' = pretty ab
        in if null aa then ab'
           else fsep $ keyword lambdaS :
                    punctuate semi (map pretty aa)
                    ++ [addBullet ab']

instance PrettyPrint UNIT_BINDING where
    printText0 = toOldText

instance Pretty UNIT_BINDING where
    pretty (Unit_binding aa ab _) =
        let aa' = pretty aa
            ab' = pretty ab
        in fsep [aa', colon, ab']

instance PrettyPrint UNIT_TERM where
    printText0 = toOldText

instance Pretty UNIT_TERM where
    pretty ut = case ut of
        Unit_reduction aa ab ->
          let aa' = pretty aa
              ab' = pretty ab
          in fsep [aa', ab']
        Unit_translation aa ab ->
          let aa' = pretty aa
              ab' = pretty ab
          in fsep [aa', ab']
        Amalgamation aa _ -> case aa of
            [] -> empty
            x : xs -> sep $ pretty x :
               map ( \ s -> keyword andS <+> pretty s) xs
        Local_unit aa ab _ ->
            fsep $ keyword localS : punctuate semi (map pretty aa)
                        ++ [keyword withinS, pretty ab]
        Unit_appl aa ab _ -> fsep $ structSimpleId aa : map pretty ab
        Group_unit_term aa _ -> specBraces $ pretty aa

instance PrettyPrint FIT_ARG_UNIT where
    printText0 = toOldText

instance Pretty FIT_ARG_UNIT where
    pretty (Fit_arg_unit aa ab _) = brackets $
        fsep $ pretty aa : if null ab then []
               else keyword fitS : punctuate comma (map pretty ab)
