-module(circular_two).
-erlscripten_output(autogenerated_transpilation_tests).
-compile({parse_transform, erlps_parse_transform}).
-compile(nowarn).
-compile(export_all).

%% API
-export([]).

one() ->
  circular_one:one().

two() ->
  hello_from_module_two.