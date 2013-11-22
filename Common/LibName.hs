{- |
Module      :  $Header$
Description :  library names for HetCASL and development graphs
Copyright   :  (c) Christian Maeder, DFKI GmbH 2008
License     :  GPLv2 or higher, see LICENSE.txt
Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

Abstract syntax of HetCASL specification libraries
   Follows Sect. II:2.2.5 of the CASL Reference Manual.
-}

module Common.LibName where

import Common.Doc
import Common.DocUtils
import Common.Id
import Common.Keywords
import Common.Utils

import Data.Char
import Data.List
import Data.Ord

import System.FilePath

omTs :: [Token]
omTs = [genToken "OM"]

mkQualName :: SIMPLE_ID -> LibId -> Id -> Id
mkQualName nodeId libId i =
  Id omTs [i, simpleIdToId nodeId, libIdToId libId] $ posOfId i

isQualNameFrom :: SIMPLE_ID -> LibId -> Id -> Bool
isQualNameFrom nodeId libId i@(Id _ cs _) = case cs of
  _ : n : l : _ | isQualName i ->
    n == simpleIdToId nodeId && libIdToId libId == l
  _ -> True

isQualName :: Id -> Bool
isQualName (Id ts cs _) = case cs of
  _ : _ : _ -> ts == omTs
  _ -> False

unQualName :: Id -> Id
unQualName j@(Id _ cs _) = case cs of
  i : _ | isQualName j -> i
  _ -> j

libIdToId :: LibId -> Id
libIdToId li = let
  path = splitOn '/' $ show li
  toTok s = Token s $ getRange li
  in mkId $ map toTok $ intersperse "/" path

data LibName = LibName
    { getLibId :: LibId
    , libVersion :: Maybe VersionNumber }

emptyLibName :: String -> LibName
emptyLibName s = LibName (IndirectLink s nullRange "") Nothing

data LibId = IndirectLink PATH Range FilePath
              -- pos: start of PATH

updFilePathOfLibId :: FilePath -> LibId -> LibId
updFilePathOfLibId fp (IndirectLink p r _) = IndirectLink p r fp

setFilePath :: FilePath -> LibName -> LibName
setFilePath fp ln =
  ln { getLibId = updFilePathOfLibId fp $ getLibId ln }

getFilePath :: LibName -> FilePath
getFilePath ln =
    case getLibId ln of
      IndirectLink _ _ fp -> fp

data VersionNumber = VersionNumber [String] Range
                      -- pos: "version", start of first string

type PATH = String

instance GetRange LibId where
  getRange (IndirectLink _ r _) = r

instance Show LibId where
  show (IndirectLink s1 _ _) = s1

instance GetRange LibName where
  getRange = getRange . getLibId

instance Show LibName where
  show = show . hsep . prettyLibName

prettyVersionNumber :: VersionNumber -> [Doc]
prettyVersionNumber (VersionNumber v _) =
  [keyword versionS, hcat $ punctuate dot $ map codeToken v]

prettyLibName :: LibName -> [Doc]
prettyLibName (LibName i mv) = pretty i : case mv of
        Nothing -> []
        Just v -> prettyVersionNumber v

instance Eq LibId where
  IndirectLink s1 _ _ == IndirectLink s2 _ _ = s1 == s2

instance Ord LibId where
  IndirectLink s1 _ _ <= IndirectLink s2 _ _ = s1 <= s2

instance Eq LibName where
  ln1 == ln2 = compare ln1 ln2 == EQ

instance Ord LibName where
  compare = comparing getLibId

instance Pretty LibName where
    pretty = fsep . prettyLibName

instance Pretty LibId where
    pretty = structId . show

data LinkPath a = LinkPath a [(LibId, Int)] deriving (Ord, Eq)

type SLinkPath = LinkPath String

convertFileToLibStr :: FilePath -> String
convertFileToLibStr = mkLibStr . takeBaseName

stripLibChars :: String -> String
stripLibChars = filter (\ c -> isAlphaNum c || elem c "'_/")

mkLibStr :: String -> String
mkLibStr = dropWhile (== '/') . stripLibChars
