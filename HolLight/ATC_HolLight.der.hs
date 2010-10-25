{-# OPTIONS -w -O0 #-}
{- |
Module      :  HolLight/ATC_HolLight.der.hs
Description :  generated Typeable, ShATermConvertible instances
Copyright   :  (c) DFKI Bremen 2008
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(overlapping Typeable instances)

Automatic derivation of instances via DrIFT-rule Typeable, ShATermConvertible
  for the type(s):
'HolLight.Sign.Sign'
'HolLight.Sentence.Sentence'
-}

{-
  Generated by 'genRules' (automatic rule generation for DrIFT). Don't touch!!
  dependency files:
HolLight/Sign.hs
HolLight/Sentence.hs
-}

module HolLight.ATC_HolLight () where

import ATC.AS_Annotation
import ATerm.Lib
import Data.Set
import Data.Typeable
import HolLight.Sentence
import HolLight.Sign

{-! for HolLight.Sign.Sign derive : Typeable !-}
{-! for HolLight.Sentence.Sentence derive : Typeable !-}

{-! for HolLight.Sign.Sign derive : ShATermConvertible !-}
{-! for HolLight.Sentence.Sentence derive : ShATermConvertible !-}