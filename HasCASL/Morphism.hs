{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2002-2003
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  hets@tzi.de
Stability   :  provisional
Portability :  non-portable (deriving Typeable)
    
Morphism on 'Env' (as for CASL)
-}

module HasCASL.Morphism where

import HasCASL.Le
import HasCASL.HToken
import HasCASL.As
import HasCASL.PrintAs
import HasCASL.Unify
import HasCASL.Merge
import HasCASL.Symbol
import Common.Id
import Common.Keywords
import Common.Result
import Common.PrettyPrint
import Common.Lib.Pretty
import Common.Lib.State
import qualified Common.Lib.Map as Map
import qualified Common.Lib.Set as Set
import Data.Dynamic

data SymbolType = OpAsItemType TypeScheme 
		| TypeAsItemType Kind
		| ClassAsItemType Kind
		  deriving (Show, Eq, Ord)

instance PrettyPrint SymbolType where
    printText0 ga t = case t of 
      OpAsItemType sc -> printText0 ga sc
      TypeAsItemType k -> printText0 ga k
      ClassAsItemType k -> printText0 ga k

instance Ord TypeScheme where
    sc1 <= sc2 = let (t1, c) = runState (freshInst sc1) 1
		     t2 = evalState (freshInst sc2) c
		     v1 = varsOf t1
		     v2 = varsOf t2
                 in case compare (length v1) $ length v2 of 
			LT -> True
			EQ -> t1 <= subst (Map.fromList $
			    zipWith (\ v (TypeArg i k _ _) ->
				     (v, TypeName i k 1)) v1 v2) t2
			GT -> False 		   

data Symbol = Symbol {symName :: Id, symbType :: SymbolType} 
	      deriving (Show, Eq, Ord, Typeable)

data RawSymbol = ASymbol Symbol | AnID Id | AKindedId SymbKind Id
    	         deriving (Show, Eq, Ord, Typeable)

type SymbolMap = Map.Map Symbol Symbol 

idToTypeSymbol :: Id -> Kind -> Symbol
idToTypeSymbol idt k = Symbol idt $ TypeAsItemType k

idToOpSymbol :: Id -> TypeScheme -> Symbol
idToOpSymbol idt typ = Symbol idt $ OpAsItemType typ

idToRaw :: Id -> RawSymbol
idToRaw x = AnID x

symbTypeToKind :: SymbolType -> SymbKind
symbTypeToKind (OpAsItemType _)    = SK_op
symbTypeToKind (TypeAsItemType _)  = SK_type
symbTypeToKind (ClassAsItemType _) = SK_class

symbolToRaw :: Symbol -> RawSymbol
symbolToRaw sym = ASymbol sym
-- symbolToRaw (Symbol idt typ) = AKindedId (symbTypeToKind typ) idt

symOf :: Env -> Set.Set Symbol
symOf sigma = 
    let classes = Map.foldWithKey ( \ i ks s -> 
			Set.insert (Symbol i $ ClassAsItemType $
				    Intersection (classKinds ks) []) s) 
		  Set.empty $ classMap sigma
	types = Map.foldWithKey ( \ i ti s -> 
			Set.insert (Symbol i $ TypeAsItemType $
				    typeKind ti) s) 
		classes $ typeMap sigma
        ops = Map.foldWithKey ( \ i ts s0 ->
		      foldr ( \ t s1 -> 
			  Set.insert (Symbol i $ OpAsItemType $ 
				      opType t) s1) s0 $ opInfos ts)
	      types $ assumps sigma
	in ops

statSymbMapItems :: [SymbMapItems] -> Result (Map.Map RawSymbol RawSymbol)
statSymbMapItems sl =  return (Map.fromList $ concat $ map s1 sl)
  where
  s1 (SymbMapItems kind l _ _) = map (symbOrMapToRaw kind) l
 
symbOrMapToRaw :: SymbKind -> SymbOrMap -> (RawSymbol,RawSymbol)
symbOrMapToRaw k (SymbOrMap s mt _) = 
    (symbToRaw k s,
     symbToRaw k $ case mt of Nothing -> s
                              Just t -> t)

statSymbItems :: [SymbItems] -> Result [RawSymbol]
statSymbItems sl = 
  return (concat (map s1 sl))
  where s1 (SymbItems kind l _ _) = map (symbToRaw kind) l

symbToRaw :: SymbKind -> Symb -> RawSymbol
symbToRaw k (Symb idt _ _)     = symbKindToRaw k idt

symbKindToRaw :: SymbKind -> Id -> RawSymbol
symbKindToRaw Implicit     idt = AnID idt
symbKindToRaw sk idt = AKindedId sk idt

matchSymb :: Symbol -> RawSymbol -> Bool
matchSymb x                            (ASymbol y)              =  x==y
matchSymb (Symbol idt _)                (AnID di)               = idt==di
matchSymb (Symbol idt _)        (AKindedId _ di)                = idt==di

rawSymName :: RawSymbol -> Id
rawSymName (ASymbol sym) = symName sym
rawSymName (AnID i) = i
rawSymName (AKindedId _ i) = i

type IdMap = Map.Map Id Id

mapType :: IdMap -> Type -> Type
-- include classIdMap later
mapType m t = case t of
	   TypeName i k n ->
	       if n == 0 then 
		  case Map.lookup i m of
		  Just j -> TypeName j k 0
		  _ -> t
	       else t
	   TypeAppl t1 t2 ->
	       TypeAppl (mapType m t1) (mapType m t2)
	   TypeToken _ -> t
	   BracketType b l ps ->
	       BracketType b (map (mapType m) l) ps
	   KindedType tk k ps -> 
	       KindedType (mapType m tk) k ps
	   MixfixType l -> MixfixType $ map (mapType m) l
	   LazyType tl ps -> LazyType (mapType m tl) ps
	   ProductType l ps -> ProductType (map (mapType m) l) ps
           FunType t1 a t2 ps -> FunType (mapType m t1) a (mapType m t2) ps

mapTypeScheme :: IdMap -> TypeScheme -> TypeScheme
-- rename clashing type arguments later
mapTypeScheme m (TypeScheme args (q :=> t) ps) =
    TypeScheme args (q :=> mapType m t) ps

type FunMap = Map.Map (Id, TypeScheme) (Id, TypeScheme)

mapFunSym :: IdMap -> FunMap -> (Id, TypeScheme) -> Maybe (Id, TypeScheme)
mapFunSym tm fm (i, sc) = do
  (newI, _sc1) <- Map.lookup (i, sc) fm
  let sc2 = mapTypeScheme tm sc
      -- unify sc2 with sc1 later
  return (newI, sc2)

data Morphism = Morphism { msource :: Env
			 , mtarget :: Env
			 , classIdMap :: IdMap  -- ignore
			 , typeIdMap :: IdMap 
                         , funMap :: FunMap } 
                         deriving (Eq, Show, Typeable)

mkMorphism :: Env -> Env -> Morphism
mkMorphism e1 e2 = Morphism e1 e2 Map.empty Map.empty Map.empty

ideMor :: Env -> Morphism
ideMor e = mkMorphism e e  -- plus identity functions
compMor :: Morphism -> Morphism -> Morphism
compMor m1 m2 = mkMorphism (msource m1) (mtarget m2) -- plus composed functions

inclusionMor :: Env -> Env -> Result Morphism
inclusionMor e1 e2 = return (mkMorphism e1 e2)

embedMorphism :: Env -> Env -> Morphism
embedMorphism a b =
    (mkMorphism a b) 
    { typeIdMap = foldr (\x -> Map.insert x x) Map.empty 
                $ Map.keys $ typeMap a
    , funMap = Map.foldWithKey 
                 ( \ i (OpInfos ts) m -> foldr 
                      (\ oi -> let t = opType oi in 
		           Map.insert (i,t) (i, t)) m ts)
                 Map.empty $ assumps a
    }

symbMapToMorphism :: Env -> Env -> SymbolMap -> Result Morphism
symbMapToMorphism sigma1 sigma2 smap = do
  type_map1 <- Map.foldWithKey myIdMap (return Map.empty) $ typeMap sigma1
  fun_map1 <- Map.foldWithKey myAsMap (return Map.empty) $ assumps sigma1
  return (mkMorphism sigma1 sigma2)
	 { typeIdMap = type_map1
	 , funMap = fun_map1}
  where
  myIdMap i k m = do
    m1 <- m 
    sym <- maybeToResult nullPos 
             ("symbMapToMorphism - Could not map sort "++showId i "")
             $ Map.lookup (Symbol { symName = i
				  , symbType = TypeAsItemType 
				               $ typeKind k}) smap
    return (Map.insert i (symName sym) m1)
  myAsMap i (OpInfos ots) m = foldr (insFun i) m ots
  insFun i ot m = do
    m1 <- m
    sym <- maybeToResult nullPos 
             ("symbMapToMorphism - Could not map op "++showId i "")
             $ Map.lookup (Symbol { symName = i
				  , symbType = OpAsItemType $ opType ot}) smap
    k <- case symbType sym of
        OpAsItemType sc -> return sc
        _ -> plain_error (opType ot)
              ("symbMapToMorphism - Wrong result symbol type for op"
               ++showId i "") nullPos 
    return (Map.insert (i, opType ot) (symName sym,k) m1)

legalEnv :: Env -> Bool
legalEnv _ = True -- maybe a closure test?
legalMor :: Morphism -> Bool
legalMor m = legalEnv (msource m) && legalEnv (mtarget m)  -- and what else?

morphismUnion :: Morphism -> Morphism -> Result Morphism
morphismUnion m1 m2 = do s <- merge (msource m1) $ msource m2
			 t <- merge (mtarget m1) $ mtarget m2
			 return $ mkMorphism s t

morphismToSymbMap :: Morphism -> Map.Map Symbol Symbol
morphismToSymbMap _ = Map.empty

-- | Check if two OpTypes are equal except from totality or partiality
compatibleOpTypes :: TypeScheme -> TypeScheme -> Bool
compatibleOpTypes = isUnifiable Map.empty 0 

-- Some quick and dirty instances

instance PrettyPrint Morphism where
  printText0 _ga s = text (show s)

instance PrettyPrint Symbol where
  printText0 ga s = text (case symbType s of 
			  OpAsItemType _ -> opS
			  TypeAsItemType _ -> typeS
			  ClassAsItemType _ -> classS) <+> 
                    printText0 ga (symName s) <+> text colonS <+> 
		    printText0 ga (symbType s)

instance PrettyPrint RawSymbol where
  printText0 _ga s = text (show s)
