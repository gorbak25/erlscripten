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

test() ->
    if integer(3),
       float(3.0),
       integer(3),
       number(3) ->
             ok end.
    %% << <<123:8>> || 1 < 2 >>.
    %% << <<X:8>> || <<X:2>> <= <<"hej">> >>.
