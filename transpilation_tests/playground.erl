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

-compile(export_all).

-compile({no_auto_import, [length/1]}).

test() ->
    ok.
