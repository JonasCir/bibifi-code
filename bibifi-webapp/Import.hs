{-# LANGUAGE FlexibleInstances #-}
module Import
    ( module Import
    ) where

import           Prelude              as Import hiding (head, init, last,
                                                 readFile, tail, writeFile)
import           LYesod               as Import

import           Control.Applicative  as Import (pure, (<$>), (<*>), (<*))
import           Data.Text            as Import (Text)

import           Foundation           as Import
import           Model                as Import
import           Settings             as Import
import           Settings.Development as Import
import           Settings.StaticFiles as Import

import           Config               as Import
import           Contest              as Import
import           Common               as Import

import           LMonad               as Import
import           LMonad.Label.DisjunctionCategory as Import
import           LMonad.Yesod         as Import
import           TCB                  as Import

import           Database.LPersist    as Import
import           Database.LEsqueleto  as Import

import     Database.Persist.RateLimit as Import

import          Yesod.Form.Bootstrap3 as Import

import          RateLimit             as Import

#if __GLASGOW_HASKELL__ >= 704
import           Data.Monoid          as Import
                                                 (Monoid (mappend, mempty, mconcat),
                                                 (<>))
#else
import           Data.Monoid          as Import
                                                 (Monoid (mappend, mempty, mconcat))

infixr 5 <>
(<>) :: Monoid m => m -> m -> m
(<>) = mappend
#endif

