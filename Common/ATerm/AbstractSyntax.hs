{- |
Module      :  $Header$
Copyright   :  (c) Klaus L�ttich, C. Maeder, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  non-portable(imports System.Mem.StableName)

data types and utilities for shared ATerms and the ATermTable
-}

module Common.ATerm.AbstractSyntax
    (ShATerm(..),
     ATermTable,
     emptyATermTable,
     addATerm,addATermNoFullSharing,
     getATerm, toReadonlyATT,
     getATermIndex,getTopIndex,
     getATerm', setATerm', getShATerm,
     Key(..), newATermTable, getKey, setKey, mkKey,
     getATermByIndex1, str2Char, integer2Int
    ) where

import qualified Common.Lib.Map as Map
import qualified Common.Lib.Map as DMap
import Common.DynamicUtils
import Data.Array
import System.Mem.StableName
import qualified Data.HashTable as HTab
import Data.Int
import GHC.Prim

data ShATerm = ShAAppl String [Int] [Int]
             | ShAList [Int]        [Int]
             | ShAInt  Integer      [Int]
               deriving (Eq, Ord)

data IntMap = Updateable !(DMap.Map Int ShATerm)
            | Readonly !(Array Int ShATerm)

empty :: IntMap
empty = Updateable $ DMap.empty

insert :: Int -> ShATerm -> IntMap -> IntMap
insert i s t = case t of
    Updateable m -> Updateable $ DMap.insert i s m
    _ -> error "ATerm.insert"

find :: Int -> IntMap -> ShATerm
find i t = case t of
    Updateable m -> DMap.findWithDefault (ShAInt (-1) []) i m
    Readonly a -> a ! i

data Key = Key (StableName ()) TypeRep deriving Eq

mkKey :: Typeable a => a -> IO Key
mkKey t = do
    s <- makeStableName t
    return $ Key (unsafeCoerce# s) $ typeOf t

hashKey :: Key -> Int32
hashKey (Key p t) = HTab.hashInt (hashStableName p) + HTab.hashString (show t)

data ATermTable = ATT
    !(Maybe (HTab.HashTable Key Int))
    !(Map.Map ShATerm Int) !IntMap !Int
    !(Map.Map (Int, String) Dynamic)

toReadonlyATT :: ATermTable -> ATermTable
toReadonlyATT (ATT h s t i dM) = ATT h s
    (case t of
     Updateable m -> Readonly $ listArray (0, i) $ DMap.elems m
     _ -> t ) i dM

emptyATermTable :: ATermTable
emptyATermTable = ATT Nothing Map.empty empty (-1) Map.empty

newATermTable :: IO ATermTable
newATermTable = do
    h <- HTab.new (==) hashKey
    return $ ATT (Just h) Map.empty empty (-1) Map.empty

addATermNoFullSharing :: ShATerm -> ATermTable -> (ATermTable,Int)
addATermNoFullSharing t (ATT h a_iDFM i_aDFM i1 dM) = let j = i1 + 1 in
    (ATT h (Map.insert t j a_iDFM) (insert j t i_aDFM) j dM, j)

addATerm :: ShATerm -> ATermTable -> (ATermTable,Int)
addATerm t at@(ATT _ a_iDFM _ _ _) =
  case Map.lookup t a_iDFM of
    Nothing -> addATermNoFullSharing t at
    Just i -> (at, i)

setKey :: Key -> Int -> ATermTable -> IO ()
setKey k i (ATT h _ _ _ _) = case h of
    Nothing -> return ()
    Just t -> HTab.insert t k i

getKey :: Key -> ATermTable -> IO (Maybe Int)
getKey k (ATT h _ _ _ _) = case h of
    Nothing -> return Nothing
    Just t -> HTab.lookup t k

getATerm :: ATermTable -> ShATerm
getATerm (ATT _ _ i_aFM i _) = find i i_aFM

getShATerm :: Int -> ATermTable -> ShATerm
getShATerm i (ATT _ _ i_aFM _ _) = find i i_aFM

getTopIndex :: ATermTable -> Int
getTopIndex (ATT _ _ _ i _) = i

getATermIndex :: ShATerm -> ATermTable -> Int
getATermIndex t (ATT _ a_iDFM _ _ _) = Map.findWithDefault (-1) t a_iDFM

getATermByIndex1 :: Int -> ATermTable -> ATermTable
getATermByIndex1 i (ATT h a_iDFM i_aDFM _ dM) = ATT h a_iDFM i_aDFM i dM

getATerm' :: Int -> String -> ATermTable -> Maybe Dynamic
getATerm' i str (ATT _ _ _ _ dM) = Map.lookup (i, str) dM

setATerm' :: Int -> String -> Dynamic -> ATermTable -> ATermTable
setATerm' i str d (ATT h a_iDFM i_aDFM m dM) =
    ATT h a_iDFM i_aDFM m $ Map.insert (i, str) d dM

-- | conversion of a string in double quotes to a character
str2Char :: String -> Char
str2Char ('\"' : sr) = conv' (init sr) where
                               conv' [x] = x
                               conv' ['\\', x] = case x of
                                   'n'  -> '\n'
                                   't'  -> '\t'
                                   'r'  -> '\r'
                                   '\"' -> '\"'
                                   _    -> error "strToChar"
                               conv' _ = error "String not convertible to char"
str2Char _         = error "String doesn't begin with '\"'"

-- | conversion of an unlimited integer to a machine int
integer2Int :: Integer -> Int
integer2Int x = if toInteger ((fromInteger :: Integer -> Int) x) == x
                  then fromInteger x
                  else error $ "Integer to big for Int: " ++ show x
