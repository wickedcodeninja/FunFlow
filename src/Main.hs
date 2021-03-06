-- (C) 2013 Pepijn Kokke & Wout Elsinghorst
-- (C) 2014 Wout Elsinghorst

module Main
  ( module FUN.Base
  , module FUN.Parsing
  , module FUN.Analyses
  , main
  ) where

import FUN.Base      -- ^ Abstract syntax tree
import FUN.Parsing   -- ^ Parser
import FUN.Labeling  -- ^ Labeling
import FUN.Analyses 
  ( checkProgram
  , printProgram
  , PrintAnnotations (..), Annotations (..), setAnnotations
  , Constraint
  , TVar, TypeScheme
  , extractFlowConstraints
  , extractScaleConstraints
  , extractBaseConstraints
  )
import FUN.Analyses.Flow
  ( printFlowInformation 
  )
import FUN.Analyses.Measure
  ( printScaleInformation 
  , printBaseInformation 
  )

import Data.Set (Set)
import Data.Map (Map)
  
import qualified Data.Set as S
  
-- |Runs the analysis on the example program code (down below) and prints an 
--  annotated version to stdout. Things between curly braces { } denote unresolved 
--  variables while stuff between brackets [ ] denotes concrete information.
--  

main :: IO ()
main = 
  let annotations = setAnnotations [ MeasureInformation       -- ^Set which annotations to print. Leave
                                   ] {-
                                   , ProgramPoints            --  empty to just print the W-inferred 
                                   , FlowInformation          --  types.       
                                   ] -}
        
      showResult :: (Map TVar TypeScheme, Program, Set Constraint) -> String
      showResult (m, p, w) =  let printUnresolved printer extracter s =
                                    let cs = extracter w
                                    in if not (S.null cs)
                                       then s ++ "unresolved " ++ s ++ " constraints = " ++ printer cs ++ "\n\n"
                                       else ""
                                    
                                  programInfo = "program = " ++ printProgram annotations p m
                                  flowInfo  = printUnresolved printFlowInformation  extractFlowConstraints  "flow"
                                  scaleInfo = printUnresolved printScaleInformation extractScaleConstraints "scale"
                                  baseInfo  = printUnresolved printBaseInformation  extractBaseConstraints  "base"
                                  
                              in programInfo
                              ++ flowInfo
                              ++ scaleInfo
                              ++ baseInfo
  in either print (putStrLn . showResult) . checkProgram $ example

-- * Example code
  
example = Prog $ case 1 of
                   0 -> exLetGen        -- ^ Let is generalized
                   1 -> exMeasure       -- ^ Main program showing our 'units of measure' capabilities
                   2 -> exEverything    -- ^ A whole bunch of random snippets, showing our language and program point tracking
                   3 -> exLoop True     -- ^ Loop program from the book, unfolded to show non-toplevel statements
                   4 -> exLoop False    -- ^ Loop program from the book, in original presentation. Only the toplevel 
                                        -- ^   type is displayed, so intermediate results cannot be checked
                   5 -> exKnor          -- ^ Still no subeffecting :(
                   6 -> exBad           -- ^ Not bad anymore!
                   
exLetGen = fmap parseDecl $ 
  [ "f x y = let r a = a; Pair (r x, s y)"          
  , "g x y = f (f x y) (f y x)"
  ]

exBad = fmap parseDecl $
  [ "test f x = let p = f in p x "
  ]
  
exKnor = fmap parseDecl $
  [ "f x = x"
  , "g y = y"
  , "knor = if true then f else g"
  ]

exMeasure = fmap parseDecl $
  [ "s1 = asMeters 3"
  , "t1 = asSeconds 5"
  , "v1 = s1 / t1"

  , "s2 = asMeters 7"
  , "t2 = asSeconds 11"
  , "t3 = t2"
  , "v2 = s2 / t2"
  
  , "combinedSpeed = v1 + v2"
  , "averageSpeed  = combinedSpeed / 2"
  
  , "t3 = asSeconds 13"
  , "s3 = combinedSpeed * t3"
  
  , "r1 = v1 * t1"
  , "r2 = t1 * v1"
  , "t = r1 + r2"
  , "s = r1 / r2"
  
  , "calc s t = (s / t) * (asMeters 5) / (asSeconds 3)"
  
  , "ret s = Pair (Pair (s, (asMeters 2) * s), (asSeconds 3) * s)"
  ]

exLoop unfolded = fmap parseDecl $
  if unfolded then
  [ "fy = fun y => y"
  , "g = fix f x => f fy"
  , "fz = fun z => z"
  , "test = g fz"
  ] else
  [ "loop = let g = fix f x => f (fun y => y) in g (fun z => z)"
  ]
   
exEverything = concat $
  [ exCategory
  , exPair
  , exCurry 
  , exMap
  , exId
  , exFunction
  , exLoop True
  , exSilly
  , exPairimental
  , exSum
  ]
   
   
exCategory = fmap parseDecl $
  [ "compose f g x = f (g x)"
  , "id x = x"
  ]
  
exPair = fmap parseDecl $
  [ "pair x y = Pair (x,y)"
  , "fst p = case p of Pair(x,y) -> x"
  , "snd p = case p of Pair(x,y) -> y"
  , "swap p = case p of Pair (x, y) -> Pair (y, x)"
  ]

exMap = fmap parseDecl $
  [ "mapFst f p = case p of Pair (x, y) -> Pair (f x, y)"
  , "mapSnd g p = case p of Pair (x, y) -> Pair (x, g y)"
  , "mapPair f g = compose (mapFst f) (mapSnd g)"
  ]
  
exCurry = fmap parseDecl $
  [ "curry f   = fun x y => let p = Pair (x, y) in f p"
  , "uncurry f = fun p => case p of Pair (x, y) -> f x y"
  ]
  
  
exId = fmap parseDecl $
  [ "idPair p = Pair(fst p, snd p)" 
  , "idCurry1 = compose curry uncurry" 
  , "idCurry2 = compose uncurry curry"
  ]
  
exFunction = fmap parseDecl $
  [ "apply f x = f x"
  
  , "const x y = x"

  , "ap w = fun f a => case f of Pair (r, g) -> case a of Pair (s, x) -> Pair (w r s, g x)"
  , "bind w = fun f a => case a of Pair (x, v) -> case f v of Pair (y, b) -> Pair (w x y, b)" 
  ]

exSilly = fmap parseDecl $
  [ "silly1 p = case p of Pair(f,g) -> compose f g"
  , "silly2 p = compose (fst p) (snd p)"
  , "silly3 p x = apply (compose (fst p) (snd p)) (id x)"
  ]
  
exPairimental = fmap parseDecl $
  [ "pA = Pair (3, 5)"
  , "pB = Pair (7, 11)"
  , "f p = case p of Pair (x, y) -> x" 
  ]
  
exSum = fmap parseDecl $
  [ "sumL = Either.Left 5"
  , "sumR = Either.Right false"
  , "sumLR = if false then sumL else sumR"
  , "sumLL = if false then sumL else sumL"
  , "sumRR = if false then sumR else sumR"
  , "killSumLR p = case p of Either.Left x -> x"
 ++ "                        Either.Right y -> y"
  , "killSumL p = case p of Either.Left x -> false"
 ++ "                       Either.Right y -> y"
  , "killSumR p = case p of Either.Left x -> x"
 ++ "                       Either.Right y -> false"
  ]

                   