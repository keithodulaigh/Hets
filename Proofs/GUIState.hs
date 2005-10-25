{- |
Module      :  $Header$
Description :  State data structure used by the goal management GUI.
Copyright   :  (c) Rene Wagner, Uni Bremen 2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  rwagner@tzi.de
Stability   :  provisional
Portability :  needs POSIX

The 'ProofGUIState' data structure abstracts the GUI implementation details
away by allowing callback function to use it as the sole input and output.

-}

module Proofs.GUIState where

import Static.DevGraph
import Comorphisms.KnownProvers

{- |
  Represents the global state of the prover GUI.
-}
data ProofGUIState = ProofGUIState { -- | theory name
                                     theoryName :: String,
				     -- | Grothendieck theory
				     theory :: G_theory,
				     -- | currently known provers
				     provers :: KnownProversMap,
                                     -- | currently selected goal or Nothing
                                     selectedGoals :: [String],
                                     -- | whether a prover is running or not
                                     proverRunning :: Bool,
                                     -- | which prover (if any) is currently selected
                                     selectedProver :: Maybe String
                                   }

{- |
  Creates an initial State.
-}
initialState :: String
             -> G_theory
	     -> KnownProversMap
             -> ProofGUIState
initialState thN th pm = 
  ProofGUIState { theoryName = thN,
		  theory = th,
		  provers = pm,
                  selectedGoals = [],
                  proverRunning = False,
                  selectedProver = Nothing
                }

