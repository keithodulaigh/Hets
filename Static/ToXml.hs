{- |
Module      :  $Header$
Description :  xml output of Hets development graphs
Copyright   :  (c) Ewaryst Schulz, Uni Bremen 2009
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  Ewaryst.Schulz@dfki.de
Stability   :  provisional
Portability :  non-portable(Grothendieck)

Xml of Hets DGs
-}

module Static.ToXml where

import Static.DevGraph
import Static.PrintDevGraph ()

import Common.AS_Annotation
import Common.ConvertGlobalAnnos
import Common.DocUtils
import Common.GlobalAnnotations
import Common.Id
import Common.Result

import Text.XML.Light

import Data.Graph.Inductive.Graph as Graph
import qualified Data.Map as Map

mkAttr :: String -> String -> Attr
mkAttr = Attr . unqual

prettyElem :: Pretty a => String -> GlobalAnnos -> a -> Element
prettyElem name ga a = unode name $ showGlobalDoc ga a ""

rangeAttrs :: Range -> [Attr]
rangeAttrs rg = case rangeToList rg of
  [] -> []
  ps -> [mkAttr "range" $ show $ prettyRange ps]

annotation :: GlobalAnnos -> Annotation -> Element
annotation ga a = add_attrs (rangeAttrs $ getRangeSpan a)
  $ prettyElem "Annotation" ga a

annotations :: GlobalAnnos -> [Annotation] -> [Element]
annotations = map . annotation

subnodes :: String -> [Element] -> [Element]
subnodes name elems = if null elems then [] else
  [unode name elems]

dGraph :: DGraph -> Element
dGraph dg =
  let body = dgBody dg
      ga = globalAnnos dg
      lnodes = labNodes body
      nm = Map.fromList $ map (\ (v, lbl) -> (v, dgn_name lbl)) lnodes
  in unode "DGraph" $
         subnodes "Global" (annotations ga $ convertGlobalAnnos ga)
         ++ map (lnode ga) lnodes
         ++ map (ledge ga nm) (labEdges body)

lnode :: GlobalAnnos -> LNode DGNodeLab -> Element
lnode ga (_, lbl) =
  add_attr (mkAttr "name" . showName $ dgn_name lbl)
  $ prettyElem "Node" ga lbl

lookupNodeName :: Int -> Map.Map Int NodeName -> String
lookupNodeName i = showName . Map.findWithDefault (error "lookupNodeName") i

ledge :: GlobalAnnos -> Map.Map Int NodeName -> LEdge DGLinkLab -> Element
ledge ga nm (f, t, lbl) =
  add_attrs [ mkAttr "source" $ lookupNodeName f nm
            , mkAttr "target" $ lookupNodeName t nm ]
  $ prettyElem "Link" ga lbl

