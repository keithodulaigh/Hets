{- |
Module      :  $Header$
Copyright   :  (c) Felix Gabriel Mance
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  f.mance@jacobs-university.de
Stability   :  provisional
Portability :  portable

Contains    :  Get the Axioms from the Manchester Syntax frames
-}

module OWL2.GetAxioms where

import OWL2.AS
import OWL2.MS
import OWL2.FS

convertFrameBit :: Entity -> FrameBit -> [Axiom]
convertFrameBit (Entity e iri) fb = case fb of
    AnnotationFrameBit ans -> [PlainAxiom ans $ AnnotationAssertion iri]
    AnnotationBit r (AnnotatedList x) ->  map (\ (ans, b) -> PlainAxiom ans $ AnnotationAxiom r iri b) x
    DatatypeBit ans dr -> [PlainAxiom ans $ DatatypeDefinition iri dr]
    ExpressionBit r (AnnotatedList x) ->
        case e of
          Class -> case r of
            SubClass -> map (\ (ans, b) -> PlainAxiom ans $ SubClassOf (Expression iri) b) x
            _ -> map (\ f -> PlainAxiom (fst f)
                    $ EquivOrDisjointClasses (getED r)
                          [Expression iri, snd f]) x
          ObjectProperty -> map (\ (ans, b) -> PlainAxiom ans $ ObjectPropertyDomainOrRange (getDR r) (ObjectProp iri) b) x
          DataProperty -> map (\ (ans, b) -> PlainAxiom ans $ DataPropertyDomainOrRange (DataDomain b) iri) x
          NamedIndividual -> map (\ (ans, b) -> PlainAxiom ans $ ClassAssertion b iri) x
          _ -> error "incorrect binding of class expression to entity"
    ClassDisjointUnion ans ce -> [PlainAxiom ans $ DisjointUnion iri ce]
    ClassHasKey ans opl dpl -> [PlainAxiom ans $ HasKey (Expression iri) opl dpl]
    ObjectBit r (AnnotatedList x) ->
        case r of
          InverseOf -> map (\ (ans, b) -> PlainAxiom ans $ InverseObjectProperties (ObjectProp iri) b) x
          SubPropertyOf -> map (\ (ans, b) -> PlainAxiom ans $ SubObjectPropertyOf (OPExpression b) (ObjectProp iri)) x
          _ -> map (\ f -> PlainAxiom (fst f)
                    $ EquivOrDisjointObjectProperties (getED r)
                          [ObjectProp iri, snd f]) x
    ObjectCharacteristics (AnnotatedList anc) ->
              map (\ (ans, b) -> PlainAxiom ans $ ObjectPropertyCharacter b (ObjectProp iri)) anc
    ObjectSubPropertyChain ans opl -> [PlainAxiom ans
              $ SubObjectPropertyOf (SubObjectPropertyChain opl) (ObjectProp iri)]
    DataBit ed (AnnotatedList x) ->
        case ed of
          SubPropertyOf -> map (\ (ans, b) -> PlainAxiom ans $ SubDataPropertyOf iri b) x
          _ -> map (\ f -> PlainAxiom (fst f)
                    $ EquivOrDisjointDataProperties (getED ed)
                          [iri, snd f]) x
    DataPropRange (AnnotatedList x) -> map (\ (ans, b) -> PlainAxiom ans $ DataPropertyDomainOrRange (DataRange b) iri) x
    DataFunctional anl -> [PlainAxiom anl $ FunctionalDataProperty iri]
    IndividualFacts (AnnotatedList x) -> map (\ (ans, b) -> PlainAxiom ans $ (convertFact iri b)) x
    IndividualSameOrDifferent sd (AnnotatedList x) -> map (\ f -> PlainAxiom (fst f)
                        $ SameOrDifferentIndividual sd [iri, snd f]) x
convertFact :: Individual -> Fact -> PlainAxiom
convertFact i f = case f of
    ObjectPropertyFact pn ope i2 -> ObjectPropertyAssertion $ Assertion ope pn i i2
    DataPropertyFact pn dpe l -> DataPropertyAssertion $ Assertion dpe pn i l

convertMisc :: EquivOrDisjoint -> Annotations -> Misc -> Axiom
convertMisc ed x misc = case misc of
    MiscEquivOrDisjointClasses l -> PlainAxiom x $ EquivOrDisjointClasses ed l
    MiscEquivOrDisjointObjProp l -> PlainAxiom x $ EquivOrDisjointObjectProperties ed l
    MiscEquivOrDisjointDataProp l -> PlainAxiom x $ EquivOrDisjointDataProperties ed l

getAxioms :: Frame -> [Axiom]
getAxioms f = case f of
    Frame e fbl -> concatMap (convertFrameBit e) fbl
    MiscFrame ed ans misc -> [convertMisc ed ans misc]
    MiscSameOrDifferent sd x il ->
        [PlainAxiom x $ SameOrDifferentIndividual sd il]
