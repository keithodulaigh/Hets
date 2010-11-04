{-# LANGUAGE FlexibleInstances, FlexibleContexts #-}
{- |
Module      :  $Header$
Description :  Test environment for CSL
Copyright   :  (c) Ewaryst Schulz, DFKI Bremen 2010
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Ewaryst.Schulz@dfki.de
Stability   :  experimental
Portability :  non-portable (uses type-expression in type contexts)

This file is for experimenting with the Interpreter instances
and general static analysis tools
-}

module CSL.InteractiveTests where

import CSL.MapleInterpreter 

import CSL.ReduceInterpreter
import CSL.Reduce_Interface
import CSL.Interpreter
import CSL.Transformation
import CSL.EPBasic
import CSL.TreePO (EPCompare)
import CSL.EPRelation -- (compareEP, EPExp, toEPExp, compareEPs, EPExps, toEPExps, forestFromEPs, makeEPLeaf, showEPForest)
import CSL.Logic_CSL
import CSL.AS_BASIC_CSL
import CSL.Parse_AS_Basic (parseResult, extparam, pComma, pSemi)
import CSL.Sign

import Common.Utils (getEnvDef)
import Common.IOS
import Common.Result (diags, printDiags, resultToMaybe)
import Common.ResultT
import Common.Lexer as Lexer
import Common.Parsec
import Common.AS_Annotation
import Text.ParserCombinators.Parsec

-- the process communication interface
import qualified Interfaces.Process as PC

-- README: In order to work correctly link the Test.hs in the Hets-root dir to Main.hs (ln -s Test.hs Main.hs)
import Main (getSigSens)

import Control.Monad.State (StateT(..))
import Control.Monad.Trans (MonadIO (..))
import Control.Monad (liftM)
import Data.Maybe (fromJust, fromMaybe)
import Data.Time.Clock
import qualified Data.Map as Map

-- ----------------------------------------------------------------------
-- * general test functions
-- ----------------------------------------------------------------------

testspecs =
    [ (44, ("/CSL/EN1591.het", "EN1591"))
    ]

l1 :: Int -> IO (Sign, [Named CMD])
l1 i = do
  let (lb, sp) = fromMaybe ("/CSL/Tests.het", "Test" ++ show i)
                 $ Prelude.lookup i testspecs
  hlib <- getEnvDef "HETS_LIB" $ error "Missing HETS_LIB environment variable"
  getSigSens CSL (hlib ++ lb) sp

sig :: Int -> IO Sign
sig = fmap fst . l1

-- Check if the order is broken or not!
sens :: Int -> IO [Named CMD]
sens = fmap snd . l1

cmds :: Int -> IO [CMD]
cmds = fmap (map sentence) . sens

-- time measurement, pendant of the time shell command
time :: MonadIO m => m a -> m a
time p = do
  t <- liftIO getCurrentTime
  res <- p
  t' <- liftIO getCurrentTime
  liftIO $ putStrLn $ show $ diffUTCTime t' t
  return res


{-
show guarded assignments:

:m +CSL.Analysis
sl <- sens 3
fst $ splitAS s
-}

-- ----------------------------------------------------------------------
-- * calculator test functions
-- ----------------------------------------------------------------------

runTest :: ResultT (IOS b) a -> b -> IO a
runTest cmd r = fmap fromJust $ runTestM cmd r

runTestM :: ResultT (IOS b) a -> b -> IO (Maybe a)
runTestM cmd r = fmap (resultToMaybe . fst) $ runIOS r $ runResultT cmd

runTest_ :: ResultT (IOS b) a -> b -> IO (a, b)
runTest_ cmd r = do
  (res, r') <- runIOS r $ runResultT cmd
  return (fromJust $ resultToMaybe res, r')


evalL :: CalculationSystem (ResultT (IOS b)) => b
      -> Int -- ^ Test-spec
      -> IO b
evalL s i = do
  cl <- cmds i
  (_, s') <- runIOS s (runResultT $ evaluateList cl)
  return s'


-- ----------------------------------------------------------------------
-- * different parser
-- ----------------------------------------------------------------------

toE :: String -> EXPRESSION
toE = fromJust . parseResult

-- parses a single extparam range such as: "I>0, J=1"
toEP :: String -> [EXTPARAM]
toEP [] = []
toEP s = case runParser (Lexer.separatedBy extparam pComma >-> fst) "" "" s of
             Left e -> error $ show e
             Right s' -> s'


-- parses lists of extparam ranges such as: "I>0, J=1; ....; I=10, J=1"
toEPL :: String -> [[EXTPARAM]]
toEPL [] = []
toEPL s = case runParser
             (Lexer.separatedBy
              (Lexer.separatedBy extparam pComma >-> fst) pSemi >-> fst) "" "" s of
              Left e -> error $ show e
              Right s' -> s'

toEP1 :: String -> EPExp
toEP1 s = case runParser extparam "" "" s of
             Left e -> error $ show e
             Right s' -> snd $ fromJust $ toEPExp s'

toEPs :: String -> EPExps
toEPs = toEPExps . toEP

toEPLs :: String -> [EPExps]
toEPLs = map toEPExps . toEPL

-- ----------------------------------------------------------------------
-- * Extended Parameter tests
-- ----------------------------------------------------------------------

{-
smtEQScript vMap (epList!!0) (epList!!1)
test for smt-export
let m = varMapFromList ["I", "J", "K"]
let be = boolExps m $ toEPs "I=0"
smtBoolExp be

compare-check for yices
let l3 = [(x,y) | x <- epList, y <- epList]
let l2 = map (uncurry $ smtCompare vMap) l3
putStrLn $ unlines $ map show $ zip l2 l3
-}

epList :: [EPRange]
epList =
    let l = map (Atom . toEPs)
            ["I=1,J=0", "I=0,J=0", "I=0", "I=1", "J=0", "I>0", "I>2", "I>0,J>2"]
    in foldl Intersection (head l) (tail l) : foldl Union (head l) (tail l) : l
         

vMap :: Map.Map String Int
vMap = varMapFromSet $ namesInList epList


printOrdEPs :: String -> IO ()
printOrdEPs s = let ft = forestFromEPs (flip makeEPLeaf ()) $ toEPLs s
                in putStrLn $ showEPForest show ft
--forestFromEPs :: (a -> EPTree b) -> [a] -> EPForest b


compareEPgen :: Show a => (String -> a) -> (a -> a -> EPCompare) -> String -> String -> IO EPCompare
compareEPgen p c a b =
    let epA = p a
        epB = p b
    in do
      putStrLn $ show epA
      putStrLn $ show epB
      return $ c epA epB

compareEP' = compareEPgen toEP1 compareEP
compareEPs' = compareEPgen toEPs compareEPs

-- ----------------------------------------------------------------------
-- * MAPLE INTERPRETER
-- ----------------------------------------------------------------------

-- just call the methods in MapleInterpreter: mapleInit, mapleExit, mapleDirect
-- , the CS-interface functions and evalL



-- ----------------------------------------------------------------------
-- * FIRST REDUCE INTERPRETER
-- ----------------------------------------------------------------------



-- first reduce interpreter
reds :: Int -- ^ Test-spec
    -> IO ReduceInterpreter
reds i = do
  r <- redsInit
  sendToReduce r "on rounded; precision 30;"
  evalL r i



-- use "redsExit r" to disconnect where "r <- red"

{- 
-- many instances (connection/disconnection tests)

l <- mapM (const reds 1) [1..20]
mapM redsExit l


-- BA-test:
(l, r) <- redsBA 2

'l' is a list of response values for each sentence in spec Test2
'r' is the reduce connection
-}


-- ----------------------------------------------------------------------
-- * SECOND REDUCE INTERPRETER
-- ----------------------------------------------------------------------

-- run the assignments from the spec
redc :: Int -- ^ verbosity level
     -> Int -- ^ Test-spec
     -> IO RITrans
redc v i = do
  r <- redcInit v
  evalL r i

redcNames :: RITrans -> IO [String]
redcNames = runTest $ liftM toList names

redcValues :: RITrans -> IO [(String, EXPRESSION)]
redcValues = runTest values

-- run the assignments from the spec
redcCont :: Int -- ^ Test-spec
         -> RITrans
         -> IO RITrans
redcCont i r = do
  cl <- cmds i
  (res, r') <- runIOS r (runResultT $ evaluateList cl)
  printDiags (PC.verbosity $ getRI r') (diags res)
  return r'


--- Testing with many instances
{-
-- c-variant
lc <- time $ mapM (const $ redc 1 1) [1..20]
mapM redcExit lc

-- to communicate directly with reduce use:

let r = head lc   OR    r <- redc x y

let ri = getRI r

redcDirect ri "some command;"

-}




-- ----------------------------------------------------------------------
-- * TRANSFORMATION TESTS
-- ----------------------------------------------------------------------

data WithAB a b c = WithAB a b c

instance Show c => Show (WithAB a b c) where
    show (WithAB _ _ c) = show c

getA (WithAB a _ _) = a
getB (WithAB _ b _) = b
getC (WithAB _ _ c) = c

-- tt = transformation tests (normally Calculationsystem monad result)

-- tte = tt with evaluation (normally gets a cs-state and has IO-result)

runTT c s vcc = do
  (res, s') <- runIOS s $ runResultT $ runStateT c vcc
  let (r, vcc') = fromJust $ resultToMaybe res
  return $ WithAB vcc' s' r

runTTi c s = do
  (res, s') <- runIOS s (runResultT $ runStateT c emptyVCCache)
  let (r, vcc') = fromJust $ resultToMaybe res
  return $ WithAB vcc' s' r

--s -> t -> t1 -> IO (Common.Result.Result a, s)
-- ttesd :: ( VarGen (ResultT (IOS s))
--          , VariableContainer a VarRange
--          , CalculationSystem (ResultT (IOS s))
--          , Cache (ResultT (IOS s)) a String EXPRESSION) =>
--         EXPRESSION -> s -> a -> IO (WithAB a s EXPRESSION)
ttesd e = runTT (substituteDefined e)

ttesdi e = runTTi (substituteDefined e)

-- -- substituteDefined with init
--ttesdi s e = ttesd s vc e

{-
r <- mapleInit 1
r <- redcInit 3
r' <- evalL r 3
let e = toE "sin(x) + 2*cos(y) + x^2"
w <- ttesdi e r'
let vss = getA w

-- show value for const x
runTest (CSL.Interpreter.lookup "x") r' >>= return . pretty

runTest (CSL.Interpreter.eval $ toE "cos(x-x)") r' >>= return . pretty

w' <- ttesd e r' vss
w' <- ttesd e r' vss

mapleExit r


y <- fmap fromJust $ runTest (CSL.Interpreter.lookup "y") r'
runTest (verificationCondition y $ toE "cos(x)") r'
pretty it

r <- mapleInit 4
r <- redcInit 4
r' <- evalL r 301
let t = toE "cos(z)^2 + cos(z ^2) + sin(y) + sin(z)^2"
t' <- runTest (eval t) r'
vc <- runTest (verificationCondition t' t) r'
pretty vc
-}

{-
-- exampleRun
r <- mapleInit 4
let t = toE "factor(x^5-15*x^4+85*x^3-225*x^2+274*x-120)"
t' <- runTest (eval t) r
vc <- runTest (verificationCondition t' t) r
pretty vc


-- exampleRun2

r <- mapleInit 4
r' <- evalL r 1011
let t = toE "factor(x^5-z4*x^4+z3*x^3-z2*x^2+z1*x-z0)"
t' <- runTest (eval t) r'
vc <- runTest (verificationCondition t' t) r'
pretty vc

let l = ["z4+z3+20", "z2 + 3*z4 + 4", "3 * z3 - 30", "5 * z4 + 10", "15"]
let tl = map toE l
tl' <- mapM (\x -> runTest (eval x) r') tl
vcl <- mapM (\ (x, y) -> runTest (verificationCondition x y) r') $ zip tl' tl
mapM_ putStrLn $ map pretty vcl
-}

-- ----------------------------------------------------------------------
-- * Utilities
-- ----------------------------------------------------------------------

-- ----------------------------------------------------------------------
-- ** Operator extraction
-- ----------------------------------------------------------------------

addOp :: Map.Map String Int -> String -> Map.Map String Int
addOp mp s = Map.insertWith (+) s 1 mp

class OpExtractor a where
    extr :: Map.Map String Int -> a -> Map.Map String Int

instance OpExtractor EXPRESSION where
    extr m (Op op _ l _) = extr (addOp m $ show op) l
    extr m (Interval _ _ _) = addOp m "!Interval"
    extr m (Int _ _) = addOp m "!Int"
    extr m (Double _ _) = addOp m "!Double"
    extr m (List l _) = extr (addOp m "!List") l
    extr m (Var _) = addOp m "!Var"

instance OpExtractor [EXPRESSION] where
    extr = foldl extr

instance OpExtractor (EXPRESSION, [CMD]) where
    extr m (e,l) = extr (extr m e) l

instance OpExtractor CMD where
    extr m (Ass c def) = extr m [c, def]
    extr m (Cmd _ l) = extr m l
    extr m (Sequence l) = extr m l
    extr m (Cond l) = foldl extr m l
    extr m (Repeat e l) = extr m (e,l)

instance OpExtractor [CMD] where
    extr = foldl extr

extractOps :: OpExtractor a => a -> Map.Map String Int
extractOps = extr Map.empty

-- -- ----------------------------------------------------------------------
-- -- ** Assignment extraction
-- -- ----------------------------------------------------------------------

-- addOp :: Map.Map String Int -> String -> Map.Map String Int
-- addOp mp s = Map.insertWith (+) s 1 mp

-- class OpExtractor a where
--     extr :: Map.Map String Int -> a -> Map.Map String Int

-- instance OpExtractor EXPRESSION where
--     extr m (Op op _ l _) = extr (addOp m op) l
--     extr m (Interval _ _ _) = addOp m "!Interval"
--     extr m (Int _ _) = addOp m "!Int"
--     extr m (Double _ _) = addOp m "!Double"
--     extr m (List l _) = extr (addOp m "!List") l
--     extr m (Var _) = addOp m "!Var"

-- instance OpExtractor [EXPRESSION] where
--     extr = foldl extr

-- instance OpExtractor (EXPRESSION, [CMD]) where
--     extr m (e,l) = extr (extr m e) l

-- instance OpExtractor CMD where
--     extr m (Cmd _ l) = extr m l
--     extr m (Sequence l) = extr m l
--     extr m (Cond l) = foldl extr m l
--     extr m (Repeat e l) = extr m (e,l)

-- instance OpExtractor [CMD] where
--     extr = foldl extr

-- extractOps :: OpExtractor a => a -> Map.Map String Int
-- extractOps = extr Map.empty

-- -- ----------------------------------------------------------------------
-- -- * static analysis functions
-- -- ----------------------------------------------------------------------
