module Erlang.Type where

import Prelude
import Node.Buffer (Buffer, toArray, fromArray, toArray, concat)
import Data.List
import Data.BigInt as BI
import Data.Maybe
import Effect (Effect)
import Effect.Unsafe (unsafePerformEffect)
import Effect.Exception (error, throwException)

data ErlangTerm
    = ErlangNum       BI.BigInt
    | ErlangCons      ErlangTerm ErlangTerm
    | ErlangEmptyList
    | ErlangBinary    Buffer
    | ErlangTuple     (Array ErlangTerm)

instance showErlangTerm :: Show ErlangTerm where
    show (ErlangNum a) =
        show $ BI.toString a
    show term  | Just l <- erlangListToList term =
        show l
    show (ErlangCons h t) =
        "[" <> show h <> "|" <> show t <> "]"
    show ErlangEmptyList =
        "[]"
    show (ErlangBinary a) =
        show $ unsafePerformEffect $ toArray a
    show (ErlangTuple a) =
        show a

instance eqErlangTerm :: Eq ErlangTerm where
    eq (ErlangNum a) (ErlangNum b) = a == b
    eq (ErlangCons ha ta) (ErlangCons hb tb) = ha == hb && ta == tb
    eq ErlangEmptyList ErlangEmptyList = true
    eq (ErlangBinary a) (ErlangBinary b) = (unsafePerformEffect $ toArray a) == (unsafePerformEffect $ toArray b)
    eq (ErlangTuple a) (ErlangTuple b) = a == b
    eq _ _ = false

concatArrays :: Buffer -> Buffer -> Effect (Buffer)
concatArrays a b = do
    concat [a, b]

instance semigroupErlangTerm :: Semigroup ErlangTerm where
     append (ErlangBinary a) (ErlangBinary b) = ErlangBinary $ unsafePerformEffect (concatArrays a b)
     append _ _ = unsafePerformEffect $ throwException $ error $ "Invalid append"

erlangListToList :: ErlangTerm -> Maybe (List ErlangTerm)
erlangListToList ErlangEmptyList = Just Nil
erlangListToList (ErlangCons h t) | Just et <- erlangListToList t = Just (Cons h et)
erlangListToList _ = Nothing