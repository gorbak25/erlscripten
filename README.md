![](images/logo_banner.png)
# Erlscripten – Erlang to PureScript transpiler! 

Erlscripten (sic not Emscripten!) is a source to source transpiler
capable of converting most Erlang codebases into semantically
equivalent [PureScript](https://purescript.org) projects. PureScript
is a strongly and statically typed functional language heavily
inspired by Haskell which compiles down to JavaScript. Taking
PureScript as an intermediary step, Erlscripten allows you to take
your existing Erlang application and easily ship it out to JavaScript
users – your Erlang code can now run safely in the browser – enabling
code sharing between an Erlang backend and the frontend. It is highly
interoperable with JavaScript – JavaScript can easily call the
transpiled code and then make use of the results – you can easily map
Erlang constructs and types to readily available JS constructs.

See it in action!

![](images/demo_transpile.gif)

The Erlscripten project consists of several repositories:

- [erlscripten](https://github.com/erlscripten/erlscripten) –
  (recursive link) The main brain of the transpiler. Contains
  algorithms responsible for code translation, [parse
  transform](https://erlang.org/doc/man/erl_id_trans.html#parse_transform-2)
  functionality and simple rebar project support.
- [erlps-core](https://github.com/erlscripten/erlps-stdlib) –
  Implementation of the ERTS in PureScript and JavaScript. Contains
  main definitions of Erlang datatypes in PureScript, builtin
  functions and Erlang process emulator. Provides utilities for
  testing transpiled projects.
- [erlps-stdlib](https://github.com/erlscripten/erlps-stdlib) – A
  PureScript project that consists of transpiled standard library of
  Erlang. Most of it is generated by Erlscripten itself, but some
  parts (especially NIFs) are handcrafted in JavaScript.

# Examples

Here is a demo of Erlang standard library transpilation process
(a.k.a. compatibility benchmark):

![](images/demo_bench.gif)

As you can see, a vast majority of the modules are transpiled
successfully. Aside from casual QuickCheck tests we re-use the
existing tests from Erlang stdlib and run them on the PureScript
side. The problematic libraries that cause Erlscripten to struggle
usually rely on not-yet-implemented builtins, NIFs and more advanced
features of Erlang Run-Time System.

As a practical example you may want to check out the transpiled
[compiler of the Sophia smart contract
language](https://github.com/erlscripten/erlps-aesophia). Not only the
project serves as an entirely working utility, but also runs a decent
amount of transpiled and handwritten tests.

## Code example

The examples are presented in the
[examples](https://github.com/erlscripten/erlscripten/tree/main/examples)
directory. Sample code snippet:

```erlang
-module(factorial).

-export([factorial/1]).

factorial(N) ->
    factorial(N, 1).

factorial(0, Acc) ->
    Acc;
factorial(N, Acc) ->
    factorial(N - 1, Acc * N).
```
Transpiles to:
```purescript
erlps__factorial__1 :: ErlangFun
erlps__factorial__1 [n_0] =
  let arg_2 = toErl 1
  in erlps__factorial__2 [n_0, arg_2]
erlps__factorial__1 [arg_3] = EXC.function_clause unit
erlps__factorial__1 args =
  EXC.badarity (ErlangFun 1 erlps__factorial__1) args

erlps__factorial__2 :: ErlangFun
erlps__factorial__2 [(ErlangInt num_0), acc_1]
  | (ErlangInt num_0) == (toErl 0) =
  acc_1
erlps__factorial__2 [n_0, acc_1] =
  let    rop_4 = toErl 1
  in let arg_2 = BIF.erlang__op_minus [n_0, rop_4]
  in let arg_5 = BIF.erlang__op_mult [acc_1, n_0]
  in erlps__factorial__2 [arg_2, arg_5]
erlps__factorial__2 [arg_8, arg_9] = EXC.function_clause unit
erlps__factorial__2 args =
  EXC.badarity (ErlangFun 2 erlps__factorial__2) args
```

Note: The generated code doesn't target to be readable, but rather to
preserve the semantics of Erlang. This includes, but isn't limited to
exceptions behavior, function arguments evaluation order and side
effects. Some efforts, however, have been made to ease the process of
debugging and reasoning about the produced PureScript.

# Status quo

## What is supported?
- Majority of erlang expression
- Arbitrary arity functions
- Pattern matching
- Records (via tuples)
- Binaries
- Lambdas
- Tail recursion
- Exceptions
- Process dictionaries
- Code server, module loading
- Imports and exports
- Compatibility utilities
- Common errors (`function_clause`, `case_clause`, `badarity`, etc.)

## What is partially supported?
- Erlang's standard library (most essential modules; `lists`, `maps`, `string`, etc.)
- Erlang builtins (growing and growing!)
- Rebar project transpilation
- ETS (missing only `duplicate_bag` implementation)

## What will be supported?
- Bitstrings
- Leaking variable scopes
- Basic erlang process emulation
- NIFs

## What won't be supported
- Hot code reloading
- Distributed erlang

<!--
## How it works?
TODO

## How to create production javascript bundles
TODO - write about rollup
-->

------------------------------

Support us at aeternity: `ak_2WESwy76bMxSxP62XDE937Dmyu8wHyV4uF8KbobMNzQxh5a1sx`

