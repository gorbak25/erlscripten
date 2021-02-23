%%%-------------------------------------------------------------------
%%% @author radek
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 26. Okt 2020 10:59
%%%-------------------------------------------------------------------
-module(simple_test).
-author("radek").
-erlscripten_output(autogenerated_transpilation_tests).
-compile({parse_transform, erlps_parse_transform}).
-compile(nowarn).
-compile(export_all).

%% API
-export([]).

ident(X) -> X.

unify(X, X) -> ok.

clause(x) -> ok;
clause(y) -> ko.

pat_tuple({X, X}) -> ok;
pat_tuple({{X, X}, {X, X, X}}) -> xd.

-if(?OTP_RELEASE >= 23).
pat_list([X, X] ++ [X, X]) -> k;
-elif.
-endif.
pat_list([H|T]) -> ok;
pat_list([H|[H|G]]) -> ok;
pat_list([]) -> nok;
pat_list([X,X,X]) -> k;

pat_list([X,X,X|[X]]) -> lol.

pat_maps(#{}) -> ok;
pat_maps(#{dupa := X, pupa := X}) -> ok.

pat_match(X = {X, X} = [X | X]) -> X.

pat_ops(1 + 2) -> aa;
pat_ops(1 + 2 * 3) -> kek.


expr_ops(X = ok) -> X + X * X - X ++ X.

expr_app(X) -> expr_app(X).

bifs() ->
    length([]) + erlang:length([]).

eq_pattern([1,2,3] = X) -> X;
eq_pattern(X = [1,2]) -> X.

eq_guard([X,X]) -> X;
eq_guard([X,Y]) when X>Y -> X+Y;
eq_guard([X,Y]) -> eq_guard([Y,X]).

eq_guard(X, Y, Z) when X==Y; Y==Z, 1==2 -> Y.

test_1(X) ->
    ident({X}).

%% Match as last fails :(
%%test_2(X) ->
%%    X=1.

%% do
%%   blah
%%   v <- 1

test_3(X) ->
    ok = X + ({Y, _} = 2).

list_comp() ->
    L = [1,2,3,4],
    L = [X || X <- L],
    [{1,3,5}, {1,3,6}, {1,4,5}, {1,4,6}, {2,3,5}, {2,3,6}, {2,4,5}, {2,4,6}] =
	[{X, Y, Z} || X <- [1,2], Y <- [3,4], Z <- [5,6]],
    ok.

minusminus_op() ->
    [3,4] = [1,2,3,4,2,4] -- [2,1,2,4],
    [3,4,4] = [1,2,3,4,2,4] -- [2,1,2,4.0],
    [] = [] -- [1],
    [1,2,3] = [1,2,3] -- [],
    [] = [1,2,3] -- [4,5,6,1,4,6,2,3],
    [] = [1,2,3] -- [4,5,6,1,4,6,2,3,12,3,4,2,1],
    [] = [] -- [],
    [] = [1,2,3] -- [1,2,3],
    [] = [1,2,3] -- [3,2,1],
    ok.
