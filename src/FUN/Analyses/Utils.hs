-- (C) 2013 Pepijn Kokke & Wout Elsinghorst

{-# LANGUAGE FlexibleInstances, GADTs #-}
{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies #-}
module FUN.Analyses.Utils where

import Prelude hiding 
  ( foldr
  , foldl
  )

import Control.Applicative
import Data.Foldable

import Data.Map (Map)
import Data.Set (Set)

import qualified Data.Map as M
import qualified Data.Set as S

-- * Constraint Solving

class Solver c s | c -> s where
  solveConstraints :: s -> Set c -> (s, Set c)

  
-- * Substitutions

class Subst e w where
  subst :: e -> w -> w
 
substM :: (Subst e w, w ~ m a, Monad m) => e -> a -> w
substM e = subst e . return
 
  
instance (Subst e a) => Subst e [a] where
  subst m = map (subst m)

instance (Subst e a, Ord a) => Subst e (Set a) where
  subst m = S.map (subst m)

instance (Subst e a, Ord k) => Subst e (Map k a) where
  subst m = M.map (subst m)
  
-- * Singleton Constructors

class Singleton w k where
  singleton :: k -> w

instance Singleton (Map k a) (k, a) where
  singleton = uncurry M.singleton

instance Singleton (Set k) k where
  singleton = S.singleton  
  
-- * Utility Functions

($*) :: Applicative f => Ord a => Map a b -> a -> f b -> f b
f $* a = \d ->
  case M.lookup a f of
    Just b  -> pure b
    Nothing -> d
    
maybeHead :: [a] -> Maybe a
maybeHead [   ] = Nothing
maybeHead (x:_) = Just x

unionMap :: (Ord a, Ord b) => (a -> Set b) -> Set a -> Set b
unionMap f = S.unions . map f . S.toList

unionBind :: (Ord a, Ord b) => Set a -> (a -> Set b) -> Set b
unionBind = flip unionMap


(<&>) :: Functor f => f a -> (a -> b) -> f b
(<&>) = flip fmap

(>>>=) :: (Ord a, Ord b) => Set a -> (a -> Set b) -> Set b
(>>>=) = flip unionMap
infixl 1 >>>=

(>>~) :: Functor f => f a -> (a -> b) -> f b
m >>~ f = fmap f m
infixl 1 >>~
  
  
(>>~~) :: Functor f => (f a, b) -> (a -> b -> c) -> f c
(m, b) >>~~ f = m >>~ \a -> f a b
infixl 1 >>~~

(>>~~~) :: Functor f => (f a, b, c) -> (a -> b -> c -> d) -> f d
(m, b, c) >>~~~ f = m >>~ \a -> f a b c
infixl 1 >>~~~

flip2 :: (a -> b -> c) -> (b -> a -> c)
flip2 f = \b a -> f a b
  
flip3 :: (a -> b -> c -> d) -> (b -> c -> a -> d)
flip3 f = \b c a -> f a b c 

flip4 :: (a -> b -> c -> d -> e) -> (b -> c -> d -> a -> e)
flip4 f = \b c d a -> f a b c d 

foldR :: Foldable f => b -> f a -> (a -> b -> b) -> b
foldR = flip3 foldr

foldL :: Foldable f => a -> f b -> (a -> b -> a) -> a
foldL = flip3 foldl'
