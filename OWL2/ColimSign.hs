{- |
Module      :  $Header$
Description :  OWL signatures colimits
Copyright   :  (c) Mihai Codescu, and Uni Bremen 2009
License     :  GPLv2 or higher, see LICENSE.txt
Maintainer  :  mcodescu@informatik.uni-bremen.de
Stability   :  provisional
Portability :  non-portable

OWL signature colimits, computed component-wise.

-}

module OWL2.ColimSign where

import OWL2.Sign
import OWL2.Morphism
import OWL2.AS

import Common.SetColimit
import Common.Lib.Graph

import Data.Graph.Inductive.Graph as Graph
import qualified Data.Map as Map

signColimit :: Gr Sign (Int, OWLMorphism) ->
               (Sign, Map.Map Int OWLMorphism)
signColimit graph = let
   conGraph = emap (getEntityTypeMap Class) $ nmap concepts graph
   dataGraph = emap (getEntityTypeMap Datatype) $ nmap datatypes graph
   indGraph = emap (getEntityTypeMap NamedIndividual) $ nmap individuals graph
   objGraph = emap (getEntityTypeMap ObjectProperty) $
              nmap objectProperties graph
   dataPropGraph = emap (getEntityTypeMap DataProperty) $
               nmap dataProperties graph
   (con, funC) = addIntToSymbols $ computeColimitSet conGraph
   (dat, funD) = addIntToSymbols $ computeColimitSet dataGraph
   (ind, funI) = addIntToSymbols $ computeColimitSet indGraph
   (obj, funO) = addIntToSymbols $ computeColimitSet objGraph
   (dp, funDP) = addIntToSymbols $ computeColimitSet dataPropGraph
   morFun i = foldl Map.union Map.empty
               [ setEntityTypeMap Class $
                   Map.findWithDefault (error "maps") i funC,
                 setEntityTypeMap Datatype $
                   Map.findWithDefault (error "maps") i funD,
                 setEntityTypeMap NamedIndividual $
                   Map.findWithDefault (error "maps") i funI,
                 setEntityTypeMap ObjectProperty $
                   Map.findWithDefault (error "maps") i funO,
                 setEntityTypeMap DataProperty $
                   Map.findWithDefault (error "maps") i funDP
                ]
   morMaps = Map.fromAscList $
              map (\ x -> (x, morFun x)) $ nodes graph
   nameMap = foldl Map.union Map.empty $
             map (\ (_, l) -> prefixMap l) $ labNodes graph
   colimSign = emptySign {
                  concepts = con,
                  datatypes = dat,
                  objectProperties = obj,
                  dataProperties = dp,
                  individuals = ind,
                  prefixMap = nameMap
                }
   colimMor = Map.fromAscList $
                map (\ (i, ssig) -> let
                         mm = Map.findWithDefault (error "mor") i morMaps
                         om = OWLMorphism {
                               osource = ssig,
                               otarget = colimSign,
                               mmaps = mm
                              }
                                   in (i, om)
                     ) $ labNodes graph
  in (colimSign, colimMor)

instance SymbolName QName where
 addIntAsSuffix (QN p l b n, i) = QN p (l ++ show i) b n

getEntityTypeMap :: EntityType -> (Int, OWLMorphism)
                    -> (Int, Map.Map QName QName)
getEntityTypeMap e (i, phi) = let
 f = Map.filterWithKey
      (\ (Entity x _) _ -> x == e) $ mmaps phi
 in (i, Map.fromList $
    map (\ (Entity _ x, y) -> (x, y)) $
    Map.toAscList f)

setEntityTypeMap :: EntityType -> Map.Map QName QName
                    -> Map.Map Entity QName
setEntityTypeMap = Map.mapKeys . Entity
