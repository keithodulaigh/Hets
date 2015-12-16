{-# LANGUAGE DeriveDataTypeable #-}
{-
Abstract syntax for Events
-}

module EVT.AS
        ( EVTQualId (..)
        , Sentence
                , ACTION (..)
                , GUARD (..)
                , EVENT (..)
                , MACHINE (..)
                , EVENT_NAME
                --, mapQualId
        --, getSignature
        ) where

import Data.Data

import Common.Id
import CASL.AS_Basic_CASL
import CASL.ATC_CASL () 

-- DrIFT command
{-! global: GetRange !-}
type GUARD_NAME = Id
type ACTION_NAME = Id
type EVENT_NAME = Id

-- | Machines are sets of events. 
data MACHINE = MACHINE [EVENT] --Range
                 deriving (Show, Eq, Ord, Typeable, Data)

data EVENT = EVENT
                     {   name :: EVENT_NAME                                
                       , guards :: [GUARD]
                       , actions :: [ACTION]
                     }
                     deriving (Show, Eq, Ord, Typeable, Data)

data GUARD = GUARD
                     {
                        gnum :: GUARD_NAME
                      , predicate :: (FORMULA ())
                     }
                     deriving (Show, Eq, Ord, Typeable, Data)

data ACTION = ACTION
                     {
                        anum :: ACTION_NAME
                      , statement :: (FORMULA ())
                     }                                
                     deriving (Show, Eq, Ord, Typeable, Data)

data EVTQualId = EVTQualId
                {
                  eventid :: Id 
                }
                deriving (Eq, Ord, Show, Typeable, Data)

-- Sentences are machines
type Sentence = EVENT


{-
map_qualId :: EVTMorphism -> EVTQualId -> Result EVTQualId
map_qualId mor qid =
    let
        (eid, rid, rn) = case qid of
            EVTQualId i1 i2 rn1 -> (i1, i2, rn1)
            return $ EVTQualId mtid mrid rn
-}

{- ^ oo-style getter function for signatures
getSignature :: RSScheme -> EVTEvents
getSignature spec = case spec of
            RSScheme tb _ _ -> tb-} 