module Erlang.Exception
  ( tryCatchFinally
  , tryOfCatchFinally
  , tryCatch
  , tryOfCatch
  , raise
  , throw, error, exit
  ) where

import Prelude
import Erlang.Type
import Erlang.Helpers

import Effect (Effect)

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))

buildException :: String -> ErlangTerm -> String -> ErlangTerm
buildException exType exPayload exStack = ErlangTuple
  [ ErlangAtom exType
  , exPayload
  , make_string exStack
  ]

foreign import raise :: ErlangTerm -> Effect ErlangTerm

foreign import getStack :: Effect String

foreign import tryCatchFinally
  :: forall a. (Unit -> Effect ErlangTerm)
  -> (ErlangTerm -> Effect ErlangTerm)
  -> (Unit -> Effect a)
  -> Effect ErlangTerm

foreign import tryOfCatchFinally
  :: forall a. (Unit -> Effect ErlangTerm)
  -> (ErlangTerm -> Effect ErlangTerm)
  -> (ErlangTerm -> Effect ErlangTerm)
  -> (Unit -> Effect a)
  -> Effect ErlangTerm


foreign import tryCatch
  :: (Unit -> Effect ErlangTerm)
  -> (ErlangTerm -> Effect ErlangTerm)
  -> Effect ErlangTerm

foreign import tryOfCatch
  :: (Unit -> Effect ErlangTerm)
  -> (ErlangTerm -> Effect ErlangTerm)
  -> (ErlangTerm -> Effect ErlangTerm)
  -> Effect ErlangTerm

throw :: ErlangTerm -> Effect ErlangTerm
throw term = do
  stack <- getStack
  raise $ buildException "throw" term stack

error :: ErlangTerm -> Effect ErlangTerm
error term = do
  stack <- getStack
  raise $ buildException "error" term stack

exit :: ErlangTerm -> Effect ErlangTerm
exit term = do
  stack <- getStack
  raise $ buildException "exit" term stack


