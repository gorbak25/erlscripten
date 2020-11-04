-module(erlscripten).
-author("gorbak25").

-export([parse_transform/2]).
-export([version/0]).

-include("erlps_purescript.hrl").


-record(env,
        { current_module :: string()
        , records :: map()
        }).

version() -> "v0.0.1".

parse_transform(Forms, Options) ->
    code:ensure_loaded(erlscripten_logger),
    application:ensure_started(erlscripten),
    Attributes = [X || X <- lists:map(fun filter_module_attributes/1, Forms), is_tuple(X)],
    FileName = proplists:get_value(file, Attributes),
    try
        ModuleName = proplists:get_value(module, Attributes),
        erlscripten_logger:info("Transpiling ~s", [ModuleName]),
        case proplists:get_value(erlscripten_output, Attributes) of
            undefined ->
                erlscripten_logger:die(FileName,
                    "Please add `-erlscripten_output(DIRECTORY).`"
                    " to indicate where the autogenerated spago project will be placed\n");
            Dir ->
                [BasePath | _] = string:split(proplists:get_value(outdir, Options), "_build"),
                OutDir = filename:join(BasePath, Dir),
                generate_template(OutDir),
                SrcDir = filename:join(OutDir, "src"),
                %% Ok now let's do some preliminary work before starting the conversion
                %% Gather record types
                Records = maps:from_list(proplists:get_all_values(record, Attributes)),
                %% Create the Purescript module
                PursModuleFile = filename:join(SrcDir, erlang_module_to_purs_file(ModuleName)),
                file:delete(PursModuleFile),
                {ok, Handle} = file:open(PursModuleFile, [write]),

                %% Ok It's time for some canonical imports which will be used a lot :)
                DefaultImports =
                    [ #import{path = ["Prelude"]}
                    , #import{path = ["Data", "List"], alias = "DL"}
                    , #import{path = ["Data", "Maybe"], alias = "DM"}
                    , #import{path = ["Erlang", "Builtins"]}
                    , #import{path = ["Erlang", "Type"], explicit = ["ErlangFun", "ErlangTerm(..)"]}
                    , #import{path = ["Effect"], explicit = ["Effect"]}
                    ],
                %% Now it's time to determine what modules to import
                %% First filter out functions to transpile
                FunctionForms = [X || X <- lists:map(fun filter_function_forms/1, Forms), is_tuple(X)],
                %% TODO Now walk the entire AST and search for calls/remote_calls
                Imports = [],

                Env = #env{
                         current_module = ModuleName,
                         records = Records
                        },
                %% Now do the dirty work - transpile every function OwO
                Decls = [transpile_function(Function, Env) ||
                    Function = {{FunName, Arity}, _} <- FunctionForms,
                    element(1, check_builtin(ModuleName, FunName, Arity)) =:= local
                ],
                %% Dispatchers = [#top_clause{clause = Disp}
                    %% || Disp <- make_dispatchers(FunctionForms)],
                Module = #module{
                    name = erlang_module_to_purs_module(ModuleName),
                    imports = DefaultImports ++ Imports,
                    decls = Decls %++ Dispatchers
                },
                file:write(Handle, erlps_purescript:format_module(Module))
        end,
        Forms
    catch Error:Reason:StackTrace ->
        erlscripten_logger:die(FileName,
            io_lib:format("Error: ~s\nReason: ~p\nStacktrace: ~p\n", [atom_to_list(Error), Reason, StackTrace])
        )
    end.

filter_module_attributes({attribute, _, file, {Filename, _}}) -> {file, Filename};
filter_module_attributes({attribute, _, module, Module}) when is_atom(Module) -> {module, atom_to_list(Module)};
filter_module_attributes({attribute, _, export, Exports}) -> {export, Exports};
filter_module_attributes({attribute, _, record, {RecordName, RecordFields}}) ->
    {record, {RecordName, lists:map(fun record_fields/1, RecordFields)}};
filter_module_attributes({attribute, _, erlscripten_output, Directory}) when is_atom(Directory) ->
    {erlscripten_output, atom_to_list(Directory)};
filter_module_attributes({attribute, _, erlscripten_output, Directory}) when is_binary(Directory) ->
    {erlscripten_output, binary_to_list(Directory)};
filter_module_attributes({attribute, _, erlscripten_output, Directory}) when is_list(Directory) ->
    {erlscripten_output, Directory};
filter_module_attributes(_) -> undefined.

record_fields({record_field, _, {atom, N, FieldName}}) -> {FieldName, {atom, N, undefined}};
record_fields({record_field, _, {atom, _, FieldName}, Default}) -> {FieldName, Default};
record_fields({typed_record_field, RecordField, _}) -> record_fields(RecordField).

generate_template(DestDir) ->
    SupportDir = filename:join(code:priv_dir(erlscripten), "support"),
    copy_recursive(SupportDir, DestDir).

copy_recursive(Source, Dest) ->
    case filelib:is_dir(Source) of
        true ->
            case filelib:is_dir(Dest) of
                false ->
                    file:make_dir(Dest);
                true ->
                    ok
            end,
            {ok, Names} = file:list_dir(Source),
            [copy_recursive(filename:join(Source, Name), filename:join(Dest, Name)) || Name <- Names];
        false ->
            file:copy(Source, Dest)
    end.

-spec erlang_module_to_purs_module(string() | atom()) -> string().
erlang_module_to_purs_module(Name) when is_atom(Name) ->
    erlang_module_to_purs_module(atom_to_list(Name));
erlang_module_to_purs_module(Name) ->
    string:join(lists:map(fun string:titlecase/1, string:split(Name, "_", all)), ".").

-spec erlang_module_to_qualified_import(string() | atom()) -> string().
erlang_module_to_qualified_import(Name) when is_atom(Name) ->
    erlang_module_to_qualified_import(atom_to_list(Name));
erlang_module_to_qualified_import(Name) ->
    string:join(lists:map(fun string:titlecase/1, string:split(Name, "_", all)), "").

-spec erlang_module_to_purs_file(string() | atom()) -> string().
erlang_module_to_purs_file(Name) when is_atom(Name) ->
    erlang_module_to_purs_file(atom_to_list(Name));
erlang_module_to_purs_file(Name) ->
    string:join(lists:map(fun string:titlecase/1, string:split(Name, "_", all)), "") ++ ".purs".

filter_function_forms({function, _, FunName, Arity, Clauses}) ->
    {{atom_to_list(FunName), Arity}, Clauses};
filter_function_forms(_) ->
    undefined.

transpile_function({{FunName, Arity}, Clauses}, Env) ->
    Type = #type_var{name = "ErlangFun"},
    PSClauses = [transpile_function_clause(FunName, Clause, Env) ||
                    Clause <- Clauses],
    #valdecl{
       name = transpile_fun_name(FunName, Arity),
       clauses = PSClauses,
       type = Type
      }.

transpile_fun_name(Name, Arity) when is_atom(Name) ->
    transpile_fun_name(atom_to_list(Name), Arity);
transpile_fun_name(Name, Arity) when is_binary(Name) ->
    transpile_fun_name(binary_to_list(Name), Arity);
transpile_fun_name(Name, Arity) ->
    io_lib:format("~s''~p", [Name, Arity]).

builtins() ->
    Operators = [ {"+",   "op_plus"}
                , {"-",   "op_minus"}
                , {"*",   "op_mult"}
                , {"/",   "op_div"}
                , {"div", "op_div"}
                , {"/=",  "op_neq"}
                , {"=/=", "op_exactNeq"}
                , {"==",  "op_eq"}
                , {"=:=", "op_exactEq"}
                , {">",   "op_greater"}
                , {"<",   "op_lesser"}
                , {">=",  "op_greaterEq"}
                , {"=<",  "op_lesserEq"}
                , {"++",  "op_append"}
                , {"--",  "op_unAppend"}
                , {"&&",  "op_and"}
                , {"||",  "op_or"}
                , {"andalso", "op_and"}
                , {"orelse" , "op_or"}
                ],
    maps:from_list(lists:append(
        [ {{"erlang", Op, 2}, io_lib:format("erlang''~s", [Fun])}
          || {Op, Fun} <- Operators],
        [ {{Module, Fun, Arity}, io_lib:format("~s''~s''~p", [Module, Fun, Arity])}
          || {Module, Fun, Arity} <-
                 lists:concat(
                   [ [ {"lists", "keyfind", 3}
                     , {"lists", "keymember", 3}
                     , {"lists", "keysearch", 3}
                     , {"lists", "member", 2}
                     , {"lists", "reverse", 2}
                     ]
                   , [ {"erlang", atom_to_list(BIF), Arity}
                       || {BIF, Arity} <- erlang:module_info(exports),
                          proplists:get_value(atom_to_list(BIF), Operators, none) =:= none
                     ]
                   ]
                  )
        ])).

check_builtin(Module, Name, Arity) ->
    Key = {Module, Name, Arity},
    case builtins() of
        #{Key := Builtin} -> {builtin, Builtin};
        _ -> {local, Name}
    end.


transpile_fun_ref(Name, Arity, Env = #env{current_module = Module}) ->
    transpile_fun_ref(Module, Name, Arity, Env).
transpile_fun_ref(Module, Name, Arity, Env) when is_atom(Name) ->
    transpile_fun_ref(Module, atom_to_list(Name), Arity, Env);
transpile_fun_ref(Module, Name, Arity, Env) when is_atom(Module) ->
    transpile_fun_ref(atom_to_list(Module), Name, Arity, Env);
transpile_fun_ref(Module, Name, Arity, #env{current_module = CurModule}) ->
    case check_builtin(Module, Name, Arity) of
        {builtin, Builtin} ->
            #expr_var{name = "Erlang.Builtins." ++ Builtin};
        {local, Local} ->
            if CurModule == Module -> #expr_var{name = Local};
               true -> #expr_var{name = erlang_module_to_purs_module(Module) ++ "." ++ Local}
            end
    end.

-spec make_dispatcher_name(string()) -> string().
make_dispatcher_name(Name) ->
    Name ++ "''dispatch".

%% Dispatcher for a given function by available arities
make_dispatcher_for(Name, Arities) ->
    #valdecl{
       name = make_dispatcher_name(Name),
       clauses =
           [#clause{
               args = [#pat_var{name = "arity"}, #pat_var{name = "args"}],
               value =
                   #expr_case{
                      expr = #expr_var{name = "arity"},
                      cases =
                          [{#pat_constr{constr = "ErlangNum", args = [#pat_num{value = Arity}]},
                            [], % guards
                            #expr_app{
                               function = #expr_var{name = transpile_fun_name(Name, Arity)},
                               args = [#expr_var{name = io_lib:format("arg_~p", [I])}
                                       || I <- lists:seq(1, Arity)]}}
                           || Arity <- Arities
                          ]
                     }
              }
           ]}.

%% Dispatcher for all defined functions by arity
make_dispatchers(Functions) ->
    ArityMap = lists:foldr(
        fun({K, V}, D) -> dict:append(K, V, D) end,
        dict:new(),
        [{Name, Arity} || {{Name, Arity}, _} <- Functions]),
    ArityMapList = dict:to_list(ArityMap),
    Global = make_global_dispatcher([Name || {Name, _} <- ArityMapList]),
    [make_dispatcher_for(Fun, Arities)
        || {Fun, Arities} <- ArityMapList
    ] ++ [Global].

global_dispatcher_name() ->
    "main_dispatcher''".

%% Dispatcher of all functions in an actual module by name and arity
make_global_dispatcher(FunNames) ->
    #valdecl{
       name = global_dispatcher_name(),
       clauses =
           [#clause{
               args = [#pat_var{name = "function"}, #pat_var{name = "arity"}, #pat_var{name = "args"}],
               value =
                   #expr_case{
                      expr = #expr_var{name = "function"},
                      cases =
                          [{#pat_string{value = Fun},
                            [], % guards
                            #expr_app{
                               function = #expr_var{name = make_dispatcher_name(Fun)},
                               args = [#expr_var{name = "arity"}, #expr_var{name = "args"}]
                              }}
                           || Fun <- FunNames
                          ]
                     }
              }
           ]}.

transpile_function_clause(FunName, {clause, _, Args, Guards, Body}, Env) ->
    %% Ok this will be slightly tricky, some patterns commonly used in erlang function clauses
    %% cannot be expressed as matches in Purescipt BUT we may emulate them in guards!
    %% Guards in purescript are really powerful - using patten guards we will emulate what we want
    %% Now we need to determine 2 important things:
    %% 1) What to match in the function head
    %% 2) What to assert in the guard
    %% We also need to emulate erlang's semantics of matching by value
    %% Important:
    %% 1) Standalone variables are the simplest case to consider
    %% 2) Literal atoms/strings/tuples are easy
    %% 3) Binaries are a PITA
    %% Keeping track of variable bindings in a pure functional way will be a PITA
    %% Let's use the process dictionary to emulate a state monad and then gather results at the end
    %% Only after we emitted the guards which will bring the referenced variables in scope
    %% we may add the guards from erlang :)
    %% When matching by value always create a new variable and AFTER all the guards which
    %% will bring the vars in the proper scope we will assert equality
    %% What essentially we want to generate:
    %% fun_name match1 match2 ... matchN | g_match1, g_match2, ..., g_matchN, ERLANG_MATCH_BY_VALUE, user erlang guard expressions
    %% Some guards which we may emit are in the state monad
    %% To deal with it just emit "unsafePerformEffect" and add guards which will ensure that
    %% The effectful computation won't throw an exception
    %% For instance: when dealing with <<X>> first emit a check for the length and
    %% only then unsafely access the specified byte in the binary
    state_clear_vars(),
    state_clear_var_stack(),
    {PsArgs, PsGuards} = transpile_pattern_sequence(Args, Env),
    #clause{
        args = [#pat_array{value = PsArgs}],
        guards = PsGuards ++ transpile_boolean_guards(Guards, Env),
        value = transpile_expr(Body, Env)
    }.


transpile_boolean_guards([], _Env) -> [];
transpile_boolean_guards(Guards, Env) ->
    Alts = [
      lists:foldl(fun(G, AccConjs) -> {op, any, "andalso", AccConjs, G} end,
        hd(Alt), tl(Alt)) || Alt <- Guards ],
    E = lists:foldl(
      fun(Alt, AccAlts) -> {op, any, "orelse", AccAlts, Alt} end,
      hd(Alts), tl(Alts)),
    {TruePat, [], []} = transpile_pattern({atom, any, true}, Env),
    [#guard_assg{
       lvalue = TruePat,
       rvalue = transpile_expr(E, Env)
    }].

transpile_pattern_sequence(PatternSequence, Env) ->
    state_push_var_stack(), %% Push fully bound variables
    S = [transpile_pattern(Pattern, Env) || Pattern <- PatternSequence, is_tuple(Pattern)],
    PSArgs = [A || {A, _, _} <- S],
    %% First the guards which will create the variable bindings
    %% Then the guards which will ensure term equality
    PsGuards = lists:flatten([G || {_, G, _} <- S]) ++ lists:flatten([G || {_, _, G} <- S]),
    {PSArgs, PsGuards}.

%% An erlang pattern can always be compiled to a purescript pattern and a list of guards
%% Returns {match, g_match, values_eq}
%% match is an purescript pattern, g_match are the pattern guards which will bring the
%% necessary bindings to the appropriate scope, values_eq ensure erlang term equality
%% for cosmetic reasons values_eq are aggregated and evaluated only after all g_match got executed
%% https://erlang.org/doc/apps/erts/absform.html#patterns
%% Atomic Literals
transpile_pattern({atom, Ann, Atom}, Env) when is_atom(Atom) ->
    transpile_pattern({atom, Ann, atom_to_list(Atom)}, Env);
transpile_pattern({atom, _, Atom}, _) ->
    {#pat_constr{constr = "ErlangAtom", args = [#pat_string{value = Atom}]}, [], []};
transpile_pattern({char, _, Char}, _) ->
    error(todo);
transpile_pattern({float, _, Float}, _) ->
    error(todo);
%% transpile_pattern({integer, _, Num}, _) when Num =< 9007199254740000, Num >= -9007199254740000 ->
%%     error({todo, too_big_int}); TODO
transpile_pattern({integer, _, Num}, _) ->
    {#pat_num{value = Num}, [], []};
transpile_pattern({op, _, "-", {integer, Ann, Num}}, Env) ->
    transpile_pattern({integer, Ann, -Num}, Env);

%% Bitstring pattern
transpile_pattern({bin, _, []}, _) ->
    %% The easy case – <<>>
    %% Empty binary - guard for size eq 0
    Var = state_create_fresh_var(),
    {{#pat_constr{constr = "ErlangBinary", args = [#pat_var{name = Var}]}}, [
        #guard_expr{guard =
        #expr_binop{
            name = "==",
            lop = #expr_num{value = 0},
            rop = #expr_app{function = #expr_var{name = "ErlangBinary.unboxed_byte_size"}, args = [#expr_var{name = Var}]}}}
    ], []};
transpile_pattern({bin, _, [{bin_element, _, {string, _, Str}, default, default}]}, _) ->
    %% Binary string literal – <<"erlang">>
    %% Assert buffer length and then compare with str
    Var = state_create_fresh_var(),
    {{#pat_constr{constr = "ErlangBinary", args = [#pat_var{name = Var}]}}, [
        #guard_expr{guard = #expr_binop{
            name = "==",
            lop = #expr_num{value = length(Str)},
                               rop = #expr_app{
                                        function = #expr_var{name =  "ErlangBinary.unboxed_byte_size"},
                                        args = [#expr_var{name = Var}]}}},
        #guard_expr{guard = #expr_binop{
            name = "==",
            lop = #expr_num{value = length(Str)},
            rop = #expr_app{
                     function = #expr_var{name = "ErlangBinary.unboxed_strcmp"},
                     args = [#expr_var{name = Var}, #expr_string{value = Str}]}}}
    ], []};
transpile_pattern({bin, _, Segments}, _) ->
    %% Ok the general hard part...
    %% Unfortunately we need to keep track of bindings created in this match
    %% Variables in the size guard can only reference variables from the enclosing scope
    %% present on the variable stack OR variables created during this binding
    %% Fortunately patterns can only be literals or variables
    %% Size specs are guard expressions
    Var = state_create_fresh_var(),
    {G, V, _} = transpile_binary_pattern_segments(Var, Segments, #{}),
    {#pat_constr{constr = "ErlangBinary", args = [#pat_var{name = Var}]}, G, V};
%% Compound pattern
transpile_pattern({match, _, {var, _, _} = V, P}, Env) ->
    {H, G, V1} = transpile_pattern(P, Env),
    case transpile_pattern(V, Env) of
      pat_wildcard ->
        {H, G, V1};
      {#pat_var{name = N}, [], V2} ->
        {#pat_as{name = N, pattern = H}, G, V1++V2}
    end;
transpile_pattern({match, Ann, P, {var, _, _} = V}, Env) ->
    transpile_pattern({match, Ann, V, P}, Env);
transpile_pattern({match, _, P1, P2}, Env) ->
    {H1, G1, V1} = transpile_pattern(P1, Env),
    {H2, G2, V2} = transpile_pattern(P2, Env),
    Var = state_create_fresh_var(),
    {#pat_as{name = Var, pattern = H2},
        [#guard_assg{lvalue = H1, rvalue = #expr_var{name = Var}} | G1 ++ G2], V1 ++ V2};

%% Cons pattern
transpile_pattern({cons, _, Head, Tail}, Env) ->
    {H, GH, VH} = transpile_pattern(Head, Env),
    {T, GT, VT} = transpile_pattern(Tail, Env),
    {#pat_constr{constr = "ErlangCons", args = [H, T]}, GH ++ GT, VH ++ VT};

%% Map pattern
transpile_pattern({map, _, Associations}, Env) ->
    MapVar = state_create_fresh_var(),
    {G, V} =
        lists:foldl(fun({map_field_exact, _, Key, Value}, {Gs, Vs}) ->
            begin
                {ValPat, GV, VV} = transpile_pattern(Value, Env),
                KeyExpr = transpile_expr(Key, Env),
                QueryGuard = #guard_assg{
                    lvalue = #pat_constr{constr = "DM.Just", args = [ValPat]},
                    rvalue = #expr_app{
                        function = #expr_var{name = "Map.lookup"},
                        args = [KeyExpr, #expr_var{name = MapVar}]}},
                {[QueryGuard | GV ++ Gs], VV ++ Vs}
            end end, {[], []}, Associations),
    {#pat_var{name = MapVar}, G, V};

%% Nil pattern
transpile_pattern({nil, _}, Env) ->
    {#pat_constr{constr = "ErlangEmptyList"}, [], []};

%% Operator pattern
transpile_pattern({op, _, '++', {nil, _}, P2}, Env) ->
    transpile_pattern(P2, Env);
transpile_pattern({op, Ann, '++', {cons, AnnC, H, T}, P2}, Env) ->
    transpile_pattern({cons, AnnC, H, {op, Ann, '++', T, P2}}, Env);
transpile_pattern(P = {op, Ann, Op, P1, P2}, Env) ->
    case compute_constexpr(P) of
        {ok, Res} -> Res;
        error -> error({illegal_operator_pattern, P})
    end;
transpile_pattern({op, _, Op, P1}, Env) ->
    %% this is an occurrence of an expression that can be evaluated to a number at compile time
    error(todo);

%% Record index pattern
transpile_pattern({record_index, _, RecordName, Field}, Env) ->
    error(todo);

%% Record pattern
transpile_pattern({record, Ann, RecordName, RecordFields}, Env) ->
    %% Convert this to a tuple
    Matches = [record_fields(X) || X <- RecordFields],
    Fields = [{atom, Ann, RecordName}] ++
        [proplists:get_value(FieldName, Matches, {var, Ann, "_"}) ||
            {FieldName, _} <- maps:get(RecordName, Env#env.records)],
    transpile_pattern({tuple, Ann, Fields}, Env);

%% Tuple pattern
transpile_pattern({tuple, _, Args}, Env) ->
    S = [transpile_pattern(Arg, Env) || Arg <- Args, is_tuple(Arg)],
    PSArgs = [A || {A, _, _} <- S],
    PsVarGuards = lists:flatten([G || {_, G, _} <- S]),
    PsValGuards = lists:flatten([G || {_, _, G} <- S]),
    {#pat_constr{constr = "ErlangTuple", args = PSArgs}, PsVarGuards, PsValGuards};

%% Universal pattern
transpile_pattern({var, _, [$_ | _]}, _) ->
    pat_wildcard;

%% Variable pattern
transpile_pattern({var, _, ErlangVar}, _) ->
    Var = state_get_unused_var_name(),
    case state_is_used(ErlangVar) of
        false ->
            state_put_var(ErlangVar, Var),
            {#pat_var{name = Var}, [], []};
        true ->
            %% Variable was used before so emit an extra guard
            state_put_var(Var, Var),
            {#pat_var{name = Var},
                [],
                [#guard_expr{guard = #expr_binop{
                    name = "==",
                    lop = #expr_var{name = Var},
                    rop = #expr_var{name = state_get_var(ErlangVar)}}}]}
    end;


transpile_pattern(Arg, _Env) ->
    error({unimplemented_pattern, Arg}).

%% When resolving variables in the size spec look to:
%% 1) The outer scope on the stack
%% 2) The newBindings scope
%% 3) If var is present in both scopes then insert a value guard
transpile_binary_pattern_segments(UnboxedVar, [], NewBindings) ->
    ok.

transpile_expr([], _) ->
    error(empty_body);
transpile_expr([Single], Env) ->
    transpile_expr(Single, Env);

transpile_expr([{match, _, Pat, Val}|Rest], Env) ->
    {[PSPat], PSGuards} = transpile_pattern_sequence([Pat], Env),
    #expr_case{
       expr = transpile_expr(Val, Env),
       cases =
           [ {PSPat, PSGuards,
              transpile_expr(Rest, Env)
             }
           , {pat_wildcard, [], #expr_app{function = #expr_var{name = "error"}, args = [#expr_string{value = "bad_match"}]}}
           ]
      };

transpile_expr([Expr|Rest], Env) ->
    #expr_binop{
       name = ">>",
       lop = transpile_expr(Expr, Env),
       rop = transpile_expr(Rest, Env)
      };

transpile_expr({atom, Ann, Atom}, Env) when is_atom(Atom) ->
    transpile_expr({atom, Ann, atom_to_list(Atom)}, Env);
transpile_expr({atom, _, Atom}, _Env) ->
    #expr_app{function = #expr_var{name = "ErlangAtom"}, args = [#expr_string{value = Atom}]};

transpile_expr({var, _, Var}, _Env) ->
    #expr_var{name = state_get_var(Var)};

transpile_expr({integer, _, Int}, _Env) ->
    #expr_num{value = Int};

transpile_expr({op, _, Op, L, R}, Env) ->
    OpFun = transpile_fun_ref("erlang", Op, 2, Env),
    LE = transpile_expr(L, Env),
    RE = transpile_expr(R, Env),
    #expr_app{function = OpFun, args = [LE, RE]};

transpile_expr({call, _, {atom, _, Fun}, Args}, Env) ->
    #expr_app{
       function = transpile_fun_ref(Fun, length(Args), Env),
       args = [transpile_expr(Arg, Env) || Arg <- Args]
      };
transpile_expr({call, _, {remote, _, {atom, _, Module}, {atom, _, Fun}}, Args}, Env) ->
    #expr_app{
       function = transpile_fun_ref(Module, Fun, length(Args), Env),
       args = [transpile_expr(Arg, Env) || Arg <- Args]
      };
transpile_expr({call, _, Fun, Args}, Env) ->
    #expr_app{
        function = #expr_var{name = "Erlang.Builtins.erlang''apply''2"},
        args = [transpile_expr(Fun, Env), transpile_expr(Args, Env)]
    };

transpile_expr({nil, _}, _) ->
    #expr_var{name = "ErlangEmptyList"};
transpile_expr({cons, _, H, T}, Env) ->
    #expr_app{
       function = #expr_var{name = "ErlangCons"},
       args = [transpile_expr(H, Env), transpile_expr(T, Env)]
      };

transpile_expr({'if', _, Clauses}, Env) ->
    #expr_case{
       expr = transpile_expr({atom, any, true}, Env),
       cases = [{pat_wildcard,
                 [#guard_expr{guard = transpile_expr(G, Env)} || G <- Guards],
                 transpile_expr(Cont, Env)} ||
                   {clause, _, [], Guards, Cont} <- Clauses]
      };

transpile_expr({'case', _, Expr, Clauses}, Env) ->
    #expr_case{
       expr = transpile_expr(Expr, Env),
       cases =
           [ begin
                 {[PSPat], PSGuards} = transpile_pattern_sequence(Pat, Env),
                 {PSPat, PSGuards ++ transpile_boolean_guards(Guards, Env), transpile_expr(Cont, Env)}
             end
            || {clause, _, Pat, Guards, Cont} <- Clauses
           ]
      };

transpile_expr({'fun', _, {function, Fun, Arity}}, Env) when is_atom(Fun) ->
    #expr_app{
       function = #expr_var{name = "ErlangFun"},
       args =
           [ #expr_num{value = Arity}
           , transpile_fun_ref(Fun, Arity, Env)
           ]
      };

transpile_expr({tuple, _, Exprs}, Env) ->
    #expr_app{
       function = #expr_var{name = "ErlangTuple"},
       args =
           [ transpile_expr(Expr, Env)
             || Expr <- Exprs
           ]
      };

transpile_expr({lc, _, Ret, []}, Env) ->
    #expr_app{
       function = #expr_var{name = "ErlangCons"},
       args = [transpile_expr(Ret, Env), #expr_var{name = "ErlangEmptyList"}]
      };
transpile_expr({lc, _, Ret, [{generate, Ann, Pat, Source}|Rest]}, Env) ->
    Var = state_create_fresh_var(),
    {[PSPat], Guards} = transpile_pattern_sequence([Pat], Env),
    #expr_app{
       function = #expr_var{name = "erlangListFlatMap"},
       args =
           [ transpile_expr(Source, Env)
           , #expr_lambda{
                args = [#pat_var{name = Var}],
                body = #expr_case{
                          expr = #expr_var{name = Var},
                          cases = [ {PSPat, Guards, transpile_expr({lc, Ann, Ret, Rest}, Env)}
                                  , {pat_wildcard, [], #expr_var{name = "ErlangEmptyList"}}
                                  ]
                         }
               }
           ]
      };
transpile_expr({lc, Ann, Ret, [Expr|Rest]}, Env) ->
    #expr_case{
       expr = transpile_expr(Expr, Env),
       cases = [ {#pat_constr{constr = "ErlangAtom", args = [#pat_string{value = "true"}]}, [],
                  transpile_expr({lc, Ann, Ret, Rest}, Env)}
               , {pat_wildcard, [], #expr_var{name = "ErlangEmptyList"}}
               ]
      };

transpile_expr(X, _Env) ->
    error({unimplemented_expr, X}).

compute_constexpr({op, _, Op, L, R}) -> %% FIXME: float handling needs to be fixed
    case {compute_constexpr(L), compute_constexpr(R)} of
        {{ok, LV}, {ok, RV}}
            when is_number(LV) andalso is_number(RV) andalso
            (Op =:= '+' orelse Op =:= '-' orelse Op =:= '*' orelse Op =:= '/')
            -> {ok, (fun erlang:Op/2)(LV, RV)};
        _ -> error
    end;
compute_constexpr({integer, _, Num}) ->
    {ok, Num};
compute_constexpr({float, _, Num}) ->
    {ok, Num}.

%% Hacky emulation of a state monad using the process dictionary :P
-define(BINDINGS, var_bindings).
-define(BINDINGS_STACK, var_bindings_stack).
%% Variable bindings
state_clear_vars() ->
    put(?BINDINGS, #{}).
state_get_vars() ->
    get(?BINDINGS).
state_get_unused_var_name() ->
    "v" ++ integer_to_list(map_size(state_get_vars())).
state_put_var(ErlangVar, PsVar) ->
    put(?BINDINGS, maps:put(ErlangVar, PsVar, state_get_vars())).
state_create_fresh_var() ->
    Var = state_get_unused_var_name(),
    state_put_var(Var, Var),
    Var.
state_is_used(ErlangVar) ->
    maps:is_key(ErlangVar, state_get_vars()).
state_get_var(ErlangVar) ->
    maps:get(ErlangVar, state_get_vars()).
%% Bindings stack
state_clear_var_stack() ->
    put(?BINDINGS_STACK, []).
state_push_var_stack() ->
    put(?BINDINGS_STACK, [state_get_vars() | get(?BINDINGS_STACK)]).
state_pop_var_stack() ->
    put(?BINDINGS_STACK, tl(get(?BINDINGS_STACK))).
state_peek_var_stack() ->
    hd(get(?BINDINGS_STACK)).
