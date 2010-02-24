{-# LANGUAGE
  FlexibleInstances
  , TypeSynonymInstances
 #-}

{- |
Module      :  $Header$
Description :  OMDoc-to/from-XML conversion
Copyright   :  (c) Ewaryst Schulz, DFKI 2009
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  ewaryst.schulz@dfki.de
Stability   :  provisional
Portability :  non-portable(Logic)

The transformation of the OMDoc intermediate representation to and from XML.
-}



module OMDoc.XmlInterface
    ( listToXml
    , listFromXml
    , makeComment
    , xmlOut
    , xmlIn
    ) where

import OMDoc.DataTypes
import Text.XML.Light
import Data.Maybe
import Data.List
import Common.Result
import Common.Id

-- | The implemented OMDoc version
omdoc_current_version :: String
omdoc_current_version = "1.6"

{-
-- the often used element names can be produced with this program

import Data.List
import Data.Char

val1 prfix f qual s = prfix ++ s ++ " = (blank_name { qName = " ++ show (f s) ++ qual ++ " })"
val2 prfix f qual s = prfix ++ s ++ " = toQN" ++ qual ++ " " ++ show (f s)

out = putStrLn out1
out1 = 
    let om1 = " , qPrefix = Just \"om\""
        om2 = "OM"
        om = om2
        val = val2
        elprfix = "el_"
        atprfix = "at_"
        toUpper = map Data.Char.toUpper
        typedecl prfix l = (Data.List.intercalate ", " $ map (\x -> prfix ++ x) l) ++ " :: QName"
        e1 = ["omdoc", "theory", "view", "structure", "type", "adt", "sortdef", "constructor", "argument", "insort", "selector", "morphism", "conass", "constant", "definition"]
        e2 = ["omobj"]
        e3 = ["ombind", "oms", "ombvar", "omattr", "omatp", "omv", "oma"]
        a1 = ["version", "cd", "name", "meta", "role", "type", "total", "for", "from", "to", "cdbase"]
    in unlines [ typedecl elprfix $ e1 ++ e2 ++ e3
               , ""
               , unlines $ map (val elprfix id "") e1
               , unlines $ map (val elprfix toUpper "") e2
               , unlines $ map (val elprfix toUpper om) e3
               , typedecl atprfix a1
               , ""
               , unlines $ map (val atprfix id "") a1]


-}

toQN :: String -> QName
toQN s = blank_name { qName = s }
toQNOM :: String -> QName
toQNOM s = blank_name { qName = s , qPrefix = Just "om" }

-- | often used element names

el_omdoc, el_theory, el_view, el_structure, el_type, el_adt
 , el_sortdef, el_constructor, el_argument, el_insort, el_selector
 , el_morphism, el_conass, el_constant, el_definition, el_omobj
 , el_ombind, el_oms, el_ombvar, el_omattr, el_omatp, el_omv, el_oma :: QName

el_omdoc = toQN "omdoc"
el_theory = toQN "theory"
el_view = toQN "view"
el_structure = toQN "structure"
el_type = toQN "type"
el_adt = toQN "adt"
el_sortdef = toQN "sortdef"
el_constructor = toQN "constructor"
el_argument = toQN "argument"
el_insort = toQN "insort"
el_selector = toQN "selector"
el_morphism = toQN "morphism"
el_conass = toQN "conass"
el_constant = toQN "constant"
el_definition = toQN "definition"

el_omobj = toQN "OMOBJ"

el_ombind = toQNOM "OMBIND"
el_oms = toQNOM "OMS"
el_ombvar = toQNOM "OMBVAR"
el_omattr = toQNOM "OMATTR"
el_omatp = toQNOM "OMATP"
el_omv = toQNOM "OMV"
el_oma = toQNOM "OMA"

at_version, at_cd, at_name, at_meta, at_role, at_type, at_total
 , at_for, at_from, at_to, at_cdbase :: QName

at_version = toQN "version"
at_cd = toQN "cd"
at_name = toQN "name"
at_meta = toQN "meta"
at_role = toQN "role"
at_type = toQN "type"
at_total = toQN "total"
at_for = toQN "for"
at_from = toQN "from"
at_to = toQN "to"
at_cdbase = toQN "cdbase"


attr_om :: Attr
attr_om = Attr (blank_name { qName = "om" , qPrefix = Just "xmlns" })
          "http://www.openmath.org/OpenMath"


{- |
  this class defines the interface to read from and write to XML
-}
class XmlRepresentable a where
  -- | render instance to an XML Element
  toXml :: a -> Content
  -- | read instance from an XML Element
  fromXml :: Element -> Result (Maybe a)


xmlOut :: XmlRepresentable a => a -> String
xmlOut obj = case toXml obj of (Elem e) -> ppTopElement e
                               c -> ppContent c

xmlIn :: String -> Result OMDoc
xmlIn s = case parseXMLDoc s of
            Just e -> fromXml e >>= maybeToMonad "xmlIn"
            _ -> fail "xmlIn: Root element missing"


listToXml :: XmlRepresentable a => [a] -> [Content]
listToXml l = map toXml l

listFromXml :: XmlRepresentable a => [Content] -> Result [a]
listFromXml elms = fmap catMaybes $ mapR fromXml (onlyElems elms)

makeComment :: String -> Content
makeComment s = Text $ CData CDataRaw ("<!-- " ++ s ++ " -->") Nothing


inAContent :: QName -> [Attr] -> Maybe Content -> Content
inAContent qn a c = Elem $ Element qn a (maybeToList c) Nothing

inContent :: QName -> Maybe Content -> Content
inContent qn c = inAContent qn [] c

toOmobj :: Content -> Content
toOmobj c = inAContent el_omobj [attr_om] $ Just c

-- don't need it now
--uriEncodeOMS :: OMCD -> OMName -> String
--uriEncodeOMS omcd omname = uriEncodeCD omcd ++ "?" ++ encodeOMName omname

uriEncodeCD :: OMCD -> String
uriEncodeCD (CD omcd base) = (fromMaybe "" base) ++ "?" ++ omcd

uriDecodeCD :: String -> OMCD
-- TODO: implement the decoding
uriDecodeCD s = CD s Nothing

encodeOMName :: OMName -> String
encodeOMName on = intercalate "/" (path on ++ [name on])

decodeOMName :: String -> OMName
-- TODO: implement the decoding
decodeOMName s = mkSimpleName s

tripleEncodeOMS :: OMCD -> OMName -> [Attr]
tripleEncodeOMS omcd omname
    = pairEncodeCD omcd ++ [Attr at_name $ encodeOMName omname]

pairEncodeCD :: OMCD -> [Attr]
pairEncodeCD (CD omcd base) =
    (maybe [] (\x -> [Attr at_cdbase x]) base) ++ [Attr at_cd omcd]

warnIfNothing :: String -> (Maybe a -> b)  -> Maybe a -> Result b
warnIfNothing s f v = let o = f v in
                      case v of Nothing -> warning () s  nullRange >> return o
                                _ -> return o

warnIf :: String -> Bool -> Result ()
warnIf s b = if b then warning () s  nullRange else return ()

oneOfMsg :: Element -> [QName] -> String
oneOfMsg e l = concat [ "Couldn't find expected element {"
                      , intercalate ", " (map qName l), "}"
                      , fromMaybe "" $ fmap ((" at line "++).show) $ elLine e
                      , " but found ", qName $ elName e, "."
                      ]

------------------------- Monad and Maybe interplay -------------------------

justReturn :: Monad m => a -> m (Maybe a)
justReturn = return . Just

fmapMaybe :: Monad m => (a -> m b) -> Maybe a -> m (Maybe b)
fmapMaybe f v = encapsMaybe $ fmap f v

fmapFromMaybe :: Monad m => (a -> m (Maybe b)) -> Maybe a -> m (Maybe b)
fmapFromMaybe f = flattenMaybe . fmapMaybe f

encapsMaybe :: Monad m => Maybe (m a) -> m (Maybe a)
encapsMaybe v = case v of { Just x -> x >>= justReturn; _ -> return Nothing }

flattenMaybe :: Monad m => m (Maybe (Maybe a)) -> m (Maybe a)
flattenMaybe v = v >>= return . fromMaybe Nothing


-- | Function to extract the Just values from maybes with a default missing
--   error in case of Nothing
missingMaybe :: String -> String -> Maybe a -> a
missingMaybe el misses = 
    fromMaybe (error $ el ++ " element must have a " ++ misses ++ ".")


------------------------------ Class instances ------------------------------


-- | The root instance for representing OMDoc in XML
instance XmlRepresentable OMDoc where
    toXml (OMDoc omname elms) =
        (Elem $ Element el_omdoc
         [Attr at_version omdoc_current_version, Attr at_name omname]
         (listToXml elms)
         Nothing)

    fromXml e
        | elName e == el_omdoc =
            do
              nm <- warnIfNothing "No name in omdoc element." (fromMaybe "")
                    $ findAttr at_name e
              vs <- warnIfNothing "No version in omdoc element."
                    (fromMaybe "1.6") $ findAttr at_version e
              warnIf "Wrong OMDoc version." $ vs /= omdoc_current_version
              tls <- listFromXml $ elContent e
              justReturn $ OMDoc nm tls
        | otherwise = fail "OMDoc fromXml: toplevel element is no omdoc."


-- | toplevel OMDoc elements to XML and back
instance XmlRepresentable TLElement where
    toXml (TLTheory tname meta elms) =
        (Elem $ Element el_theory
         ((Attr at_name tname)
           : case meta of Nothing -> []
                          Just mtcd -> [Attr at_meta $ uriEncodeCD mtcd])
         (listToXml elms)
         Nothing)
    toXml (TLView nm from to mor) =
        inAContent
        el_view [Attr at_name nm, Attr at_from $ uriEncodeCD from,
                      Attr at_to $ uriEncodeCD to]
                    $ fmap toXml mor

    fromXml e
        | elName e == el_theory =
            let nm = missingMaybe "Theory" "name" $ findAttr at_name e
                mt = fmap uriDecodeCD $ findAttr at_meta e
            in do
              tcl <- listFromXml $ elContent e
              justReturn $ TLTheory nm mt tcl

        | elName e == el_view =
            let musthave at s = missingMaybe "View" s $ findAttr at e
                nm = musthave at_name "name"
                from = uriDecodeCD $ musthave at_from "from"
                to = uriDecodeCD $ musthave at_to "to"
            in do
              tc <- fmapFromMaybe fromXml $ findChild el_morphism e
              justReturn $ TLView nm from to tc
        | otherwise = return Nothing


-- | theory constitutive OMDoc elements to XML and back
instance XmlRepresentable TCElement where
    toXml (TCSymbol sname symtype role defn) =
        constantToXml sname (show role) symtype defn
    toXml (TCADT sds) = Elem $ Element el_adt [] (listToXml sds) Nothing
    toXml (TCComment c) = makeComment c
    toXml (TCImport nm from mor) =
        inAContent
        el_structure
        [Attr at_name nm, Attr at_from $ uriEncodeCD from] $ fmap toXml mor
    toXml (TCMorphism mapping) =
        Elem $ Element el_morphism [] (map assignmentToXml mapping) Nothing

    fromXml e
        | elName e == el_constant =
            let musthave s v = missingMaybe "Constant" s v
                nm = musthave "name" $ findAttr at_name e
                role = fromMaybe Obj $ fmap read $ findAttr at_role e
            in do
              typ <- fmap (musthave "typ") $ omelementFrom el_type e
              defn <- omelementFrom el_definition e
              justReturn $ TCSymbol nm typ role defn
        | elName e == el_structure =
            let musthave at s = missingMaybe "Structure" s $ findAttr at e
                nm = musthave at_name "name"
                from = uriDecodeCD $ musthave at_from "from"
            in do
              tc <- fmapFromMaybe fromXml $ findChild el_morphism e
              justReturn $ TCImport nm from tc
        | elName e == el_adt =
            do
              sds <- listFromXml $ elContent e
              justReturn $ TCADT sds
        | elName e == el_morphism =
            mapR xmlToAssignment (findChildren el_conass e)
                     >>= justReturn . TCMorphism
        | otherwise =
            fail $ oneOfMsg e [el_constant, el_structure, el_adt, el_morphism]


-- | OMDoc - Algebraic Data Types
instance XmlRepresentable OmdADT where
    toXml (ADTSortDef n b cs) =
        Elem $ Element el_sortdef
                 [Attr at_name n,
                  Attr at_type $ show b]
                 (listToXml cs) Nothing
    toXml (ADTConstr n args) =
        Elem $ Element el_constructor [Attr at_name n] (listToXml args) Nothing
    toXml (ADTArg t sel) =
        Elem $ Element el_argument []
                 (typeToXml t :
                  case sel of Nothing -> []
                              Just s -> [toXml s])
                 Nothing
    toXml (ADTSelector n total) =
        Elem $ Element el_selector
                 [Attr at_name n,
                  Attr at_total $ show total]
                 [] Nothing
    toXml (ADTInsort n) = Elem $ Element el_insort [Attr at_for n] [] Nothing

    fromXml e
        | elName e == el_sortdef =
            let musthave s at = missingMaybe "Sortdef" s $ findAttr at e
                nm = musthave "name" at_name
                typ = read $ musthave "type" at_type
            in do
              entries <- listFromXml $ elContent e
              justReturn $ ADTSortDef nm typ entries
        | elName e == el_constructor =
            do
              let nm = missingMaybe "Constructor" "name" $ findAttr at_name e
              entries <- listFromXml $ elContent e
              justReturn $ ADTConstr nm entries
        | elName e == el_argument =
            do
              typ <- fmap (missingMaybe "Argument" "typ")
                     $ omelementFrom el_type e
              sel <- fmapFromMaybe fromXml $ findChild el_selector e
              justReturn $ ADTArg typ sel
        | elName e == el_selector =
            let musthave s at = missingMaybe "Selector" s $ findAttr at e
                nm = musthave "name" at_name
                total = read $ musthave "total" at_total
            in justReturn $ ADTSelector nm total
        | elName e == el_insort =
            do
              let nm = missingMaybe "Insort" "for" $ findAttr at_for e
              justReturn $ ADTInsort nm
        | otherwise =
            fail $ oneOfMsg e [ el_sortdef, el_constructor, el_argument
                              , el_selector, el_insort]


-- | OpenMath elements to XML and back
instance XmlRepresentable OMElement where
    toXml (OMS d n) = Elem $ Element el_oms
                       (tripleEncodeOMS d n)
                       []
                       Nothing
    toXml (OMV n) = Elem $ Element el_omv [Attr at_name (name n)] [] Nothing
    toXml (OMATTT elm attr) =
        Elem $ Element el_omattr
         []
         [toXml attr, toXml elm]
         Nothing
    toXml (OMA args) = Elem $ Element el_oma [] (listToXml args) Nothing
    toXml (OMBIND symb vars body) =
        Elem $ Element el_ombind
         []
         [toXml symb,
          Elem (Element el_ombvar [] (listToXml vars) Nothing),
          toXml body]
         Nothing

    fromXml e
        | elName e == el_oms =
            let nm = missingMaybe "OMS" "name" $ findAttr at_name e
                omcd = fromMaybe "" $ findAttr at_cd e
                cdb = findAttr at_cdbase e
            in justReturn $ OMS (CD omcd cdb) $ decodeOMName nm
        | elName e == el_omv =
            let nm = missingMaybe "OMV" "name" $ findAttr at_name e
            in justReturn $ OMV $ decodeOMName nm
        | elName e == el_omattr =
            let [atp, el] = elChildren e
                musthave s v = missingMaybe "OMATTR" s v
            in do
              atp' <- fromXml atp
              el' <- fromXml el
              justReturn $ OMATTT (musthave "attribution" atp')
                             (musthave "attributed value" el')
        | elName e == el_oma =
            do
              entries <- listFromXml $ elContent e
              justReturn $ OMA entries
        | elName e == el_ombind =
            let [bd, bvar, body] = elChildren e
                musthave s v = missingMaybe "OMBIND" s v
            in do
              bd' <- fromXml bd
              bvar' <- listFromXml $ elContent bvar
              body' <- fromXml body
              justReturn $ OMBIND (musthave "binder" bd') bvar'
                             (musthave "body" body')
        | otherwise =
            fail $ oneOfMsg e [el_oms, el_omv, el_omattr, el_oma, el_ombind]


-- | Helper instance for OpenMath attributes
instance XmlRepresentable OMAttribute where
    toXml (OMAttr e1 e2) =
        (Elem $ Element el_omatp
         []
         [toXml e1,
          toXml e2]
         Nothing)

    fromXml e
        | elName e == el_omatp =
            do
              [key, val] <- listFromXml $ elContent e
              justReturn $ OMAttr key val
        | otherwise =
            fail $ oneOfMsg e [el_omatp]


------------------------------ fromXml methods ------------------------------

-- | Get an OMElement from an child element of type qn of the given element,
--   hence containing an OMOBJ
omelementFrom :: QName -> Element -> Result (Maybe OMElement)
omelementFrom qn e = fmapFromMaybe omelementFromOmobj $ findChild qn e

omelementFromOmobj :: Element -> Result (Maybe OMElement)
omelementFromOmobj e = fmapMaybe omobjToOMElement $ findChild el_omobj e

-- | Get an OMElement from an OMOBJ xml element
omobjToOMElement :: Element -> Result OMElement
omobjToOMElement e = case elChildren e of
                       [om] ->
                           do
                             omelem <- fromXml om
                             case omelem of
                               Nothing ->
                                   fail
                                   $ concat [ "omobjToOMElement: "
                                            , "No OpenMath element found."]
                               Just x -> return x
                       _ -> fail "OMOBJ element must have a unique child."


-- | The input is assumed to be a conass element
xmlToAssignment :: Element -> Result (OMName, OMElement)
xmlToAssignment e = 
    let musthave s v = missingMaybe "Conass" s v
        nm = musthave "name" $ findAttr at_name e
    in do
      omel <- omelementFromOmobj e
      return (decodeOMName nm, musthave "OMOBJ element" omel)


------------------------------ toXml methods ------------------------------

typeToXml :: OMElement -> Content
typeToXml t = inContent el_type $ Just $ toOmobj $ toXml t

assignmentToXml :: (OMName, OMElement) -> Content
assignmentToXml (from, to) =
    inAContent el_conass [Attr at_name $ encodeOMName from]
                   $ Just . toOmobj . toXml $ to

constantToXml :: String -> String -> OMElement -> Maybe OMElement -> Content
constantToXml n r tp prf = 
    Elem $ Element el_constant
             [Attr at_name n, Attr at_role r]
             ([typeToXml tp]
              ++ map (inContent el_definition . Just . toOmobj . toXml)
                     (maybeToList prf))
             Nothing


