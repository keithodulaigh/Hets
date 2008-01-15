-- NOTE: use GHC flag -fcontext-stack45 with this module
---------------------------------------------------------------------------
-- Generated by DB/Direct
---------------------------------------------------------------------------
module Search.DB.FormulaDB.Inclusion where

import Database.HaskellDB.DBLayout

---------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------
inclusion :: Table
    ((RecCons Source (Expr String)
      (RecCons Target (Expr String)
       (RecCons Line_assoc (Expr String)
        (RecCons Morphism (Expr String)
         (RecCons Morphism_size (Expr Int) RecNil))))))

inclusion = baseTable "inclusion" $
            hdbMakeEntry Source #
            hdbMakeEntry Target #
            hdbMakeEntry Line_assoc #
            hdbMakeEntry Morphism #
            hdbMakeEntry Morphism_size

---------------------------------------------------------------------------
-- Fields
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Source Field
---------------------------------------------------------------------------

data Source = Source

instance FieldTag Source where fieldName _ = "source"

source :: Attr Source String
source = mkAttr Source

---------------------------------------------------------------------------
-- Target Field
---------------------------------------------------------------------------

data Target = Target

instance FieldTag Target where fieldName _ = "target"

target :: Attr Target String
target = mkAttr Target

---------------------------------------------------------------------------
-- Line_assoc Field
---------------------------------------------------------------------------

data Line_assoc = Line_assoc

instance FieldTag Line_assoc where fieldName _ = "line_assoc"

line_assoc :: Attr Line_assoc String
line_assoc = mkAttr Line_assoc

---------------------------------------------------------------------------
-- Morphism Field
---------------------------------------------------------------------------

data Morphism = Morphism

instance FieldTag Morphism where fieldName _ = "morphism"

morphism :: Attr Morphism String
morphism = mkAttr Morphism

---------------------------------------------------------------------------
-- Morphism_size Field
---------------------------------------------------------------------------

data Morphism_size = Morphism_size

instance FieldTag Morphism_size where
    fieldName _ = "morphism_size"

morphism_size :: Attr Morphism_size Int
morphism_size = mkAttr Morphism_size
