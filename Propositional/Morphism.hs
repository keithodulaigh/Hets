{-# OPTIONS -fallow-undecidable-instances #-}
{- |
Module      :  $Header$
Description :  Instance of class Logic for propositional logic
Copyright   :  (c) Dominik Luecke, Uni Bremen 2007
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  luecke@tzi.de
Stability   :  experimental
Portability :  portable

Definition of morphisms for propositional logic
-}
{-
  Ref.

  Till Mossakowski, Joseph Goguen, Razvan Diaconescu, Andrzej Tarlecki.
  What is a Logic?.
  In Jean-Yves Beziau (Ed.), Logica Universalis, pp. 113-@133. Birkhäuser.
  2005.
-}

module Propositional.Morphism 
    (
     Morphism (..)               -- datatype for Morphisms
    ,pretty                      -- pretty printing
    ,idMor                       -- identity morphism
    ,isLegalMorphism             -- check if morhpism is ok
    ,composeMor                  -- composition
    ) where

import qualified Data.Map as Map
import qualified Data.Set as Set
import Propositional.Sign as Sign
import Common.Id
import Common.Result
import Common.Doc
import Common.DocUtils
import Data.Typeable
import Common.ATerm.Conversion

-- Maps are simple maps between elements of sets
-- By the definition of maps in Data.Map
-- these maps are injective
type PropMap = Map.Map Id Id

-- | The datatype for morphisms in propositional logic as 
-- | simple injective maps of sets

data Morphism = Morphism
    {
       source :: Sign
     , target :: Sign
     , propMap :: PropMap
    } deriving (Eq, Show)

instance Pretty Morphism where
    pretty = printMorphism

-- | Constructs an id-morphism as the diagonal 

idMor :: Sign -> Morphism
idMor a = Morphism 
          { source = a
          , target = a
          , propMap = makeIdMor $ items a
          }
    where
      makeIdMor :: (Ord b) => Set.Set b -> Map.Map b b
      makeIdMor b = Set.fold (\x -> Map.insert x x) Map.empty b

-- | Determines whether a morphism is valid
-- since all maps from sets to sets are ok,
-- this value is glued to true

isLegalMorphism :: Morphism -> Bool
isLegalMorphism _ = True

-- | Composition of morphisms in propositional Logic
-- possibly there are far better way to solve this,
-- but I am jsut a n00b :)

composeMor :: Morphism -> Morphism -> Result Morphism
composeMor f g
    | fTarget /= gSource = fail "Morphisms are not composable"
    | otherwise = return Morphism
                  {
                   source = fSource
                  , target = gTarget
                  , propMap = composeHelper fassoc gMap Map.empty
                  }
    where
      fSource = source f
      fTarget = target f
      gSource = source g
      gTarget = target g
      fMap    = propMap f
      gMap    = propMap g
      fassoc  = Map.assocs fMap
      composeHelper :: (Ord a, Ord k, Ord b) => [(k, a)] -> Map.Map a b 
                    -> Map.Map k b -> Map.Map k b
      composeHelper [] _ newMor          = newMor
      composeHelper ((k, a):xs) h newMor =
          case Map.lookup a h of
            Nothing -> composeHelper xs h newMor
            Just v  -> composeHelper xs h (Map.insert k v newMor)

-- | Pretty printing for Morphisms
printMorphism :: Morphism -> Doc
printMorphism m = pretty (source m) <> text "-->" <> pretty (target m)
  <> vcat (map ( \ (x, y) -> lparen <> idDoc x <> text "," 
  <> idDoc y <> rparen) $ Map.assocs $ propMap m)
