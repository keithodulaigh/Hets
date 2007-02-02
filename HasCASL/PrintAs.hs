{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2003
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  experimental
Portability :  portable

printing data types of the abstract syntax
-}

module HasCASL.PrintAs where

import HasCASL.As
import HasCASL.AsUtils
import HasCASL.FoldTerm
import HasCASL.Builtin
import Common.Id
import Common.Keywords
import Common.DocUtils
import Common.Doc
import Common.AS_Annotation

-- | short cut for: if b then empty else d
noPrint :: Bool -> Doc -> Doc
noPrint b d = if b then empty else d

noNullPrint :: [a] -> Doc -> Doc
noNullPrint = noPrint . null

semiDs :: Pretty a => [a] -> Doc
semiDs = fsep . punctuate semi . map pretty

semiAnnoted :: Pretty a => [Annoted a] -> Doc
semiAnnoted = vcat . map (printSemiAnno pretty True) 

instance Pretty Variance where
    pretty = sidDoc . mkSimpleId . show

instance Pretty a => Pretty (AnyKind a) where
    pretty knd = case knd of
        ClassKind ci -> pretty ci
        FunKind v k1 k2 _ -> fsep [pretty v <>
                          (case k1 of
                                  FunKind _ _ _ _ -> parens
                                  _ -> id) (pretty k1)
                          , funArrow
                          , pretty k2]

instance Pretty TypePattern where
    pretty tp = case tp of
        TypePattern name args _ -> pretty name
                                 <> fsep (map (parens . pretty) args)
        TypePatternToken t -> pretty t
        MixfixTypePattern ts -> fsep (map (pretty) ts)
        BracketTypePattern k l _ -> bracket k $ ppWithCommas l
        TypePatternArg t _ -> parens $ pretty t

-- | put proper brackets around a document
bracket :: BracketKind -> Doc -> Doc
bracket b = case b of
              Parens -> parens
              Squares -> brackets
              Braces -> specBraces
              NoBrackets -> id

-- | print a 'Kind' plus a preceding colon (or nothing)
printKind :: Kind -> Doc
printKind k = noPrint (k == universe) $ printVarKind InVar (VarKind k)

-- | print the kind of a variable with its variance and a preceding colon
printVarKind :: Variance -> VarKind -> Doc
printVarKind e vk = case vk of
                    Downset t ->
                        space <> less <+> pretty t
                    VarKind k -> space <> colon <+>
                                 pretty e <> pretty k
                    MissingKind -> empty

data TypePrec = Outfix | Prefix | ProdInfix | FunInfix deriving (Eq, Ord)

parenPrec :: TypePrec -> (TypePrec, Doc) -> Doc
parenPrec p1 (p2, d) = if p2 < p1 then d else parens d

printTypeToken :: Token -> Doc
printTypeToken t = let 
  l = ("*", cross) : map ( \ (a, d) -> (show a, d) ) 
    [ (FunArr, funArrow)
    , (PFunArr, pfun)
    , (ContFunArr, cfun)
    , (PContFunArr, pcfun) ]
  in case lookup (tokStr t) l of 
       Just d -> d
       _ -> pretty t

toMixType :: Type -> (TypePrec, Doc)
toMixType typ = case typ of
    ExpandedType t1 _ -> toMixType t1
    {- (Prefix, ExpandedType
                      (parenPrec Prefix $ toMixType t1)
                         $ parenPrec Prefix $ toMixType t2) -}
    BracketType k l _ -> (Outfix, bracket k $ sepByCommas $ map
                             (snd . toMixType) l)
    KindedType t kind _ -> (Prefix,
               fsep [parenPrec Prefix $ toMixType t, colon, pretty kind])
    MixfixType ts -> (Prefix, fsep $ map (snd . toMixType) ts)
    _ -> let (topTy, tyArgs) = getTypeAppl typ in
      case topTy of
      TypeName name@(Id ts cs _) _k _i -> let topDoc = pretty name in
        case tyArgs of
          [] -> (Outfix, pretty name)
          [arg] -> let dArg = toMixType arg in
               case ts of
               [e1, e2, e3] | not (isPlace e1) && isPlace e2
                              && not (isPlace e3) && null cs ->
                   (Outfix, fsep [pretty e1, snd dArg, pretty e3])
               _ -> (Prefix, fsep [topDoc, parenPrec Prefix dArg])
          [arg1, arg2] -> let dArg1 = toMixType arg1
                              dArg2 = toMixType arg2 in
               case ts of
               [e1, e2, e3] | isPlace e1 && not (isPlace e2)
                              && isPlace e3 && null cs ->
                    if tokStr e2 == prodS then
                      (ProdInfix, fsep [
                       parenPrec ProdInfix dArg1, cross,
                       parenPrec ProdInfix dArg2])
                    else -- assume fun type
                      (FunInfix, fsep [
                       parenPrec FunInfix dArg1, printTypeToken e2, snd dArg2])
               _ -> (Prefix, fsep [topDoc, parenPrec Prefix dArg1,
                               parenPrec Prefix dArg2])
          _ -> if name == productId (length tyArgs) then
                (ProdInfix, fsep $ punctuate (space <> cross) $
                          map (parenPrec ProdInfix . toMixType) tyArgs)
                else (Prefix, fsep $ topDoc :
                            map (parenPrec Prefix . toMixType) tyArgs)
      _ | null tyArgs -> (Outfix, printType topTy)
      _ -> (Prefix, fsep $ parenPrec ProdInfix (toMixType topTy)
         : map (parenPrec Prefix . toMixType) tyArgs)

printType :: Type -> Doc
printType ty = case ty of
        TypeName name _ _ -> pretty name
        TypeAppl t1 t2 -> fcat [parens (printType t1),
                                parens (printType t2)]
        ExpandedType t1 t2 -> fcat [printType t1, text asP, printType t2]
        TypeToken t -> printTypeToken t
        BracketType k l _ -> bracket k $ sepByCommas $ map (printType) l
        KindedType t kind _ -> sep [printType t, colon <+> pretty kind]
        MixfixType ts -> fsep $ map printType ts

instance Pretty Type where
    pretty = snd . toMixType

-- no curried notation for bound variables
instance Pretty TypeScheme where
    pretty (TypeScheme vs t _) = let tdoc = pretty t in
        if null vs then tdoc else
           fsep [forallDoc, semiDs vs, bullet, tdoc]

instance Pretty Partiality where
    pretty p = case p of
        Partial -> quMarkD
        Total -> empty

instance Pretty Quantifier where
    pretty q = case q of
        Universal -> forallDoc
        Existential -> exists
        Unique -> unique

instance Pretty TypeQual where
    pretty q = case q of
        OfType -> colon
        AsType -> text asS
        InType -> inDoc
        Inferred -> colon

instance Pretty Term where
    pretty = changeGlobalAnnos addBuiltins . printTerm . rmSomeTypes

isSimpleTerm :: Term -> Bool
isSimpleTerm trm = case trm of
    QualVar _ -> True
    QualOp _ _ _ _ -> True
    ResolvedMixTerm _ _ _ -> True
    ApplTerm _ _ _ -> True
    TupleTerm _ _ -> True
    TermToken _ -> True
    BracketTerm _ _ _ -> True
    _ -> False

isPatVarDecl :: VarDecl -> Bool
isPatVarDecl (VarDecl v ty _ _) = case ty of 
           TypeName t _ _ -> isSimpleId v && take 2 (show t) == "_v" 
           _ -> False

parenTermDoc :: Term -> Doc -> Doc
parenTermDoc trm = if isSimpleTerm trm then id else parens

printTermRec :: FoldRec Doc (Doc, Doc)
printTermRec = FoldRec
    { foldQualVar = \ _ vd@(VarDecl v _ _ _) -> 
         if isPatVarDecl vd then pretty v 
         else parens $ keyword varS <+> pretty vd
    , foldQualOp = \ _ br n t _ ->
          parens $ fsep [pretty br, pretty n, colon, pretty $
                         if isPred br then unPredTypeScheme t else t]
    , foldResolvedMixTerm = \ (ResolvedMixTerm _ os _) n ts _ ->
          if placeCount n == length ts || null ts then
          idApplDoc n $ zipWith parenTermDoc os ts
          else idApplDoc applId [idDoc n, parens $ sepByCommas ts]
    , foldApplTerm = \ (ApplTerm o1 o2 _) t1 t2 _ ->
        case (o1, o2) of
          (ResolvedMixTerm n [] _, TupleTerm ts _)
              | placeCount n == length ts ->
                  idApplDoc n $ zipWith parenTermDoc ts $ map printTerm ts
          (ResolvedMixTerm n [] _, _) | placeCount n == 1 ->
              idApplDoc n [parenTermDoc o2 t2]
          _ -> idApplDoc applId [parenTermDoc o1 t1, parenTermDoc o2 t2]
     , foldTupleTerm = \ _ ts _ -> parens $ sepByCommas ts
     , foldTypedTerm = \ (TypedTerm ot _ _ _) t q typ _ -> fsep [(case ot of 
           LambdaTerm {} -> parens
           LetTerm {} -> parens
           CaseTerm {} -> parens
           QuantifiedTerm {} -> parens
           _ -> id) t, pretty q, pretty typ]
     , foldQuantifiedTerm = \ _ q vs t _ ->
           fsep [pretty q, semiDs vs, bullet, t]
     , foldLambdaTerm = \ _ ps q t _ ->
            fsep [ lambda
                 , case ps of
                      [p] -> p
                      _ -> fcat $ map parens ps
                 , case q of
                     Partial -> bullet
                     Total -> bullet <> text exMark
                 , t]
     , foldCaseTerm = \ _ t es _  ->
            fsep [text caseS, t, text ofS,
                  cat $ punctuate (space <> bar <> space) $
                       map (printEq0 funArrow) es]
     , foldLetTerm = \ _ br es t _ ->
            let des = sep $ punctuate semi $ map (printEq0 equals) es
                in case br of
                Let -> fsep [sep [text letS <+> des, text inS], t]
                Where -> fsep [sep [t, text whereS], des]
                Program -> text programS <+> des
     , foldTermToken = \ _ t -> pretty t
     , foldMixTypeTerm = \ _ q t _ -> pretty q <+> pretty t
     , foldMixfixTerm = \ _ ts -> fsep ts
     , foldBracketTerm = \ _ k l _ -> bracket k $ sepByCommas l
     , foldAsPattern = \ _ (VarDecl v _ _ _) p _ -> 
                       fsep [pretty v, text asP, p]
     , foldProgEq = \ _ p t _ -> (p, t)
    }

printTerm :: Term -> Doc
printTerm = foldTerm printTermRec

rmTypeRec :: MapRec
rmTypeRec = mapRec
    { -- foldQualVar = \ _ (VarDecl v _ _ ps) -> ResolvedMixTerm v [] ps
      foldQualOp = \ t _ (InstOpId i _ _) _ ps ->
                   if elem i $ map fst bList then
                     ResolvedMixTerm i [] ps else t
    , foldTypedTerm = \ _ nt q ty ps ->
           case q of
           Inferred -> nt
           _ -> case nt of
               TypedTerm _ oq oty _ | oty == ty || oq == InType -> nt
               QualVar (VarDecl _ oty _ _) | oty == ty -> nt
               _ -> TypedTerm nt q ty ps
    }

rmSomeTypes :: Term -> Term
rmSomeTypes = foldTerm rmTypeRec

-- | print an equation with different symbols between 'Pattern' and 'Term'
printEq0 :: Doc -> (Doc, Doc) -> Doc
printEq0 s (p, t) = fsep [p, s, t]

instance Pretty VarDecl where
    pretty (VarDecl v t _ _) = pretty v <>
       case t of
       MixfixType [] -> empty
       _ -> space <> colon <+> pretty t

instance Pretty GenVarDecl where
    pretty gvd = case gvd of
        GenVarDecl v -> pretty v
        GenTypeVarDecl tv -> pretty tv

instance Pretty TypeArg where
    pretty (TypeArg v e c _ _ _ _) =
        pretty v <> printVarKind e c

-- | don't print an empty list and put parens around longer lists
printList0 :: (Pretty a) => [a] -> Doc
printList0 l = case l of
    []  -> empty
    [x] -> pretty x
    _   -> parens $ ppWithCommas l

instance Pretty InstOpId where
    pretty (InstOpId n l _) = pretty n <> noNullPrint l
                                     (brackets $ semiDs l)

-- | print a 'TypeScheme' as a pseudo type
printPseudoType :: TypeScheme -> Doc
printPseudoType (TypeScheme l t _) = noNullPrint l (lambda
    <+> (if null $ tail l then pretty $ head l
         else fsep(map (parens . pretty) l))
            <+> bullet <> space) <> pretty t

instance Pretty BasicSpec where
    pretty (BasicSpec l) = vcat $ map pretty l

instance Pretty ProgEq where
    pretty = printEq0 equals . foldEq printTermRec

instance Pretty BasicItem where
    pretty bi = case bi of
        SigItems s -> pretty s
        ProgItems l _ -> sep [keyword programS, semiAnnoted l]
        ClassItems i l _ -> let b = semiAnnoted l in case i of 
            Plain -> topSigKey classS <+>b
            Instance -> sep [keyword classS <+> keyword instanceS, b]
        GenVarItems l _ -> topSigKey varS <+> semiDs l
        FreeDatatype l _ -> 
            sep [keyword freeS <+> keyword typeS, semiAnnoted l]
        GenItems l _ -> sep [ keyword generatedS
                            , specBraces . vcat $ map (printAnnoted pretty) l]
        AxiomItems vs fs _ ->
            vcat $ (if null vs then [] else
                    [forallDoc <+> semiDs vs])
                  ++ case fs of 
                       [] -> []
                       _ -> map (printAnnoted $ addBullet . pretty) (init fs)
                         ++ [printSemiAnno (addBullet . pretty) True $ last fs]
        Internal l _ -> sep [keyword internalS, specBraces $ semiAnnoted l]

instance Pretty OpBrand where
    pretty b = keyword $ show b

instance Pretty SigItems where
    pretty si = case si of
        TypeItems i l _ -> let b = semiAnnos pretty l in case i of
            Plain -> topSigKey (if all (isSimpleTypeItem . item) l 
                                then sortS else typeS) <+> b
            Instance -> sep [keyword typeS <+> keyword instanceS, b]
        OpItems b l _ -> noNullPrint l $ topSigKey (show b) 
            <+> let po = (prettyOpItem $ isPred b) in 
                if case item $ last l of 
                  OpDecl _ _ a@(_ : _) _ -> case last a of 
                    UnitOpAttr {} -> True
                    _ -> False
                  OpDefn {} -> True
                  _ -> False 
                then vcat (map (printSemiAnno po True) l)
                else semiAnnos po l

isSimpleTypeItem :: TypeItem -> Bool
isSimpleTypeItem ti = case ti of
    TypeDecl l k _ -> k == universe && all isSimpleTypePat l
    SubtypeDecl l (TypeName i _ _) _ -> isSimpleId i && all isSimpleTypePat l
    SubtypeDefn p (Var _) (TypeName i _ _) _ _ -> 
        isSimpleTypePat p && isSimpleId i
    _ -> False

isSimpleTypePat :: TypePattern -> Bool
isSimpleTypePat tp = case tp of
    TypePattern i [] _ -> isSimpleId i
    _ -> False

instance Pretty ClassItem where
    pretty (ClassItem d l _) = 
        pretty d $+$ noNullPrint l (specBraces $ semiAnnoted l)

instance Pretty ClassDecl where
    pretty (ClassDecl l k _) = fsep [ppWithCommas l, less, pretty k]

instance Pretty Vars where
    pretty vd = case vd of
        Var v -> pretty v
        VarTuple vs _ -> parens $ ppWithCommas vs

instance Pretty TypeItem where
    pretty ti = case ti of
        TypeDecl l k _ -> ppWithCommas l <> printKind k
        SubtypeDecl l t _ -> 
            fsep [ppWithCommas l, less, pretty t]
        IsoDecl l _ -> fsep $ punctuate (space <> equals) $ map pretty l
        SubtypeDefn p v t f _ ->
            fsep [pretty p, equals,
                  specBraces $ fsep
                  [pretty v, colon, pretty t, bullet, pretty f]]
        AliasType p k t _ ->
            fsep $ pretty p : (case k of
                     Just j | j /= universe -> [colon <+> pretty j]
                     _ -> [])
                  ++ [text assignS <+> printPseudoType t]
        Datatype t -> pretty t

prettyTypeScheme :: Bool -> TypeScheme -> Doc
prettyTypeScheme b = pretty . (if b then unPredTypeScheme else id)

prettyOpItem :: Bool -> OpItem -> Doc 
prettyOpItem b oi = case oi of
        OpDecl l t a _ -> fsep $ punctuate comma (map pretty l)
          ++ [colon <+> 
              (if null a then id else (<> comma))(prettyTypeScheme b t)]
          ++ punctuate comma (map pretty a)
        OpDefn n ps s p t _ ->
            fcat $ ((if null ps then (<> space) else id) $ pretty n)
                     : map ((<> space) . parens . semiDs) ps
                     ++ (if b then [] else 
                         [colon <> pretty p <+> prettyTypeScheme b s <> space])
                     ++ [(if b then equiv else equals) <> space, pretty t]

instance Pretty BinOpAttr where
    pretty a = text $ case a of
        Assoc -> assocS
        Comm -> commS
        Idem -> idemS

instance Pretty OpAttr where
    pretty oa = case oa of
        BinOpAttr a _ -> pretty a
        UnitOpAttr t _ -> text unitS <+> pretty t

instance Pretty DatatypeDecl where
    pretty (DatatypeDecl p k alts d _) = 
        fsep [ pretty p <> printKind k, defn
              <+> cat (punctuate (space <> bar <> space) 
                      $ map pretty alts)
             , case d of 
                 [] -> empty
                 _ -> keyword derivingS <+> ppWithCommas d]

instance Pretty Alternative where
    pretty alt = case alt of
        Constructor n cs p _ ->
            pretty n <+> fsep (map ( \ l -> case (l, p) of 
                              ([NoSelector (TypeToken t)], Total) 
                                  -> pretty t
                              _ -> parens $ semiDs l) cs)
                       <> pretty p
        Subtype l _ -> noNullPrint l $ text typeS <+> ppWithCommas l

instance Pretty Component where
    pretty sel = case sel of
        Selector n p t _ _ -> pretty n
                              <+> colon <> pretty p
                                      <+> pretty t
        NoSelector t -> pretty t

instance Pretty OpId where
    pretty (OpId n ts _) = pretty n
                                  <+> noNullPrint ts
                                      (brackets $ ppWithCommas ts)

instance Pretty Symb where
    pretty (Symb i mt _) =
        pretty i <> (case mt of
                       Nothing -> empty
                       Just (SymbType t) ->
                           space <> colon <+> pretty t)

instance Pretty SymbItems where
    pretty (SymbItems k syms _ _) =
        printSK k <> ppWithCommas syms

instance Pretty SymbOrMap where
    pretty (SymbOrMap s mt _) =
        pretty s <> (case mt of
                       Nothing -> empty
                       Just t ->
                           space <> mapsto <+> pretty t)

instance Pretty SymbMapItems where
    pretty (SymbMapItems k syms _ _) =
        printSK k <> ppWithCommas syms

-- | print symbol kind
printSK :: SymbKind -> Doc
printSK k =
    case k of Implicit -> empty
              _ -> text (drop 3 $ show k) <> space
