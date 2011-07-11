{-# LANGUAGE MultiParamTypeClasses, TypeSynonymInstances #-}
{- |
Module      :  $Header$
Description :  Comorphism from OWL 1.1 to CASL_Dl
Copyright   :  (c) Uni Bremen 2007
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  luecke@informatik.uni-bremen.de
Stability   :  provisional
Portability :  non-portable (via Logic.Logic)

a not yet implemented comorphism
-}

module OWL2.OWL22CASL (OWL22CASL (..)) where

import Logic.Logic as Logic
import Logic.Comorphism
import Common.AS_Annotation
import Common.Result
import Common.Id
import Control.Monad
import Data.Char
import qualified Data.Set as Set
import qualified Data.Map as Map
import qualified Common.Lib.MapSet as MapSet
import qualified Common.Lib.Rel as Rel

-- OWL = domain
import OWL2.Logic_OWL2
import OWL2.MS
import OWL2.AS
import OWL2.Sublogic
import OWL2.ManchesterPrint()
import OWL2.Morphism
import OWL2.Symbols
import OWL2.ATC_OWL2
import OWL2.Keywords
import OWL2.Morphism
import qualified OWL2.Sign as OS
-- CASL_DL = codomain
import CASL.Logic_CASL
import CASL.AS_Basic_CASL
import CASL.Sign
import CASL.Morphism
import CASL.Sublogic

import Common.ProofTree

import Maybe

data OWL22CASL = OWL22CASL deriving Show

instance Language OWL22CASL

instance Comorphism
    OWL22CASL        -- comorphism
    OWL2             -- lid domain
    OWLSub          -- sublogics domain
    OntologyDocument    -- Basic spec domain
    Axiom           -- sentence domain
    SymbItems       -- symbol items domain
    SymbMapItems    -- symbol map items domain
    OS.Sign         -- signature domain
    OWLMorphism     -- morphism domain
    Entity          -- symbol domain
    RawSymb         -- rawsymbol domain
    ProofTree       -- proof tree codomain
    CASL            -- lid codomain
    CASL_Sublogics  -- sublogics codomain
    CASLBasicSpec   -- Basic spec codomain
    CASLFORMULA     -- sentence codomain
    SYMB_ITEMS      -- symbol items codomain
    SYMB_MAP_ITEMS  -- symbol map items codomain
    CASLSign        -- signature codomain
    CASLMor         -- morphism codomain
    Symbol          -- symbol codomain
    RawSymbol       -- rawsymbol codomain
    ProofTree       -- proof tree domain
    where
      sourceLogic OWL22CASL = OWL2
      sourceSublogic OWL22CASL = sl_top
      targetLogic OWL22CASL = CASL
      mapSublogic OWL22CASL _ = Just $ cFol
        { cons_features = emptyMapConsFeature }
      map_theory OWL22CASL = mapTheory
      map_morphism OWL22CASL = mapMorphism
      isInclusionComorphism OWL22CASL = True
      has_model_expansion OWL22CASL = True

-- | Mapping of OWL morphisms to CASL morphisms
mapMorphism :: OWLMorphism -> Result CASLMor
mapMorphism oMor =
    do
      cdm <- mapSign $ osource oMor
      ccd <- mapSign $ otarget oMor
      let emap = mmaps oMor
          preds = Map.foldWithKey (\ (Entity ty u1) u2 -> let
              i1 = uriToId u1
              i2 = uriToId u2
              in case ty of
                Class -> Map.insert (i1, conceptPred) i2
                ObjectProperty -> Map.insert (i1, objectPropPred) i2
                DataProperty -> Map.insert (i1, dataPropPred) i2
                _ -> id) Map.empty emap
          ops = Map.foldWithKey (\ (Entity ty u1) u2 -> case ty of
                NamedIndividual ->
                    Map.insert (uriToId u1, indiConst) (uriToId u2, Total)
                _ -> id) Map.empty emap
      return (embedMorphism () cdm ccd)
                 { op_map = ops
                 , pred_map = preds }

-- | OWL topsort Thing
thing :: Id
thing = stringToId "Thing"

noThing :: Id
noThing = stringToId "Nothing"

-- | OWL bottom
mkThingPred :: Id -> PRED_SYMB
mkThingPred i =
  Qual_pred_name i (toPRED_TYPE conceptPred) nullRange

-- | OWL Data topSort DATA
dataS :: SORT
dataS = stringToId dATAS

data VarOrIndi = OVar Int | OIndi IRI

predefSorts :: Set.Set SORT
predefSorts = Set.singleton thing

hetsPrefix :: String
hetsPrefix = ""

conceptPred :: PredType
conceptPred = PredType [thing]

objectPropPred :: PredType
objectPropPred = PredType [thing, thing]

dataPropPred :: PredType
dataPropPred = PredType [thing, dataS]

indiConst :: OpType
indiConst = OpType Total [] thing

mapSign :: OS.Sign                 -- ^ OWL signature
        -> Result CASLSign         -- ^ CASL signature
mapSign sig =
      let conc = OS.concepts sig
          cvrt = map uriToId . Set.toList
          tMp k = MapSet.fromList . map (\ u -> (u, [k]))
          cPreds = thing : noThing : cvrt conc
          oPreds = cvrt $ OS.objectProperties sig
          dPreds = cvrt $ OS.dataProperties sig
          aPreds = foldr MapSet.union MapSet.empty
            [ tMp conceptPred cPreds
            , tMp objectPropPred oPreds
            , tMp dataPropPred dPreds ]
     in return (emptySign ())
             { sortRel = Rel.fromKeysSet predefSorts
             , predMap = aPreds
             , opMap = tMp indiConst . cvrt $ OS.individuals sig
             }


loadDataInformation :: OWLSub -> Sign f ()
loadDataInformation _ =
    let
        dts = Set.fromList $ map stringToId datatypeKeys
    in
     (emptySign ()) { sortRel = Rel.fromKeysSet dts }
{-
loadDataInformation :: OWLSub -> Sign f ()
loadDataInformation sl =
    let
        dts = Set.map (stringToId . printXSDName) $ datatype sl
    in
     (emptySign ()) { sortRel = Rel.fromKeysSet dts }
-}

predefinedSentences :: [Named CASLFORMULA]
predefinedSentences =
    [
     makeNamed "nothing in Nothing" $
     Quantification Universal
     [Var_decl [mkNName 1] thing nullRange]
     (
      Negation
      (
       Predication
       (mkThingPred noThing)
       [Qual_var (mkNName 1) thing nullRange]
       nullRange
      )
      nullRange
     )
     nullRange
    ,
     makeNamed "thing in Thing" $
     Quantification Universal
     [Var_decl [mkNName 1] thing nullRange]
     (
       Predication
       (mkThingPred thing)
       [Qual_var (mkNName 1) thing nullRange]
       nullRange
     )
     nullRange
    ]

mapTheory :: (OS.Sign, [Named Axiom])
             -> Result (CASLSign, [Named CASLFORMULA])
mapTheory (owlSig, owlSens) =
        let
            sublogic = sl_top
        in
    do
      cSig <- mapSign owlSig
      let pSig = loadDataInformation sublogic
      (cSensI, nSig) <- foldM (\ (x, y) z ->
                           do
                             (sen, sig) <- mapSentence y z
                             return (sen : x, uniteCASLSign sig y)
                             ) ([], cSig) owlSens
      let cSens = concatMap (\ x ->
                             case x of
                               Nothing -> []
                               Just a -> [a]
                        ) cSensI
      return (uniteCASLSign nSig pSig, predefinedSentences ++ cSens)

-- | mapping of OWL to CASL_DL formulae
mapSentence :: CASLSign                           -- ^ CASL Signature
  -> Named Axiom                                  -- ^ OWL2 Sentence
  -> Result (Maybe (Named CASLFORMULA), CASLSign) -- ^ CASL Sentence
mapSentence cSig inSen = do
    (outAx, outSig) <- mapAxiom cSig $ sentence inSen
    return (fmap (flip mapNamed inSen . const) outAx, outSig)


mapAxiom :: CASLSign                             -- ^ CASL Signature
         -> Axiom                                -- ^ OWL2 Axiom
         -> Result (Maybe CASLFORMULA, CASLSign) -- ^ CASL Formula
mapAxiom cSig _ = return (Nothing, cSig)


toIRILst :: EntityType 
         -> Extended
         -> Maybe IRI

toIRILst ty ane = case ane of
  SimpleEntity (Entity ty2 iri) | ty == ty2 -> Just iri
  _ -> Nothing



-- | Mapping of ListFrameBit
mapListFrameBit :: CASLSign 
       -> Extended
       -> Maybe Relation 
       -> ListFrameBit 
       -> Result ([CASLFORMULA], CASLSign)
mapListFrameBit cSig ex rel lfb = case lfb of
    AnnotationBit a -> return ([], cSig)
    ExpressionBit cls -> 
      case ex of
          Misc _ -> return ([], cSig)
          SimpleEntity (Entity ty iri) -> 
            case ty of 
              NamedIndividual | rel == Just Types -> 
                do
                  inD <- mapIndivURI cSig iri
                  ocls <- mapM (\ (_, c) -> mapDescription cSig c 1) cls 
                  return (map (\ cd -> Quantification Universal
                             [Var_decl [mkNName 1] thing nullRange]
                             (
                              Implication
                              (Strong_equation
                               (Qual_var (mkNName 1) thing nullRange)
                               inD
                               nullRange
                              ) cd
                              True
                              nullRange
                             )
                             nullRange) ocls, cSig)

              DataProperty | rel == (Just $ DRRelation ADomain)->
                do
                  oEx <- mapDataProp cSig iri 1 2
                  odes <- mapM (\ (_, c) -> mapDescription cSig c 1) cls 
                  let vars = (mkNName 1, mkNName 2)
                  return (map (\ cd -> Quantification Universal
                          [Var_decl [fst vars] thing nullRange]
                          (Quantification Existential
                          [Var_decl [snd vars] dataS nullRange]
                          (Implication oEx cd True nullRange)
                          nullRange) nullRange) odes, cSig)
                

              _ -> return ([], cSig)
{-
          ObjectEntity oe -> -- treat relation here
          ClassEntity ce -> -- treat relations here
-}
    ObjectBit ol -> 
      let mol = fmap ObjectProp (toIRILst ObjectProperty ex)
          isJ = isJust mol
          Just ob = mol
          map2nd = map snd ol
          fol = maybeToList mol ++ map2nd
          
      in case rel of 
      Nothing -> return ([], cSig)
      Just r -> case r of
        EDRelation ed -> do
          pairs <- mapComObjectPropsList cSig mol map2nd 1 2 
          return (map (\ (a, b) -> Quantification Universal
                              [ Var_decl [mkNName 1] thing nullRange
                              , Var_decl [mkNName 2] thing nullRange]
                                 (case ed of
                                   Equivalent ->
                                                Equivalence a b nullRange
                                   Disjoint ->
                                                 Negation
                                                 (Conjunction [a, b] nullRange)
                                                 nullRange)                                
                               nullRange) pairs, cSig)
        SubPropertyOf | isJ-> do
                  os <- mapM (\ (o1, o2) -> mapSubObjProp cSig o1 o2 3) $ comPairsaux ob map2nd
                  return (os, cSig)
        InverseOf | isJ ->
          do
             os1 <- mapM (\ o1 -> mapObjProp cSig o1 1 2) map2nd
             o2 <- mapObjProp cSig ob 2 1
             return (map (\ o1 -> Quantification Universal
                             [Var_decl [mkNName 1] thing nullRange
                             , Var_decl [mkNName 2] thing nullRange]
                             (
                              Equivalence
                              o2
                              o1
                              nullRange
                             )
                             nullRange) os1, cSig)
        _ -> return ([],cSig)

    DataBit db -> 
      let mol = toIRILst DataProperty ex
          isJ = isJust mol
          map2nd = map snd db
          Just ob = mol
          fol = maybeToList mol ++ map snd db
      in case rel of
      Nothing -> return ([], cSig)
      Just r -> case r of 
        SubPropertyOf | isJ -> do
          os1 <- mapM (\ o1 -> mapDataProp cSig o1 1 2) map2nd
          o2 <- mapDataProp cSig ob 2 1
          return (map (\ o1 -> Quantification Universal
                               [ Var_decl [mkNName 1] thing nullRange
                               , Var_decl [mkNName 2] dataS nullRange]
                               (
                                Implication
                                o2
                                o1
                                True
                                nullRange
                               )
                               nullRange) os1, cSig)
        EDRelation ed -> do
          pairs <- mapComDataPropsList cSig map2nd 1 2 
          return (map (\ (a, b) -> Quantification Universal
                              [ Var_decl [mkNName 1] thing nullRange
                              , Var_decl [mkNName 2] dataS nullRange]
                                (case ed of
                                   Equivalent ->
                                     Equivalence a b nullRange
                                   Disjoint ->
                                     Negation
                                       (Conjunction [a, b] nullRange)
                                       nullRange)
                               nullRange) pairs, cSig)
     
{-
    IndividualSameOrDifferent a ->
          IndividualSameOrDifferent $ mapAnnList m (`getIndIri` m) a
    DataPropRange a -> DataPropRange $ mapAnnList m (mapDRange m) a
    IndividualFacts a -> IndividualFacts $ mapAnnList m (mapFact m) a
    ExpressionBit a -> ExpressionBit  $ mapAnnList m (mapDescr m) a
    ObjectCharacteristics _ -> lfb
-}
	

{- | Mapping along ObjectPropsList for creation of pairs for commutative
operations. -}
mapComObjectPropsList :: CASLSign                    -- ^ CASLSignature
                      -> Maybe ObjectPropertyExpression
                      -> [ObjectPropertyExpression]
                      -> Int                         -- ^ First variable
                      -> Int                         -- ^ Last  variable
                      -> Result [(CASLFORMULA, CASLFORMULA)]
mapComObjectPropsList cSig mol props num1 num2 =
      mapM (\ (x, z) -> do
                              l <- mapObjProp cSig x num1 num2
                              r <- mapObjProp cSig z num1 num2
                              return (l, r)
                       ) $ case mol of
                             Nothing -> comPairs props props
                             Just ol -> comPairsaux ol props
                           

-- | mapping of data constants
mapLiteral :: CASLSign
            -> Literal
            -> Result (TERM ())
mapLiteral _ c =
    do
      let cl = case c of
                Literal l _ -> l
      return $ Application
               (
                Qual_op_name
                (stringToId cl)
                (Op_type Total [] dataS nullRange)
                nullRange
               )
               []
               nullRange

-- | Mapping of subobj properties
mapSubObjProp :: CASLSign
              -> ObjectPropertyExpression
              -> ObjectPropertyExpression
              -> Int
              -> Result CASLFORMULA
mapSubObjProp cSig oPL oP num1 = do
    let num2 = num1 + 1
    l <- mapObjProp cSig oPL num1 num2
    r <- mapObjProp cSig oP num1 num2
    return $ mkForall [mkVarDecl (mkNName num1) thing,
                       mkVarDecl (mkNName num2) thing]
                       (mkImpl r l )
                       nullRange
    
{- | Mapping along DataPropsList for creation of pairs for commutative
operations. -}
mapComDataPropsList :: CASLSign
                      -> [DataPropertyExpression]
                      -> Int                         -- ^ First variable
                      -> Int                         -- ^ Last  variable
                      -> Result [(CASLFORMULA, CASLFORMULA)]
mapComDataPropsList cSig props num1 num2 =
      mapM (\ (x, z) -> do
                              l <- mapDataProp cSig x num1 num2
                              r <- mapDataProp cSig z num1 num2
                              return (l, r)
                       ) $ comPairs props props

-- | Mapping of data properties
mapDataProp :: CASLSign
            -> DataPropertyExpression
            -> Int
            -> Int
            -> Result CASLFORMULA
mapDataProp _ dP nO nD =
    do
      let
          l = mkNName nO
          r = mkNName nD
      ur <- uriToIdM dP
      return $ Predication
                 (Qual_pred_name ur (toPRED_TYPE dataPropPred) nullRange)
                 [Qual_var l thing nullRange, Qual_var r dataS nullRange]
                 nullRange

-- | Mapping of obj props
mapObjProp :: CASLSign
              -> ObjectPropertyExpression
              -> Int
              -> Int
              -> Result CASLFORMULA
mapObjProp cSig ob num1 num2 =
    case ob of
      ObjectProp u ->
          do
            let l = mkNName num1
                r = mkNName num2
            ur <- uriToIdM u
            return $ Predication
              (Qual_pred_name ur (toPRED_TYPE objectPropPred) nullRange)
              [Qual_var l thing nullRange, Qual_var r thing nullRange]
              nullRange
      ObjectInverseOf u ->
          mapObjProp cSig u num2 num1

-- | Mapping of obj props with Individuals
mapObjPropI :: CASLSign
              -> ObjectPropertyExpression
              -> VarOrIndi
              -> VarOrIndi
              -> Result CASLFORMULA
mapObjPropI cSig ob lP rP =
      case ob of
        ObjectProp u ->
          do
            lT <- case lP of
                    OVar num1 -> return $ Qual_var (mkNName num1)
                                     thing nullRange
                    OIndi indivID -> mapIndivURI cSig indivID
            rT <- case rP of
                    OVar num1 -> return $ Qual_var (mkNName num1)
                                     thing nullRange
                    OIndi indivID -> mapIndivURI cSig indivID
            ur <- uriToIdM u
            return $ Predication
                       (Qual_pred_name ur
                        (toPRED_TYPE objectPropPred) nullRange)
                       [lT,
                        rT
                       ]
                       nullRange
        ObjectInverseOf u -> mapObjPropI cSig u rP lP

-- | Mapping of Class URIs
mapClassURI :: CASLSign
            -> Class
            -> Token
            -> Result CASLFORMULA
mapClassURI _ uril uid =
    do
      ur <- uriToIdM uril
      return $ Predication
                  (Qual_pred_name ur (toPRED_TYPE conceptPred) nullRange)
                  [Qual_var uid thing nullRange]
                  nullRange

-- | Mapping of Individual URIs
mapIndivURI :: CASLSign
            -> Individual
            -> Result (TERM ())
mapIndivURI _ uriI =
    do
      ur <- uriToIdM uriI
      return $ Application
                 (
                  Qual_op_name
                  ur
                  (Op_type Total [] thing nullRange)
                  nullRange
                 )
                 []
                 nullRange

uriToIdM :: IRI -> Result Id
uriToIdM = return . uriToId

-- | Extracts Id from URI
uriToId :: IRI -> Id
uriToId urI =
    let
        ur = case urI of
               QN _ "Thing" _ _ -> mkQName "Thing"
               QN _ "Nothing" _ _ -> mkQName "Nothing"
               _ -> urI
        repl a = if isAlphaNum a
                  then
                      a
                  else
                      '_'
        nP = map repl $ namePrefix ur
        lP = map repl $ localPart ur
        nU = map repl $ namespaceUri ur
    in stringToId $ nU ++ "" ++ nP ++ "" ++ lP

-- | Mapping of a list of descriptions
mapDescriptionList :: CASLSign
                      -> Int
                      -> [ClassExpression]
                      -> Result [CASLFORMULA]
mapDescriptionList cSig n lst =
      mapM (uncurry $ mapDescription cSig)
                                $ zip lst $ replicate (length lst) n

-- | Mapping of a list of pairs of descriptions
mapDescriptionListP :: CASLSign
                    -> Int
                    -> [(ClassExpression, ClassExpression)]
                    -> Result [(CASLFORMULA, CASLFORMULA)]
mapDescriptionListP cSig n lst =
    do
      let (l, r) = unzip lst
      llst <- mapDescriptionList cSig n l
      rlst <- mapDescriptionList cSig n r
      let olst = zip llst rlst
      return olst

-- | Build a name
mkNName :: Int -> Token
mkNName i = mkSimpleId $ hetsPrefix ++ mkNName_H i
    where
      mkNName_H k =
          case k of
            0 -> ""
            j -> mkNName_H (j `div` 26) ++ [chr (j `mod` 26 + 96)]

-- | Get all distinct pairs for commutative operations
comPairs :: [t] -> [t1] -> [(t, t1)]
comPairs [] [] = []
comPairs _ [] = []
comPairs [] _ = []
comPairs (a : as) (_ : bs) = comPairsaux a bs ++ comPairs as bs

comPairsaux :: t -> [t1] -> [(t, t1)]
comPairsaux a = map (\ b -> (a, b))

-- | mapping of Data Range
mapDataRange :: CASLSign 
	  -> DataRange 
	  -> Int
	  -> Result CASLFORMULA
mapDataRange cSig dr inId = 
    do 
	let uid = mkNName inId
	case dr of
	  DataType d _ ->
	    do
              ur <- uriToIdM d
	      return $ Membership
			(Qual_var uid thing nullRange)
			ur
			nullRange
	  DataComplementOf dr ->
	    do
	      dc <- mapDataRange cSig dr inId
	      return $ Negation dc nullRange
	  DataOneOf _ -> error "nyi"	
	  DataJunction _ _ -> error "nyi"

-- | mapping of OWL2 Descriptions 
mapDescription :: CASLSign 
	 	-> ClassExpression
		-> Int 
		-> Result CASLFORMULA
mapDescription cSig desc var = case desc of
    Expression u -> mapClassURI cSig u (mkNName var)
    ObjectJunction ty ds -> 
	do
	   des0 <- mapM(flip (mapDescription cSig) var) ds
	   return $ case ty of
		UnionOf -> Disjunction des0 nullRange
		IntersectionOf -> Conjunction des0 nullRange
    ObjectComplementOf d -> 
	do 
	   des0 <- mapDescription cSig d var
	   return $ Negation des0 nullRange
    ObjectOneOf is -> 
	do
	   ind0 <- mapM (mapIndivURI cSig) is
	   let var0 = Qual_var (mkNName var) thing nullRange
	   let forms = map (mkStEq var0) ind0
	   return $ Disjunction forms nullRange
    ObjectValuesFrom ty o d -> 
	do
	   oprop0 <- mapObjProp cSig o var (var + 1)
	   desc0 <- mapDescription cSig d (var + 1)
	   case ty of 
		SomeValuesFrom ->
		   return $ Quantification Existential [Var_decl [mkNName
								   (var + 1)]
							  thing nullRange]
			  (
			  Conjunction
                           [oprop0, desc0]
                           nullRange
			  )
			  nullRange
		AllValuesFrom ->
		   return $ Quantification Universal [Var_decl [mkNName
                                                               (var + 1)]
                                                       thing nullRange]
                       (
                        Implication
                        oprop0 desc0
                        True
                        nullRange
                       )
                       nullRange
    ObjectHasSelf o -> mapObjProp cSig o var var
    ObjectHasValue o i -> 
	mapObjPropI cSig o (OVar var) (OIndi i)
    ObjectCardinality c -> 
	case c of 
	   Cardinality ct n oprop d
		->
		   do
		     let vlst = [(var + 1) .. (n + var)]
                         vlstM = [(var + 1) .. (n + var + 1)]
		     dOut <- (\ x -> case x of
				     Nothing -> return []
				     Just y ->
					   mapM (mapDescription cSig y) vlst
			        ) d
		     let dlst = map (\ (x, y) ->
				     Negation 
				     (
					Strong_equation
					 (Qual_var (mkNName x) thing nullRange)
					 (Qual_var (mkNName y) thing nullRange)
					 nullRange
				     )
				     nullRange
				    ) $ comPairs vlst vlst
		     	 dlstM = map (\ (x, y) ->
				      Strong_equation
				      (Qual_var (mkNName x) thing nullRange)
				      (Qual_var (mkNName y) thing nullRange)
				      nullRange
				     ) $ comPairs vlstM vlstM
			 qVars = map (\ x ->
				      Var_decl [mkNName x]
						thing nullRange
				     ) vlst
			 qVarsM = map (\x ->
				       Var_decl [mkNName x]
						 thing nullRange
				      ) vlstM
		     oProps <- mapM (mapObjProp cSig oprop var) vlst
		     oPropsM <- mapM (mapObjProp cSig oprop var) vlstM
		     let minLst = Quantification Existential
				  qVars
				  (
				   Conjunction 
				   (dlst ++ dOut ++ oProps)
				   nullRange
				  )
				  nullRange
		     let maxLst = Quantification Universal
				  qVarsM
			   	  (
				   Implication
				   (Conjunction (oPropsM ++ dOut) nullRange)
				   (Disjunction dlstM nullRange)
				   True
				   nullRange
				  )
				  nullRange
		     case ct of
			MinCardinality -> return minLst
			MaxCardinality -> return maxLst
			ExactCardinality -> return $
                                            Conjunction
                                            [minLst, maxLst]
                                            nullRange
    DataValuesFrom _ _ _ _ -> fail "data handling nyi"
    DataHasValue _ _ -> fail "data handling nyi"
    DataCardinality _ -> fail "data handling nyi"