-module(erlps_parse_transform).

-author("gorbak25").

-export([parse_transform/2]).

parse_transform(Forms, Options) ->
    io:format(user, "~p\n", [Options]),
    code:ensure_loaded(erlps_logger),
    code:ensure_loaded(erlps_utils),
    code:ensure_loaded(erlps_purescript_pretty),
    code:ensure_loaded(erlps_transpiler),
    application:ensure_started(erlscripten),
    Attributes = erlps_transpiler:filter_module_attributes(Forms),
    {FileName, _} = proplists:get_value(file, Attributes),
    try
        case proplists:get_value(erlscripten_output, Attributes) of
            undefined ->
                erlps_logger:die(FileName,
                                 "Please add `-erlscripten_output(DIRECTORY).` to indicate where "
                                 "the autogenerated spago project will be placed\n");
            Dir ->
                ModuleName = proplists:get_value(module, Attributes),

                [BasePath | _] =
                    string:split(
                        proplists:get_value(outdir, Options), "_build"),
                OutDir = filename:join(BasePath, Dir),
                erlps_utils:generate_template(OutDir),
                SrcDir = filename:join(OutDir, "src"),

                %% Create the Purescript module
                PursModuleFile =
                    filename:join(SrcDir, erlps_transpiler:erlang_module_to_purs_file(ModuleName)),
                file:delete(PursModuleFile),
                {ok, Handle} = file:open(PursModuleFile, [write]),

                PSAst = erlps_transpiler:transpile_erlang_module(Forms),
                TxtModule = erlps_purescript_pretty:format_module(PSAst),
                file:write(Handle, TxtModule)
        end,
        Forms
    catch
        Error:Reason:StackTrace ->
            erlps_logger:die(FileName,
                             io_lib:format("Error: ~s\nReason: ~p\nStacktrace: ~p\n",
                                           [atom_to_list(Error), Reason, StackTrace]))
    end.
