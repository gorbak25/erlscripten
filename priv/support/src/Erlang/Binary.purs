module Erlang.Binary where

import Prelude
import Erlang.Type (ErlangTerm(ErlangBinary, ErlangNum, ErlangTuple))
import Node.Buffer as Buffer
-- import Node.Buffer.Unsafe as Buffer
import Node.Buffer(Buffer)
import Node.Encoding
import Data.Num (class Num, fromBigInt)
import Data.BigInt as BI
import Effect (Effect)
import Effect.Unsafe (unsafePerformEffect)
import Effect.Exception (throw, throwException)
import Data.UInt (UInt, toInt, fromInt)
import Data.Array.NonEmpty as NonEmpty
import Partial.Unsafe (unsafePartial)
import Data.Base58 as B58
import Data.Array as DA
import Data.List as DL
import Data.Maybe(Maybe, fromJust)
import Data.Foldable

error :: forall a. String -> a
error = unsafePerformEffect <<< throw

data Endian = Big | Little
data Sign   = Signed | Unsigned
data BinResult = Nah | Ok ErlangTerm Buffer.Buffer

fromFoldable :: forall f. Foldable f => f Int -> Buffer
fromFoldable f = unsafePerformEffect (Buffer.fromArray (DA.fromFoldable f))

concat :: Array Buffer -> Buffer
concat args = unsafePerformEffect $ Buffer.concat args

buffer (ErlangBinary x) = x
buffer _ = error "buffer – not a binary"

length (ErlangBinary x) = unsafePerformEffect $ Buffer.size x
length _ = error "length – not a binary"

unboxed_byte_size :: Buffer.Buffer -> Int
unboxed_byte_size b = unsafePerformEffect $ Buffer.size b

empty :: Buffer.Buffer -> Boolean
empty buf = unsafePerformEffect $ map (_ == 0) (Buffer.size buf)

size :: Buffer -> ErlangTerm
size = ErlangNum <<< unsafePerformEffect <<< Buffer.size

chop_int :: Buffer.Buffer -> Int -> Int -> Endian -> Sign -> BinResult
chop_int buf size unit endian sign = unsafePerformEffect $ do
  let chopSize = size * unit `div` 8
  size <- Buffer.size buf
  if size < chopSize
    then pure Nah
    else do
    let chop = Buffer.slice 0 chopSize buf
        rest = Buffer.slice chopSize size buf
    pure $ Ok (
      case endian of
        Big    -> ErlangNum (decode_unsigned_big chop)
        Little -> ErlangNum (decode_unsigned_little chop)
      ) rest

chop_bin :: Buffer.Buffer -> Int -> Int -> BinResult
chop_bin buf size unit = unsafePerformEffect $ do
  let chopSize = size * unit `div` 8
  size <- Buffer.size buf
  if size < chopSize
    then pure Nah
    else do
    let chop = Buffer.slice 0 chopSize buf
        rest = Buffer.slice chopSize size buf
    pure $ Ok (ErlangBinary chop) rest

foreign import bytesToFloat64 :: Array Int -> Number
chop_float :: Buffer.Buffer -> Int -> Int -> Endian -> BinResult
chop_float buf size unit endian = unsafePerformEffect $ do
  bufSize <- Buffer.size buf
  let chopSize = size * unit / 8
  if chopSize == 8 || chopSize == 4
    then do
      let chop = Buffer.split 0 chopSize buf
          rest = Buffer.split chopSize bufSize buf
      trueChop <- case endian of
        Big -> pure chop
        Little -> do
          asArr <- Buffer.toArray chop
          Buffer.fromArray (DA.reverse asArr)
      pure $ Ok (if chopSize == 8
                 then ErlangFloat (arrayToFloat64 trueChop)
                 else ErlangFloat (arrayToFloat32 trueChop)
                ) rest
    else pure Nah

unsafe_at :: Buffer -> Int -> Int
unsafe_at buf n = unsafePartial $ fromJust $ unsafePerformEffect $ (Buffer.getAtOffset n buf)

decode_unsigned_big :: Buffer -> Int
decode_unsigned_big buf = unsafePerformEffect (Buffer.size buf >>= go buf 0) where
  go :: Buffer -> Int -> Int -> Effect Int
  go buf acc size = do
    case size of
      0 -> pure acc
      _ -> go
           (Buffer.slice 1 size buf)
           (256 * acc + unsafe_at buf 0)
           (size - 1)

decode_unsigned_little :: Buffer -> Int
decode_unsigned_little buf = unsafePerformEffect (Buffer.size buf >>= go buf 0) where
  go :: Buffer -> Int -> Int -> Effect Int
  go buf acc size = do
    case size of
      0 -> pure acc
      _ -> go
           (Buffer.slice 0 (size - 1) buf)
           (256 * acc + unsafe_at buf (size - 1))
           (size - 1)

from_int :: ErlangTerm -> ErlangTerm -> Int -> Endian -> Buffer
from_int (ErlangNum n) (ErlangNum size) unit endian = unsafePerformEffect $ do
  let bufSize = size * unit / 8
      build 0 _ acc = acc
      build x num acc = build (x - 1) (num / 256) (DL.Cons (num `mod` 256) acc)
      little = build bufSize n DL.Nil
  pure $ Buffer.fromArray $ DA.fromFoldable $
    case endian of
      Big -> DL.reverse little
      Little -> little
from_int _ _ _ _ = EXC.badarg unit

foreign import float32ToArray :: Number -> Array Int
foreign import float64ToArray :: Number -> Array Int
from_float :: ErlangTerm -> ErlangTerm -> Int -> Endian -> Buffer
from_float (ErlangFloat f) (ErlangNum size) unit endian = unsafePerformEffect $ do
  let bufSize = size * unit / 8
  big <- case bufSize of
    64 -> float64ToArray f
    32 -> float32ToArray f
    _ -> EXC.badarg unit
  pure $ Buffer.fromArray $ case endian of
    Big -> big
    Little -> DA.reverse big

format_bin :: ErlangTerm -> ErlangTerm -> Int -> Buffer
format_bin (ErlangBinary buf) (ErlangNum size) unit =
  let bufSize = size * unit / 8
  in Buffer.split 0 bufSize buf
format_bin _ _ _ = EXC.badarg unit



-- toArray :: ErlangTerm -> Effect (Array Int)
-- toArray (ErlangBinary a) = do
--     Buffer.toArray a
-- toArray _ = error "toArray – not a binary"

-- toB64 :: ErlangTerm -> String
-- toB64 (ErlangBinary a) =
--     unsafePerformEffect $ Buffer.toString Base64 a
-- toB64 _ = error "toB64 – not a binary"

-- fromB64 :: String -> ErlangTerm
-- fromB64 str = do
--     ErlangBinary $ unsafePerformEffect $ Buffer.fromString str Base64

-- toB58 :: Partial => ErlangTerm -> String
-- toB58 (ErlangBinary a) =
--     B58.encode $ unsafePerformEffect $ Buffer.toArray a
-- toB58 _ = error "toB58 – not a binary"

-- fromB58 :: String -> Maybe ErlangTerm
-- fromB58 str = do
--     s <- B58.decode str
--     pure $ ErlangBinary $ unsafePerformEffect $ Buffer.fromArray s
