%%%-------------------------------------------------------------------
%%% @author radek
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 26. Okt 2020 10:59
%%%-------------------------------------------------------------------
-module(playground).
-author("radek").
-erlscripten_output(autogenerated_transpilation_tests).
-compile({parse_transform, erlps_parse_transform}).
-compile(nowarn).

-export([test_3/1]).
-record(dupa, {jaja, kek :: integer(), kok = 123, lol = 1999 :: integer()}).

test_3(X) ->
    %% try X of
    %%     _ -> kek
    %% catch
    %%     _ -> lol
    %% after
        jup.
    %% end.
