{- |
Module      :  $Header$
Description :  Morphisms for Maude
Copyright   :  (c) Martin Kuehl, Uni Bremen 2008
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  mkhl@informatik.uni-bremen.de
Stability   :  experimental
Portability :  portable

Definition of morphisms for Maude.
-}
{-
  Ref.

  ...
-}

module Maude.Morphism (
    Morphism(..),
    fromRenamings,
    symbolMap,
    identity,
    inverse,
) where

import Maude.AS_Maude

import Maude.Sign (Sign)
import qualified Maude.Sign as Sign

import Data.Set (Set)
import Data.Map (Map)
import Data.Typeable (Typeable)
import qualified Data.Set as Set
import qualified Data.Map as Map
import qualified Data.Foldable as Fold

import Common.Id (Token)
import Common.Result (Result)
import qualified Common.Result as Result


type SortMap = Map Token Token
type OpMap = Map Token Token
type LabelMap = Map Token Token

data Morphism = Morphism {
        source :: Sign,
        target :: Sign,
        sortMap :: SortMap,
        opMap :: OpMap,
        labelMap :: LabelMap
    } deriving Show--(Show, Eq, Ord, Typeable)


-- | extract a Morphism from a list of Renamings
fromRenamings :: [Renaming] -> Morphism
fromRenamings = foldr insertRenaming empty

-- | extract a Symbol Map from a Morphism
symbolMap :: Morphism -> Map Token Token
symbolMap mor = Map.unions [(sortMap mor), (opMap mor), (labelMap mor)]

-- | insert a Renaming into a Morphism
insertRenaming :: Renaming -> Morphism -> Morphism
insertRenaming rename mor = let
        src = source mor
        tgt = target mor
        smap = sortMap mor
        omap = opMap mor
        lmap = labelMap mor
    in case rename of
        (SortRenaming from to) -> let
                a = sortName from
                b = sortName to
            in mor {
                source = Sign.insertSort from src,
                target = Sign.insertSort to tgt,
                sortMap = Map.insert a b smap
            }
        (LabelRenaming from to) -> let
                a = labelName from
                b = labelName to
            in mor {
                labelMap = Map.insert a b lmap
            }
        (OpRenaming1 from (To to _)) -> let
                a = opName from
                b = opName to
            in mor {
                source = Sign.insertOpName from src,
                target = Sign.insertOpName to tgt,
                opMap = Map.insert a b omap
            }
        (OpRenaming2 from _ _ (To to _)) -> let
                a = opName from
                b = opName to
            in mor {
            source = Sign.insertOpName from src,
            target = Sign.insertOpName to tgt,
                opMap = Map.insert a b omap
            }

-- | the empty Morphism
empty :: Morphism
empty = identity Sign.empty

-- | the identity Morphism
identity :: Sign -> Morphism
identity sign = Morphism {
        source = sign,
        target = sign,
        sortMap = Map.empty,
        opMap = Map.empty,
        labelMap = Map.empty
    }

-- -- | the composition of two Morphisms
-- compose :: Morphism -> Morphism -> Result Morphism
-- compose f g
--     | target f /= source g = fail "target of the first and source of the second morphism are different"
--     | otherwise = let
--             apply mp nam = Map.findWithDefault nam nam mp
--             map'map mp = apply (mp g) . apply (mp f)
--             insert mp x = let y = map'map mp x
--                 in if x == y then id else Map.insert x y
--             compose'map mp items = if Map.null (mp g)
--                 then mp f
--                 else Set.fold (insert mp) Map.empty $ items (source f)
--         in return Morphism {
--                 source = (source f),
--                 target = (target g),
--                 sortMap = compose'map sortMap getSorts,
--                 opMap = compose'map opMap getOps,
--                 labelMap = compose'map labelMap getLabels
--             }

-- | the inverse of a Morphism
inverse :: Morphism -> Result Morphism
inverse mor = let
        inverseMap = Map.foldWithKey (flip Map.insert) Map.empty
    in return Morphism {
        source = (target mor),
        target = (source mor),
        sortMap  = inverseMap (sortMap mor),
        opMap    = inverseMap (opMap mor),
        labelMap = inverseMap (labelMap mor)
    }

-- -- | check that a Morphism is legal
-- isLegal :: Morphism -> Bool
-- isLegal mor = let
--         src = source mor
--         tgt = target mor
--         smap = sortMap mor
--         omap = opMap mor
--         lmap = labelMap mor
--         apply mp nam = Map.findWithDefault nam nam mp
--         subset mp items = Set.isSubsetOf (Set.map (apply mp) $ items src) (items tgt)
--         legal'source = Sign.isLegal src
--         legal'sortMap = subset smap getSorts
--         legal'opMap = subset omap getOps
--         legal'labelMap = subset lmap getLabels
--         legal'target = Sign.isLegal tgt
--     in all id [legal'source, legal'sortMap, legal'opMap, legal'labelMap, legal'target]


-- extract the name from a Sort, Op or Label
sortName (SortId name) = name
opName (OpId name) = name
labelName (LabelId name) = name