
-module(lambdas).
-erlscripten_output(autogenerated_transpilation_tests).
-compile({parse_transform, erlps_parse_transform}).
-compile(nowarn).
-compile(export_all).

%% API
-export([]).

test_can_be_called() ->
    A = fun(X) -> X end,
    A(ok).

id(X) -> X.

test_can_pass_fun() ->
    A = fun lambdas:id/1,
    A(ok).

test_match_semantics_1() ->
    X = 2,
    A = fun (X) -> ok end,
    A(3).

test_match_semantics_2() ->
    A = 2,
    B = fun (X) -> A = X end,
    B(1). %% should throw exception

test_scope_does_not_leak_1() ->
    (fun() -> X=2 end)(),
    X = 1.

test_scope_does_not_leak_2() ->
    (fun X() -> ok end)(),
    X = 1.
