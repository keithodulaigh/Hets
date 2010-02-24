{- |
Module      :  $Header$
Description :  The OMDoc Data Types
Copyright   :  (c) Ewaryst Schulz, DFKI 2008
License     :  similar to LGPL, see HetCATS/LICENSE.txt

Maintainer  :  Ewaryst.Schulz@dfki.de
Stability   :  provisional
Portability :  portable

Datatypes for an intermediate OMDoc Representation.
-}
module OMDoc.DataTypes where

import Common.Amalgamate

{-
  OMDoc represented in 3 layers:
  1. toplevel (theory, view)
  2. theory constitutive (axiom, symbol)
  3. subelements (morphism, insort, ...) and OpenMath
-}




-- | OMDoc root element with libname and a list of toplevel elements
data OMDoc = OMDoc String [TLElement]

-- | Toplevel elements for OMDoc, theory with name, meta and content,
-- view with from, to and morphism
data TLElement = TLTheory String (Maybe OMCD) [TCElement]
               | TLView String OMCD OMCD (Maybe TCElement)
                 deriving (Show, Eq, Ord)

-- | Theory constitutive elements for OMDoc
data TCElement =
    -- | Symbol to represent sorts, constants, predicate symbols, etc.
    TCSymbol String OMElement SymbolRole (Maybe OMElement)
    -- | An axiom or theorem element, depends on the proof entry.
    -- Even unproven theorems should contain a constant marking them as
    -- a theorem.
--  | TCAxiomOrTheorem (Maybe OMElement) String OMElement
    -- | Algebraic Data Type represents free/generated types
  | TCADT [OmdADT]
    -- | Import statements for referencing other theories
  | TCImport String OMCD (Maybe TCElement)
    -- | Morphisms to specify signature mappings
  | TCMorphism [(OMName, OMElement)]
    -- | A comment, only for development purposes
  | TCComment String
    deriving (Show, Eq, Ord)


-- | The flattened structure of an Algebraic Data Type
data OmdADT =
    -- | A single sort given by name, type and a list of constructors
    ADTSortDef String ADTType [OmdADT]
    -- | A constructor given by its name and a list of arguments
  | ADTConstr String [OmdADT]
    -- | An argument with type and evtually a selector
  | ADTArg OMElement (Maybe OmdADT)
    -- | The selector has a name and is total (Yes) or partial (No)
  | ADTSelector String Totality
    -- | Insort elements point to other sortdefs and inherit their structure
  | ADTInsort String
    deriving (Show, Eq, Ord)

-- | Roles of the declared symbols can be object or type
data SymbolRole = Obj | Typ | Axiom | Theorem deriving (Eq, Ord)

-- | Type of the algebraic data type
data ADTType = Free | Generated deriving (Eq, Ord)

-- | Totality for selectors of an adt
data Totality = Yes | No deriving (Eq, Ord)

instance Show SymbolRole where
    show Obj = "object"
    show Typ = "type"
    show Axiom = "axiom"
    show Theorem = "theorem"

instance Show ADTType where
    show Free = "free"
    show Generated = "generated"

instance Show Totality where
    show Yes = "yes"
    show No = "no"

instance Read SymbolRole where
    readsPrec  _ = readShowAux $ map ( \ o -> (show o, o))
                   [Obj, Typ, Axiom, Theorem]

instance Read ADTType where
    readsPrec  _ = readShowAux $ map ( \ o -> (show o, o))
                   [Free, Generated]

instance Read Totality where
    readsPrec  _ = readShowAux $ map ( \ o -> (show o, o))
                   [Yes, No]

-- | Names used for OpenMath variables and symbols
data OMName = OMName { name :: String,  path :: [String] }
              deriving (Show, Eq, Ord)

-- | Attribute-name/attribute-value pair used to represent the type
-- of a type-annotated term
data OMAttribute = OMAttr OMElement OMElement
                      deriving (Show, Eq, Ord)

-- | CD contains the reference to the content dictionary
-- and eventually the cdbase entry
data OMCD = CD { cd :: String,
                 cdbase :: (Maybe String)}
            deriving (Show, Eq, Ord)

-- | Elements for Open Math
data OMElement =
    -- | Symbol
    OMS OMCD OMName
    -- | Simple variable
  | OMV OMName
    -- | Attributed element needed for type annotations of elements
  | OMATTT OMElement OMAttribute
    -- | Application to a list of arguments,
    -- first argument is usually the functionhead
  | OMA [OMElement]
    -- | Bindersymbol, bound vars, body
  | OMBIND OMElement [OMElement] OMElement
  deriving (Show, Eq, Ord)


---------------------- Constructing Values ----------------------

mkSimpleName :: String -> OMName
mkSimpleName s = OMName s []
