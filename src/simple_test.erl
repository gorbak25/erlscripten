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
-erlscripten_output(autogenerated).
-compile({parse_transform, erlscripten}).
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
pat_ops(1 + 2 * 3 / 4) -> kek.


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
