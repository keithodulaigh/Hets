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
	, ACTION_NAME
	, GUARD_NAME
	--, mapQualId
        --, getSignature
        ) where

import Data.Data
import qualified Data.Map as Map
import Data.Set as Set

import Common.Id
import Common.AS_Annotation
import Common.Doc
import Common.DocUtils
import Common.Result

import EVT.Keywords
import CASL.AS_Basic_CASL

-- DrIFT command
{-! global: GetRange !-}
--CSPCOPY
type GUARD_NAME = Id

type ACTION_NAME = Id

type EVENT_NAME = Id

-- | Machines are sets of events. (they should be made of a data part and then an event part
data MACHINE = MACHINE EVENT Range
                 deriving (Show, Eq, Ord, Typeable, Data)

data EVENT = EVENT
	     {   name :: EVENT_NAME		
		, guards :: [GUARD]
		, actions :: [ACTION]
	     }
		deriving (Show, Eq, Ord, Typeable, Data)



data GUARD = GUARD 
	     {
		gname :: GUARD_NAME --[PRED_ITEM ()] 
	     }
		deriving (Eq, Ord, Show, Typeable, Data)

data ACTION = ACTION
	     {  aname ::ACTION_NAME --[TERM ()] 
	     }		
		deriving (Eq, Ord, Show, Typeable, Data)


--RELSCHEMECOPY
-- first Id is TableId, second is columnId --}
data EVTQualId = EVTQualId
                {
                  eventid :: Id
		}
                deriving (Eq, Ord, Show, Typeable, Data)

-- Sentences are machines
type Sentence = MACHINE


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
