{- |
Module      :  $Header$
Description :  Signatures for Maude
Copyright   :  (c) Martin Kuehl, Uni Bremen 2008-2009
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  mkhl@informatik.uni-bremen.de
Stability   :  experimental
Portability :  portable

Definition of signatures for Maude.
-}

module Maude.Sign (
    Sign(..),
    SortSet,
    SubsortRel,
    OpDecl,
    OpDeclSet,
    OpMap,
    Sentences,
    fromSpec,
    symbols,
    empty,
    union,
    intersection,
    isLegal,
    isSubsign,
    includesSentence,
    simplifySentence,
) where

import Maude.AS_Maude
import Maude.Symbol
import Maude.Meta
import Maude.Printing ()

import Maude.Sentence (Sentence)
import qualified Maude.Sentence as Sen

import Data.Set (Set)
import Data.Map (Map)
import qualified Data.Set as Set
import qualified Data.Map as Map
import qualified Data.Foldable as Fold
import qualified Common.Lib.Rel as Rel

import Common.Doc hiding (empty)
import Common.DocUtils (Pretty(..))


type SortSet = SymbolSet
type SubsortRel = SymbolRel
type OpDecl = (Symbol, [Attr])
type OpDeclSet = Set OpDecl
type OpMap = Map Qid OpDeclSet
type Sentences = Set Sentence

-- TODO: Should we also add the Module name to Sign?
data Sign = Sign {
        sorts :: SortSet,
        subsorts :: SubsortRel,
        ops :: OpMap,
        sentences :: Sentences
    } deriving (Show, Ord, Eq)


instance Pretty Sign where
    pretty sign = let
            pretty'sorts ss = hsep
                [keyword "sorts", hsep $ map pretty ss, dot]
            pretty'sups = hsep . map pretty . Set.elems
            pretty'pair sub sups = (:) . hsep $
                [keyword "subsort", pretty sub, less, pretty'sups sups]
            pretty'subs = vsep . Map.foldWithKey pretty'pair []
            pretty'decl (sym, attrs) = hsep
                [keyword "op", pretty sym, pretty attrs, dot]
            pretty'ods = flip $ Set.fold ((:) . pretty'decl)
            pretty'ops = vsep . Map.fold pretty'ods []
        in vsep [
            pretty'sorts $ Set.elems $ sorts sign,
            pretty'subs $ Rel.toMap $ subsorts sign,
            pretty'ops $ ops sign,
            pretty $ sentences sign
        ]


instance HasSorts Sign where
    getSorts = sorts
    mapSorts mp sign = sign {
        sorts = mapSorts mp $ sorts sign,
        subsorts = mapSorts mp $ subsorts sign
    }

instance HasOps Sign where
    getOps = let insert = flip $ Set.fold $ Set.insert . fst
        in Map.fold insert Set.empty . ops
    mapOps mp sign = let
            update (symb, attrs) = insertOpDecl (mapOps mp symb) attrs
            insert = flip $ Set.fold update
        in sign {
            ops = Map.fold insert Map.empty $ ops sign
        }

instance HasLabels Sign where
    getLabels = getLabels . sentences
    mapLabels mp sign = sign {
        sentences = mapLabels mp $ sentences sign
    }


-- | extract the Signature of a Module
fromSpec :: Module -> Sign
fromSpec spec@(Module _ _ stmts) = let
        sens = filter (not . Sen.isRule) . Sen.fromSpec $ spec
        sign = foldr insert empty stmts
        insert stmt = case stmt of
            SortStmnt sort -> insertSort sort
            SubsortStmnt sub -> insertSubsort sub
            OpStmnt op -> insertOp op
            _ -> id
    in sign { sentences = Set.fromList sens }

-- | extract the Set of all Symbols from a Signature
symbols :: Sign -> SymbolSet
symbols sign = Set.unions [
        getSorts sign,
        getOps sign,
        getLabels sign
    ]

-- | the empty Signature
empty :: Sign
empty = Sign {
    sorts = Set.empty,
    subsorts = Rel.empty,
    ops = Map.empty,
    sentences = Set.empty
}

-- | the union of two Signatures
union :: Sign -> Sign -> Sign
union sig1 sig2 = let
        apply func items = func (items sig1) (items sig2)
    in Sign {
        sorts = apply Set.union sorts,
        subsorts = apply Rel.union subsorts,
        ops = apply Map.union ops,
        sentences = apply Set.union sentences
    }

-- | the intersection of two Signatures
intersection :: Sign -> Sign -> Sign
intersection sig1 sig2 = let
        apply func items = func (items sig1) (items sig2)
    in Sign {
        sorts = apply Set.intersection sorts,
        subsorts = apply Rel.intersection subsorts,
        ops = apply Map.intersection ops,
        sentences = apply Set.intersection sentences
    }


-- | insert a Sort into a Signature
insertSort :: Sort -> Sign -> Sign
insertSort sort sign = sign {sorts = insert sort (sorts sign)}
    where insert = Set.insert . asSymbol

-- | insert a Subsort declaration into a Signature
insertSubsort :: SubsortDecl -> Sign -> Sign
insertSubsort decl sign = sign {subsorts = insert decl (subsorts sign)}
    where insert (Subsort sub super) = Rel.insert (asSymbol sub) (asSymbol super)

-- | insert an Operator declaration into an OperatorMap
insertOpDecl :: Symbol -> [Attr] -> OpMap -> OpMap
insertOpDecl symb attrs opmap = let
        name = getName symb
        decl = (symb, attrs)
        old'ops = Map.findWithDefault Set.empty name opmap
        new'ops = Set.insert decl old'ops
    in Map.insert name new'ops opmap

-- | insert an Operator declaration into a Signature
insertOp :: Operator -> Sign -> Sign
insertOp op sign = let
        insert (Op _ _ _ as) = insertOpDecl (asSymbol op) as
    in sign {ops = insert op (ops sign)}


-- TODO: Add more checks, e.g. whether all Symbols in SortSet are Sorts?
-- | check that a Signature is legal
isLegal :: Sign -> Bool
isLegal sign = let
        -- TODO: isLegalSort won't work for Kinds vs. Sorts
        isLegalSort sort = Set.member sort (sorts sign)
        isLegalOp pair = case fst pair of
            Operator _ dom cod -> all isLegalSort dom && isLegalSort cod
            _ -> False
        legal'subsorts = Fold.all isLegalSort $ Rel.nodes (subsorts sign)
        legal'ops = Fold.all (Fold.all isLegalOp) (ops sign)
    in all id [legal'subsorts, legal'ops]

-- | check that a Signature is a subsignature of another Signature
isSubsign :: Sign -> Sign -> Bool
isSubsign sig1 sig2 = let
        apply func items = func (items sig1) (items sig2)
        has'sorts = apply Set.isSubsetOf sorts
        has'subsorts = apply Rel.isSubrelOf subsorts
        has'ops = apply Map.isSubmapOf ops
        -- TODO: Check Sentences as well?
    in all id [has'sorts, has'subsorts, has'ops]

-- | check that a Signature can include a Sentence
includesSentence :: Sign -> Sentence -> Bool
includesSentence sign sen = let
        -- NOTE: We could have used the `apply' pattern here, but the type system won't comply.
        has'ops   = Set.isSubsetOf (getOps sen)   (getOps sign)
        has'sorts = Set.isSubsetOf (getSorts sen) (getSorts sign)
    in all id [has'sorts, has'ops]

-- | simplification of sentences (leave out qualifications)
-- TODO: Add real implementation of simplification. Maybe.
simplifySentence :: Sign -> Sentence -> Sentence
simplifySentence _ = id

-- TODO: Reenable all of these!
-- -- | rename the given sort
-- renameListSort :: [(Qid, Qid)] -> Sign -> Sign
-- renameListSort rnms sg = foldr f sg rnms
--               where f (x, y) = renameSort x y
-- 
-- -- | rename the given sort
-- renameSort :: Qid -> Qid -> Sign -> Sign
-- renameSort from to sign = Sign sorts' subsorts' ops' sens'
--               where sorts' = ren'sort'sortset from to $ sorts sign
--                     subsorts' = ren'sort'subsortrel from to $ subsorts sign
--                     ops' = ren'sort'op_map from to $ ops sign
--                     sens' = ren'sort'sentences from to $ sentences sign
-- 
-- renameLabel :: Qid -> Qid -> Sign -> Sign
-- renameLabel from to sign = sign {sentences = sens'}
--               where sens' = ren'lab'sens from to $ sentences sign
-- 
-- -- | rename the given op
-- renameOp :: Qid -> Qid -> [Attr] -> Sign -> Sign
-- renameOp from to ats sign = sign {ops = ops'}
--               where ops' = ren'op'op_map from to ats $ ops sign
-- 
-- -- | rename the op with the given profile
-- renameOpProfile :: Qid -> [Qid] -> Qid -> [Attr] -> Sign -> Sign
-- renameOpProfile from ar to ats sg = case Map.member from (ops sg) of
--                  False -> sg
--                  True -> 
--                     let ssr = Rel.transClosure $ subsorts sg
--                         ods = fromJust $ Map.lookup from (ops sg)
--                         (ods1, ods2) = Set.partition (\ (x, _, _) -> allSameKind ar x ssr) ods
--                         ods1' = ren'op'set from to ats ods1
--                         new_ops1 = if ods2 == Set.empty 
--                                    then Map.delete from (ops sg)
--                                    else Map.insert from ods2 (ops sg)
--                         new_ops2 = if ods1 == Set.empty
--                                    then new_ops1
--                                    else Map.insertWith (Set.union) to ods1' new_ops1
--                     in sg {ops = new_ops2}


-- -- TODO: kind2sort and dropClosing belong in AS_Maude if anywhere.
-- kind2sort :: String -> Qid
-- kind2sort ('`' : '[' : s) = mkSimpleId $ dropClosing s
-- kind2sort s = mkSimpleId $ s
-- 
-- dropClosing :: String -> String
-- dropClosing ('`' : ']' : []) = []
-- dropClosing (c : ss) = c : dropClosing ss
-- dropClosing _ = ""

--- Helper functions for inserting Signature members into their respective collections.

-- TODO: Reenable all of these!?
-- -- | rename a sort in a sortset
-- ren'sort'sortset :: Qid -> Qid -> SortSet -> SortSet 
-- ren'sort'sortset from to = Set.insert to . Set.delete from
-- 
-- -- | rename a sort in a subsort relation
-- ren'sort'subsortrel :: Qid -> Qid -> SubsortRel -> SubsortRel 
-- ren'sort'subsortrel from to ssr = Rel.fromList ssr''
--                 where ssr' = Rel.toList ssr
--                       ssr'' = map (ren'pair from to) ssr'
-- 
-- -- | aux function that renames pair
-- ren'pair :: Qid -> Qid -> (Qid, Qid) -> (Qid, Qid)
-- ren'pair from to (s1, s2) = if from == s1
--                             then (to, s2)
--                             else if from == s2
--                                  then (s1, to)
--                                  else (s1, s2)
-- 
-- -- | rename a sort in an operator map
-- ren'sort'op_map :: Qid -> Qid -> OpMap -> OpMap
-- ren'sort'op_map from to = Map.map (ren'sort'ops from to)
-- 
-- -- | rename a sort in a set of operator declarations
-- ren'sort'ops :: Qid -> Qid -> OpDeclSet -> OpDeclSet
-- ren'sort'ops from to = Set.map $ ren'op from to
-- 
-- -- | aux function to rename operator declarations
-- ren'op :: Qid -> Qid -> OpDecl -> OpDecl
-- ren'op from to (ar, coar, ats) = (ar', coar', ats')
--              where ar' = map (\ x -> if x == from then to else x) ar
--                    coar' = if from == coar
--                            then to
--                            else coar
--                    ats' = renameSortAttrs from to ats
-- 
-- -- | rename a sort in an attribute set. This renaming only affects to
-- -- identity attributes.
-- renameSortAttrs :: Qid -> Qid -> [Attr] -> [Attr]
-- renameSortAttrs from to = map (renameSortAttr from to)
-- 
-- -- | rename a sort in an attribute. This renaming only affects to
-- -- identity attributes.
-- renameSortAttr :: Qid -> Qid -> Attr -> Attr
-- renameSortAttr from to attr = case attr of
--          Id t -> Id $ renameSortTerm from to t
--          LeftId t -> LeftId $ renameSortTerm from to t
--          RightId t -> RightId $ renameSortTerm from to t
--          _ -> attr
-- 
-- -- | rename a sort in a term
-- renameSortTerm :: Qid -> Qid -> Term -> Term
-- renameSortTerm from to (Const q ty) = Const q $ renameSortType from to ty
-- renameSortTerm from to (Var q ty) = Var q $ renameSortType from to ty
-- renameSortTerm from to (Apply q ts ty) = Apply q (map (renameSortTerm from to) ts)
--                                                  (renameSortType from to ty)
-- 
-- -- | rename a sort in a type. This renaming does not affect kinds
-- renameSortType :: Qid -> Qid -> Type -> Type
-- renameSortType from to (TypeSort s) = TypeSort $ SortId sid'
--        where SortId sid = s
--              sid' = if (sid == from)
--                    then to
--                    else sid
-- renameSortType _ _ ty = ty
-- 
-- -- | rename a sort in the sentences.
-- ren'sort'sentences :: Qid -> Qid -> Sentences -> Sentences
-- ren'sort'sentences from to = Set.map (ren'sort'sentence from to)
-- 
-- -- | rename a sort in a sentence.
-- ren'sort'sentence :: Qid -> Qid -> Sentence -> Sentence
-- ren'sort'sentence from to (Equation eq) = Equation $ Eq lhs' rhs' cond' ats
--                where Eq lhs rhs cond ats = eq
--                      lhs' = renameSortTerm from to lhs
--                      rhs' = renameSortTerm from to rhs
--                      cond' = renameSortConditions from to cond
-- ren'sort'sentence from to (Membership mb) = Membership $ Mb lhs' s' cond' ats
--                where Mb lhs s cond ats = mb
--                      lhs' = renameSortTerm from to lhs
--                      SortId sid = s
--                      s' = if (sid == from)
--                           then SortId to
--                           else s
--                      cond' = renameSortConditions from to cond
-- ren'sort'sentence from to (Rule rl) = Rule $ Rl lhs' rhs' cond' ats
--                where Rl lhs rhs cond ats = rl
--                      lhs' = renameSortTerm from to lhs
--                      rhs' = renameSortTerm from to rhs
--                      cond' = renameSortConditions from to cond
-- 
-- -- | rename a sort in a list of conditions
-- renameSortConditions :: Qid -> Qid -> [Condition] -> [Condition]
-- renameSortConditions from to = map (renameSortCondition from to)
-- 
-- -- | rename a sort in a condition
-- renameSortCondition :: Qid -> Qid -> Condition -> Condition
-- renameSortCondition from to (EqCond t1 t2) = EqCond t1' t2'
--                where t1' = renameSortTerm from to t1
--                      t2' = renameSortTerm from to t2
-- renameSortCondition from to (MatchCond t1 t2) = MatchCond t1' t2'
--                where t1' = renameSortTerm from to t1
--                      t2' = renameSortTerm from to t2
-- renameSortCondition from to (MbCond t s) = MbCond t' s'
--                where t' = renameSortTerm from to t
--                      SortId sid = s
--                      s' = if (sid == from)
--                           then SortId to
--                           else s
-- renameSortCondition from to (RwCond t1 t2) = RwCond t1' t2'
--                where t1' = renameSortTerm from to t1
--                      t2' = renameSortTerm from to t2
-- 
-- -- | rename an operator without profile in an operator map
-- ren'op'op_map :: Qid -> Qid -> [Attr] -> OpMap -> OpMap
-- ren'op'op_map from to ats = Map.fromList . map f . Map.toList
--                where f = \ (x,y) -> if x == from 
--                                     then (to, ren'op'set from to ats y)
--                                     else (x,y)
-- 
-- -- | rename the attributes in the operator declaration set
-- ren'op'set :: Qid -> Qid -> [Attr] -> OpDeclSet -> OpDeclSet
-- ren'op'set from to ats ods = Set.map f ods
--                where f = \ (x, y, z) -> let
--                               z' = ren'op'ident'ats from to z
--                               in (x, y, ren'op'ats ats z')
-- 
-- 
-- -- | rename an operator in an attribute set. This renaming only affects to
-- -- identity attributes.
-- ren'op'ident'ats :: Qid -> Qid -> [Attr] -> [Attr]
-- ren'op'ident'ats from to = map (ren'op'ident'at from to)
-- 
-- -- | rename a sort in an attribute. This renaming only affects to
-- -- identity attributes.
-- ren'op'ident'at :: Qid -> Qid -> Attr -> Attr
-- ren'op'ident'at from to attr = case attr of
--          Id t -> Id $ ren'op'term from to t
--          LeftId t -> LeftId $ ren'op'term from to t
--          RightId t -> RightId $ ren'op'term from to t
--          _ -> attr
-- 
-- -- | rename a sort in a term
-- ren'op'term :: Qid -> Qid -> Term -> Term
-- ren'op'term from to (Const q ty) = Const q' ty
--          where q' = if q == from then to else q
-- ren'op'term from to (Var q ty) = Var q' ty
--          where q' = if q == from then to else q
-- ren'op'term from to (Apply q ts ty) = Apply q' (map (ren'op'term from to) ts)
--                                            (renameSortType from to ty)
--          where q' = if q == from then to else q
-- 
-- -- | rename the attributes in an attribute set
-- ren'op'ats :: [Attr] -> [Attr] -> [Attr]
-- ren'op'ats [] curr_ats = curr_ats
-- ren'op'ats (at : ats) curr_ats = ren'op'ats ats $ ren'op'at at curr_ats
-- 
-- -- | rename an attribute in an attribute set
-- ren'op'at :: Attr -> [Attr] -> [Attr]
-- ren'op'at rn@(Prec i) (a : ats) = a' : ren'op'at rn ats
--                where a' = case a of
--                              Prec _ -> Prec i
--                              at -> at
-- ren'op'at rn@(Gather qs) (a : ats) = a' : ren'op'at rn ats
--                where a' = case a of
--                              Gather _ -> Gather qs
--                              at -> at
-- ren'op'at rn@(Format qs) (a : ats) = a' : ren'op'at rn ats
--                where a' = case a of
--                              Format _ -> Format qs
--                              at -> at
-- ren'op'at _ _ = []


-- -- | rename a label in the sentences
-- ren'lab'sens :: Qid -> Qid -> Sentences -> Sentences
-- ren'lab'sens from to = Set.map (ren'lab'sen from to)
-- 
-- -- | rename a label in a sentece
-- ren'lab'sen :: Qid -> Qid -> Sentence -> Sentence
-- ren'lab'sen from to (Equation eq) = Equation $ Eq t1 t2 cond $ ren'lab'ats from to attrs
--                where Eq t1 t2 cond attrs = eq
-- ren'lab'sen from to (Membership mb) = Membership $ Mb t s cond $ ren'lab'ats from to attrs
--                where Mb t s cond attrs = mb
-- ren'lab'sen from to (Rule rl) = Rule $ Rl t1 t2 cond $ ren'lab'ats from to attrs
--                where Rl t1 t2 cond attrs = rl
-- 
-- -- | rename a label in an attribute set
-- ren'lab'ats :: Qid -> Qid -> [StmntAttr] -> [StmntAttr]
-- ren'lab'ats from to = map (ren'lab'at from to)
-- 
-- -- | rename a label if the attribute is the label
-- ren'lab'at :: Qid -> Qid -> StmntAttr -> StmntAttr
-- ren'lab'at from to (Label l) = Label l'
--          where l' = if l == from
--                     then to
--                     else l
-- ren'lab'at _ _ attr = attr
