{- |
Module      :$Header$
Description : The definition of CMDL interface for 
              standard input and file input
Copyright   : uni-bremen and DFKI
Licence     : similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  : r.pascanu@jacobs-university.de
Stability   : provisional
Portability : portable

PGIP.CMDLStdin describes the interface specific function
for standard input and file input
-} 

module PGIP.Interface where


import System.Console.Shell
import System.Console.Shell.Backend
import System.Console.Shell.Backend.Readline

import System.IO

import PGIP.CMDLShell
import PGIP.CMDLState
import PGIP.DgCommands
import PGIP.InfoCommands
import PGIP.ProveCommands
import PGIP.UndoRedo

import qualified Control.Exception as Ex

-- | Generates the list of all the shell commands toghether
-- with a short description
cmdlCommands :: [ShellCommand CMDLState]
cmdlCommands
   -- different names for exit commands
 = (exitCommand "exit")
 : (exitCommand "quit")
   -- also vi style 
 : (exitCommand ":q")
   -- different name for help commands
  : (cmd "details" shellDetails
   "view details about the gramma of this interactive mode")
 : (helpCommand "help")
   -- also ? for help
 : (helpCommand "?")
   -- dgCommands
 : (cmd "use" shellDgUse "load a HetCATS library")
 : (cmd "dg auto" shellDgAuto
   "apply automatic tactic to a list of goals")
 : (cmd "dg glob-subsume" shellDgGlobSubsume
   "apply global subsumption to a list of goals")
 : (cmd "dg glob-decomp" shellDgGlobDecomp
   "apply global decomposition to a list of goals")
 : (cmd "dg loc-infer" shellDgLocInfer
   "apply local inference to a list of goals")
 : (cmd "dg loc-decomp" shellDgLocDecomp
   "apply local decomposition to a list of goals")
 : (cmd "dg comp" shellDgComp
   "apply composition to a list of goals")
 : (cmd "dg comp-new" shellDgCompNew
   "apply composition with speculation of new edges ")
 : (cmd "dg hide-thm" shellDgHideThm
   "apply hide theorem shift to a list of goals")
 : (cmd "dg thm-hide" shellDgThmHideShift
   "apply theorem hide shift to a list of goals")
   -- select nodes
 : (cmd "select" shellDgSelect
   "select a list of goals for proving")
 : (cmd "dg basic" shellDgSelect
   "select a list of goals for proving")
   -- dgAllCommands 
 : (cmd "dg-all auto" shellDgAllAuto
   "apply automatic tactic to all goals")
 : (cmd "dg-all glob-subsume" shellDgAllGlobSubsume
   "apply global subsumption to all goals")
 : (cmd "dg-all glob-decomp" shellDgAllGlobDecomp
   "apply global decomposition to all goals")
 : (cmd "dg-all loc-infer" shellDgAllLocInfer
   "apply local inference to all goals")
 : (cmd "dg-all loc-decomp" shellDgAllLocDecomp
   "apply local decomposition to all goals")
 : (cmd "dg-all comp" shellDgAllComp
   "apply composition to all goals")
 : (cmd "dg-all comp-new" shellDgAllCompNew
   "apply composition with speculation of new edges ")
 : (cmd "dg-all hide-thm" shellDgAllHideThm
   "apply hide theorem shift to all goals")
 : (cmd "dg-all thm-hide" shellDgAllThmHide
   "apply theorem hide shift to all goals")
   -- select all nodes
 : (cmd "select-all" shellDgSelectAll
   "select all goals for proving")
 : (cmd "dg-all basic" shellDgSelectAll
   "select all goals for proving")
   -- information commands 
 : (cmd "show-undo-history" shellShowUndoHistory
   "show history of executed commands")
 : (cmd "show-redo-history" shellShowRedoHistory
   "show commands that had been canceled")
 : (cmd "show-dg-goals" shellShowDgGoals
   "shows list of all open dg goals")
 : (cmd "show-theory-goals" shellShowTheoryGoals
   "shows list of theory goals")
 : (cmd "show-theory-goals-current" shellShowTheoryGoalsCurrent
   "shows theory of goals from the selected nodes")
 : (cmd "show-proven-goals" shellShowNodePGoals
   "shows names of the proven goals ")
 : (cmd "show-proven-goals-current" shellShowNodePGoalsCurrent
   "shows names of the proven goals from selected nodes")
 : (cmd "show-unproven-goals" shellShowNodeUGoals
   "shows names of the unproven goals")
 : (cmd "show-unproven-goals-current" shellShowNodeUGoalsCurrent
   "shows names of the unproven goals from selected nodes")
 : (cmd "show-axioms" shellShowNodeAxioms
   "show names of axioms")
 : (cmd "show-axioms-current" shellShowNodeAxiomsCurrent
   "show names of axioms from selected nodes")
 : (cmd "show-theory-current" shellShowTheoryCurrent
   "shows current theory and proof goals")
 : (cmd "show-theory" shellShowTheory
   "shows theory of the provided node")
 : (cmd "info-current" shellInfoCurrent
   "shows info about current dg node or edge")
 : (cmd "info" shellInfo
   "shows info about the provided dg node")
 : (cmd "show-taxonomy-current" shellShowTaxonomyCurrent
   "shows taxonomy graph")
 : (cmd "show-taxonomy" shellShowTaxonomy
   "shows taxonomy graph of the provided nodes")
 : (cmd "show-concept-current" shellShowConceptCurrent
   "shows concept graph")
 : (cmd "show-concept" shellShowConcept
   "shows concept graph of the provided nodes")
 : (cmd "node-number" shellNodeNumber
   " view node number")
 : (cmd "nodes" shellNodes
   "show all nodes of the development graph")
 : (cmd "edges" shellEdges
   "show all edges of the development graph")
 : (cmd "show-graph" shellDisplayGraph
   "displays the current dg graph")
 : (cmd "#" shellComment
   "comments")
 : (cmd "%%" shellComment
   "comments")
 : (cmd "%{" shellMultiLineCommentOpen
   "open comments")
 : (cmd "}%" shellMultiLineCommentClose
   "close comments")
   -- prove mode commands
   -- comorphism related
 : (cmd "translate" shellTranslate
   "translate theory goals along comorphism")
   -- prover related
 : (cmd "prover" shellProver
   "selects a prover")
   -- proving related
 : (cmd "prove-all" shellProveAll
   "Applies a theorem prover")
 : (cmd "prove" shellProveAll
   "Applies a theorem prover to selected goals")
 : (cmd "set axioms" shellSelectAxms
   "Selects what axioms should be used")
 : (cmd "set goals" shellSelectGoals
   "Selects what goals needs to be proven")
 : (cmd "set-all axioms" shellSetAxmsAll
   "Selects all axioms")
 : (cmd "set-all goals" shellSetGoalsAll
   "Selects all goals")
 : (cmd "del axioms" shellUnselectAxms
   "Unselects the given axioms")
 : (cmd "del goals" shellUnselectGoals
   "Unselects the given goals")
 : (cmd "del-all axioms" shellUnselectAxmsAll
   "Unselects all axioms")
 : (cmd "del-all goals" shellUnselectGoalsAll
   "Unselects all goals")
 : (cmd "add axioms" shellAddAxms
   "Adds axioms to the current selections")
 : (cmd "add goals" shellAddGoals
   "Adds goals to the current selections")
 : (cmd "begin-script" shellBeginScript
   "Prepares the interface for reading a script")
 : (cmd "end-script" shellEndScript  
    " Close the block of rules and runs either prove or prove-all")
 : (cmd "set include-theorems true"  shellUseThms
   "Include previous proved theorems")
 : (cmd "set include-theorems false" shellDontUseThms
   "Do not include previous proved theorems")
 : (cmd "set save-prove-to-file true" shellSave2File
   "Saves the proofs for each goal to a file")
 : (cmd "set save-prove-to-file false" shellDontSave2File
   "Do not save the proofs into files")
  : (cmd "set time-limit" shellTimeLimit
   "Time limit for the prover to run before abortion") 
  : (cmd "undo" shellUndo
   "Undo last action")
  : (cmd "redo" shellRedo
   "Redo last undone action")
  : []



-- | Creates the Backend for reading from files
fileBackend :: String -> ShellBackend Handle
fileBackend filename = ShBackend
  { initBackend = openFile filename ReadMode
  , shutdownBackend = hClose
  , outputString = \_ -> basicOutput
  , flushOutput = \_ -> hFlush stdout
  , getSingleChar = fileGetSingleChar
  , getInput = fileGetInput
  , addHistory = \_ _ -> return ()
  , setWordBreakChars = \_ _ -> return ()
  , getWordBreakChars = \_ -> return
                      " \t\n\r\v`~!@#$%^&*()=[]{};\\\'\",<>"
  , onCancel = \_ -> hPutStrLn stdout "canceled...\n"
  , setAttemptedCompletionFunction = \_ _ -> return ()
  , setDefaultCompletionFunction = \_ _ -> return ()
  , completeFilename = \_ _ -> return []
  , completeUsername = \_ _ -> return []
  , clearHistoryState = \_ -> return ()
  , getMaxHistoryEntries = \_ -> return 0
  , setMaxHistoryEntries = \_ _ -> return ()
  , readHistory = \_ _ -> return ()
  , writeHistory = \_ _ -> return ()
  }

-- | Used to get one char from a file open for reading
fileGetSingleChar :: Handle -> String -> IO (Maybe Char)
fileGetSingleChar file _ 
 = do
    Ex.bracket (hGetBuffering file) (hSetBuffering file) $ 
         \_ -> do
                hSetBuffering file NoBuffering
                c <- hGetChar file
                hPutStrLn stdout ""
                return (Just c)

-- | Used to get a line from a file open for reading
fileGetInput :: Handle -> String -> IO (Maybe String)
fileGetInput file _ = do
   x <- hGetLine file
   return (Just x)

basicOutput :: BackendOutput -> IO ()
basicOutput (RegularOutput out) = hPutStr stdout out
basicOutput (InfoOutput out)    = hPutStr stdout out
basicOutput (ErrorOutput out)   = hPutStr stderr out


cmdlShellDescription :: ShellDescription CMDLState 
cmdlShellDescription =
 let wbc = "\n\r\v\\" in
      initialShellDescription
       { shellCommands      = cmdlCommands
       , commandStyle       = OnlyCommands
       , evaluateFunc       = cmdlEvalFunc
       , wordBreakChars     = wbc
       , prompt             = \x -> return (prompter x)
       , historyFile        = Just ("consoleHistory.tmp")
       }

cmdlFileShellDescription :: ShellDescription CMDLState
cmdlFileShellDescription =
 let wbc = "\t\n\r\v\\" in
      initialShellDescription
       { shellCommands      = cmdlCommands
       , commandStyle       = OnlyCommands
       , evaluateFunc       = cmdlEvalFunc
       , wordBreakChars     = wbc
       , prompt             = \_ -> return ""
       , historyFile        = Just ("consoleHistory.tmp")
       }


-- | Applies cUse to a list of input files
recursiveApplyUse::[String] -> CMDLState -> IO CMDLState
recursiveApplyUse ls state
 = case ls of
    []   -> return state
    l:ll -> do
             nwState <- cUse l state
             recursiveApplyUse ll nwState




-- | The function runs hets in a shell
cmdlRunShell :: [String] ->IO CMDLState
cmdlRunShell files
   = do
      state <- recursiveApplyUse  files emptyCMDLState 
      runShell cmdlShellDescription
                {defaultCompletions= Just cmdlCompletionFn }
              readlineBackend
              state

-- | The function processes the file of instruction
cmdlProcessFile :: String -> IO CMDLState
cmdlProcessFile filename =
        (runShell cmdlFileShellDescription
                 (fileBackend filename)
                 emptyCMDLState) `catch` 
                               (\_ -> return emptyCMDLState )


