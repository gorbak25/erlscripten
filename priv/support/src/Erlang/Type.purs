module Erlang.Type where

import Prelude
import Node.Buffer (Buffer, toArray, fromArray, toArray, concat)
import Data.List as DL
import Data.Array as DA
import Data.BigInt as DBI
import Data.Maybe as DM
import Data.Char as DC
import Effect (Effect)
import Effect.Unsafe (unsafePerformEffect)
import Effect.Exception (error, throwException)

type ErlangFun = Partial => List ErlangTerm -> Effect ErlangTerm

-- TODO: add floats
data ErlangTerm
    = ErlangNum       BI.BigInt
    | ErlangCons      ErlangTerm ErlangTerm
    | ErlangEmptyList
    | ErlangBinary    Buffer
    | ErlangTuple     (Array ErlangTerm)
    | ErlangFun       Int ErlangFun

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

erlangStringToString :: ErlangTerm -> Maybe String
erlangStringToString = "todo"

erlangPlus :: ErlangFun
erlangPlus [ErlangNum x, ErlangNum y] = ErlangNum (x + y)

erlangMinus :: ErlangFun
erlangMinus [ErlangNum x, ErlangNum y] = ErlangNum (x - y)

erlangMult :: ErlangFun
erlangMult [ErlangNum x, ErlangNum y] = ErlangNum (x * y)

erlangDiv :: ErlangFun
erlangDiv [ErlangNum x, ErlangNum y] = ErlangNum (x / y)

erlangApply :: ErlangFun
erlangApply [ErlangFun arity@(ErlangNum arityVal) fun, args]
  | Just argsL <- erlangListToList args
  , length argsL == arityVal =
    fun args