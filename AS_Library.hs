{- HetCATS/AS_Library.hs
   $Id$
   Klaus Luettich

   These data structures describe the abstract syntax tree for heterogenous 
   libraries in HetCASL.

   todo:
-}

module AS_Library where

import Id
import AS_Annotation

import AS_Architecture
import AS_Structured
import Grothendieck


data LIB_DEFN = Lib_defn LIB_NAME [Annoted LIB_ITEM] [Pos] [Annotation]
	        -- pos: "library"
	        -- list of annotations is parsed preceding the first LIB_ITEM
	        -- the last LIB_ITEM may be annotated with a following comment
	        -- the first LIB_ITEM cannot be annotated
		deriving (Show,Eq)

{- for information on the list of Pos see the documentation in
   AS_Structured.hs and AS_Architecture.hs -}

data LIB_ITEM = Spec_defn SPEC_NAME GENERICITY (Annoted SPEC) [Pos]
	      
	      | View_defn VIEW_NAME GENERICITY VIEW_TYPE 
		          G_symb_map_items_list [Pos]

	      | Arch_spec_defn ARCH_SPEC_NAME (Annoted ARCH_SPEC) [Pos]

	      | Unit_spec_defn SPEC_NAME UNIT_SPEC [Pos]

	      | Download_items  LIB_NAME [ITEM_NAME_OR_MAP] [Pos] 
		-- pos: "from","get",commas, opt "end"
		deriving (Show,Eq)

data ITEM_NAME_OR_MAP = Item_name ITEM_NAME 
		      | Item_name_map ITEM_NAME ITEM_NAME [Pos]
			-- pos: "|->"
			deriving (Show,Eq)

type ITEM_NAME = SIMPLE_ID

data LIB_NAME = Lib_version LIB_ID VERSION_NUMBER
	      | Lib_id LIB_ID
		deriving (Show,Eq)

data LIB_ID = Direct_link URL [Pos]
	      -- pos: start of URL
	    | Indirect_link PATH [Pos]
	      -- pos: start of PATH
	      deriving (Show,Eq)

data VERSION_NUMBER = Version_number [String] [Pos]
		      -- pos: "version", start of first string
		      deriving (Show,Eq) 

type URL = String
type PATH = String

-- functions for casts
cast_S_L_Spec_defn :: SPEC_DEFN -> LIB_ITEM 
cast_L_S_Spec_defn :: LIB_ITEM  -> SPEC_DEFN

cast_S_L_Spec_defn (AS_Structured.Spec_defn x y z p) = 
    (AS_Library.Spec_defn x y z p) 

cast_L_S_Spec_defn (AS_Library.Spec_defn x y z p) =
    (AS_Structured.Spec_defn x y z p)

cast_S_L_View_defn :: VIEW_DEFN -> LIB_ITEM 
cast_L_S_View_defn :: LIB_ITEM  -> VIEW_DEFN

cast_S_L_View_defn (AS_Structured.View_defn w x y z p) = 
    (AS_Library.View_defn w x y z p) 

cast_L_S_View_defn (AS_Library.View_defn w x y z p) =
    (AS_Structured.View_defn w x y z p)

cast_A_L_Arch_spec_defn :: ARCH_SPEC_DEFN -> LIB_ITEM
cast_L_A_Arch_spec_defn :: LIB_ITEM       -> ARCH_SPEC_DEFN

cast_A_L_Arch_spec_defn (AS_Architecture.Arch_spec_defn x y p) =
    (AS_Library.Arch_spec_defn x y p)

cast_L_A_Arch_spec_defn (AS_Library.Arch_spec_defn x y p) =
    (AS_Architecture.Arch_spec_defn x y p)

cast_A_L_Unit_spec_defn :: UNIT_SPEC_DEFN -> LIB_ITEM
cast_L_A_Unit_spec_defn :: LIB_ITEM       -> UNIT_SPEC_DEFN

cast_A_L_Unit_spec_defn (AS_Architecture.Unit_spec_defn x y p) =
    (AS_Library.Unit_spec_defn x y p)

cast_L_A_Unit_spec_defn (AS_Library.Unit_spec_defn x y p) =
    (AS_Architecture.Unit_spec_defn x y p)

