{- |
Module      :  $Header$
Description :  xml input for Hets development graphs
Copyright   :  (c) Simon Ulbricht, DFKI GmbH 2011
License     :  GPLv2 or higher, see LICENSE.txt
Maintainer  :  tekknix@tzi.de
Stability   :  provisional
Portability :  non-portable (DevGraph)

create new or extend a Development Graph in accordance with an XML input
-}

module Static.FromXml where

import Static.DevGraph
import Static.GTheory

import Logic.Logic (AnyLogic (..))
import Logic.Prover (noSens)
import Logic.Grothendieck (LogicGraph (..), startSigId)
import Logic.ExtSign (ext_empty_signature)

import qualified Data.Map as Map (lookup)
import Data.List (partition)

import Text.XML.Light

--TODO: write test module!

type NamedNode = (String,Element)
type NamedLink = ((String,String),Element)

fromXML :: LogicGraph -> DGraph -> Element -> DGraph
fromXML lg dg el = case Map.lookup (currentLogic lg) (logics lg) of
  Nothing ->
    error "FromXML.fromXML: current logic was not found in logicMap"
  Just (Logic lid) -> let
    emptyTheory = G_theory lid (ext_empty_signature lid)
                    startSigId noSens startThId
    -- extract all nodes and store them with their names in fst field
    nodes :: [NamedNode]
    nodes = map nameNode $ findChildren (unqual "DGNode") el where
      nameNode e = case findAttr (unqual "name") e of
                 Just name -> (name, e)
                 Nothing -> error "FromXML.fromXML: node has no name"
    -- extract all links and store tuple of source and target names in fst field
    links :: [NamedLink] -- TODO filter links so only DefLinks are considered
    links = map nameLink $ findChildren (unqual "DGLink") el where
      nameLink e = case findAttr (unqual "source") e of
                 Just src -> case findAttr (unqual "target") e of
                   Just trg -> ((src, trg), e)
                   Nothing -> error "FromXML.fromXML: link has no target"
                 Nothing -> error "FromXML.fromXML: link has no source"
    (dg', depNodes) = initialiseNodes dg emptyTheory nodes links
    in iterateLinks dg' depNodes links

{-
  All nodes that do not have dependencies via the links are processed at the
  beginning and written into the DGraph. The remaining nodes are returned as
  well for further processing.
-}
initialiseNodes :: DGraph -> G_theory -> [NamedNode] -> [NamedLink] 
                -> (DGraph,[NamedNode])
initialiseNodes dg gt nodes links = let 
  targets = map (snd . fst) links
  -- all nodes that are not targeted by any links are considered independent
  (dep, indep) = partition ((`elem` targets) . fst) nodes
  dg' = foldl insertNodeDG dg $ map (mkDGNodeLab gt) indep
  in (dg',dep)

{-
  Writes a single Node into the DGraph
-}
insertNodeDG :: DGraph -> DGNodeLab -> DGraph
insertNodeDG dg lbl = let n = getNewNodeDG dg in
  insLNodeDG (n,lbl) dg

-- TODO: links have to be inserted as well, use insLEdgeDG
insertEdgeDG :: NamedLink -> DGraph -> DGraph
insertEdgeDG ((src,trg),l) dg = undefined

{-
  This is the main loop. In every step, all links are extracted which source
  has already been processed. Then, for each of these links, the target node
  is calculated and stored using the sources G_theory.
  The function is called again with the remaining links and additional nodes
  (stored in DGraph) until the list of links reaches null.
-}
iterateLinks :: DGraph -> [NamedNode] -> [NamedLink] -> DGraph
iterateLinks dg _ [] = dg
iterateLinks dg nodes links = let (cur,lftL) = splitLinks dg links
                                  (dg',lftN) = processNodes nodes cur dg
  in if null cur then error 
      "FromXML.iterateLinks: remaining links cannot be processed"
    else iterateLinks dg' lftN lftL

{-
  Help function for iterateNodes. For every link, the target node is created
  and stored in DGraph. Then the link is stored in DGraph.
  Returns updated DGraph and the list of nodes that have not been captured.
-}
processNodes :: [NamedNode] -> [(G_theory,NamedLink)] -> DGraph 
             -> (DGraph,[NamedNode])
processNodes nodes [] dg = (dg,nodes)
processNodes nodes ((th,l@((_,trg),_)):ls) dg = 
  case partition ((== trg) . fst) nodes of
    ([o],r) -> processNodes r ls $ insertEdgeDG l 
            $ insertNodeDG dg (mkDGNodeLab th o)
    _ -> error "fromXML.processNodes: link has no or multiple targets"

{-
  Help function for iterateNodes. Given a list of links, it partitions the
  links depending on if their source has been processed. Then stores the
  source-nodes G_theory alongside for easy access.
-}
splitLinks :: DGraph -> [NamedLink] -> ([(G_theory,NamedLink)],[NamedLink])
splitLinks dg = foldr (\l@((src,_),_) (r,r') -> case lookupNodeByName src dg of
    [(_,lbl)] -> ((dgn_theory lbl, l):r,r')
    [] -> (r,l:r') 
    _ -> error "FromXML.splitLinks: found multiple nodes for one NodeName" 
  ) ([],[])

{-
  Generates a new DGNodeLab with a startoff-G_theory and an Element
-}
mkDGNodeLab :: G_theory -> NamedNode -> DGNodeLab
mkDGNodeLab gt (name, el) = let
  (response,message) = extendByBasicSpec (strContent el) gt -- TODO extract string properly!
  in case response of
    Failure _ -> error $ "FromXML.mkDGNodeLab: "++message
    Success gt' _ symbs _ -> 
      newNodeLab (parseNodeName name) (DGBasicSpec Nothing symbs) gt'

extractBasicSpecs :: Element -> String
extractBasicSpecs el = case elChildren el of
  [] -> strContent el ++ "\n"
  cld -> concat $ map extractBasicSpecs cld
