{-# OPTIONS -cpp #-}
{- |
Module      :  $Header$
Description :  instance of the class Logic for OWL
Copyright   :  (c) Klaus Luettich, Heng Jiang, Uni Bremen 2002-2004
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  luecke@informatik.uni-bremen.de
Stability   :  provisional
Portability :  portable

Here is the place where the class Logic is instantiated for OWL DL.
__SROIQ__
-}

module OWL.Logic_OWL where

import Common.AS_Annotation
import Common.Doc
import Common.DocUtils
import Common.ProofTree

import ATC.ProofTree ()

import Logic.Logic

import OWL.AS
import OWL.Parse
import OWL.Print ()
import OWL.ATC_OWL ()
import OWL.Sign
import OWL.StaticAnalysis
import OWL.Sublogic
import OWL.Morphism
import Common.Consistency
#ifdef UNI_PACKAGE
import OWL.ProvePellet
import OWL.Conservativity
import OWL.Taxonomy
#endif

data OWL = OWL deriving Show

instance Language OWL where
 description _ =
  "OWL DL -- Web Ontology Language Description Logic http://wwww.w3c.org/"

instance Syntax OWL OntologyFile () () where
    parse_basic_spec OWL = Just basicSpec

-- OWL DL logic

instance Sentences OWL Sentence Sign OWL_Morphism () where
    map_sen OWL _ s = return s
    print_named OWL namedSen =
        pretty (sentence namedSen) <>
          if isAxiom namedSen then empty else space <> text "%implied"

instance StaticAnalysis OWL OntologyFile Sentence
               () ()
               Sign
               OWL_Morphism
               () ()   where
{- these functions are be implemented in OWL.StaticAna and OWL.Sign: -}
      basic_analysis OWL = Just basicOWLAnalysis
      empty_signature OWL = emptySign
      signature_union OWL s = return . addSign s
      final_union OWL = signature_union OWL
      inclusion OWL = owlInclusion
      theory_to_taxonomy OWL = onto2Tax

{-   this function will be implemented in OWL.Taxonomy
         theory_to_taxonomy OWL = convTaxo
-}

instance Logic OWL OWL_SL OntologyFile Sentence () ()
               Sign
               OWL_Morphism () () ProofTree where
    --     stability _ = Testing
    -- default implementations are fine
    -- the prover uses HTk and IO functions from uni
#ifdef UNI_PACKAGE
         provers OWL = [pelletProver]
         cons_checkers OWL = [pelletConsChecker]
         conservativityCheck OWL =
             [
              ConservativityChecker "Locality_BOTTOM_BOTTOM" (conserCheck
                                                              "BOTTOM_BOTTOM")
             ,ConservativityChecker "Locality_TOP_BOTTOM" (conserCheck
                                                           "TOP_BOTTOM")
             ,ConservativityChecker "Locality_TOP_TOP" (conserCheck
                                                        "TOP_TOP")
             ]
#endif

instance SemiLatticeWithTop (OWL_SL) where
    join = sl_max
    top = sl_top

instance SublogicName (OWL_SL) where
    sublogicName = sl_name

instance MinSublogic OWL_SL Sentence where
    minSublogic = sl_basic_spec

instance MinSublogic OWL_SL OWL_Morphism where
    minSublogic = sl_mor

instance ProjectSublogic OWL_SL OWL_Morphism where
    projectSublogic = pr_mor

instance MinSublogic OWL_SL Sign where
    minSublogic = sl_sig

instance ProjectSublogic OWL_SL Sign where
    projectSublogic = pr_sig

instance MinSublogic OWL_SL () where
    minSublogic _ = sl_top

instance MinSublogic OWL_SL OntologyFile where
    minSublogic = sl_o_file

instance ProjectSublogicM OWL_SL () where
    projectSublogicM _ _ = return ()

instance ProjectSublogic OWL_SL OntologyFile where
    projectSublogic = pr_o_file
