-module(exceptions).
-erlscripten_output(autogenerated_transpilation_tests).
-compile({parse_transform, erlps_parse_transform}).
-compile(nowarn).
-compile(export_all).

test_try_catch() ->
    try throw(ok), bad
    catch _ -> ok
    end.

test_try_catch_type() ->
    try throw(ok), bad
    catch T:E -> {T, E}
    end.

test_try_catch_select_throw() ->
    try throw(ok), bad
    catch error:_ -> bad;
          throw:_ -> ok
    end.

test_try_catch_select_error() ->
    try error(ok), bad
    catch _ -> bad;
          error:bad -> bad;
          error:ok -> ok
    end.

test_try_of() ->
    try ok of
        X -> X
    catch _:_ -> bad
    end.

test_try_of_catch() ->
    try throw(xd), bad of
        _ -> bad
    catch throw:_ -> ok
    end.

test_rethrow() ->
    try
        try exit(boom)
        catch exit:boom ->
                error(ok), bad;
              _:_ -> bad
        end
    catch error:ok ->
            ok;
          _:_ -> bad
    end.

test_throw_of() ->
    try
        try ok of
            _ -> error(boom), bad
        catch
              _:_ -> bad
        end
    catch error:boom ->
            ok;
          _:_ -> bad
    end.

test_unmatched_catch() ->
    try
        try throw(konik)
        catch krowa ->
                bad
        end
    catch konik ->
            ok
    end.

test_after_throw_return() ->
    try
        try
            bad
        after
            throw(ok)
        end
    catch throw:OK ->
            OK
    end.

test_after_throw_catch() ->
    try
        try
            throw(bad), bad
        catch bad -> bad
        after
            throw(ok)
        end
    catch throw:OK ->
            OK
    end.

test_after_throw_rethrow() ->
    try
        try
            throw(bad), bad
        catch Err -> throw(Err)
        after
            throw(ok)
        end
    catch throw:OK ->
            OK
    end.

test_after_throw_of() ->
    try
        try ok of
            ok -> throw(bad), bad
        catch Err -> throw(Err)
        after
            throw(ok)
        end
    catch throw:OK ->
            OK
    end.

test_nasty_nest() ->
    F = fun(X) ->
                error(X)
        end,
    G = fun(K) ->
                try K(ok) of
                    X -> exit(X)
                catch error:C ->
                        {error, C};
                      throw:C ->
                        {throw, C}
                end
        end,
    H = fun(K) ->
                case G(fun(_) -> K(lol) end) of
                    ok -> throw(K);
                    {E, X} -> K({E, X})
                end
        end,
    try try H(F)
        catch
            _:{error, ER} ->
                error(ER);
            _:{throw, ER} ->
                throw(ER);
            _:{exit, ER} ->
                exit(ER);
            _ -> bad
        end
    catch
        _ -> bad;
        exit:_ -> bad;
        error:lol -> ok;
        error:A -> A
    end.

test_sick_factorial(N) ->
    Guess =
        fun Guess(X, Pred) ->
                try true = Pred(X), X
                catch error:{badmatch, false} -> Guess(X + 1, Pred)
                end
        end,
    Mul =
        fun(X,Y) ->
                Guess(0, fun(Z) -> Z == X * Y end)
        end,
    Prev =
        fun(X) ->
                Guess(0, fun(Z) -> Z == X - 1 end)
        end,
    FacW =
        fun FacW(0) -> 1;
            FacW(X) -> Mul(X, FacW(Prev(X)))
        end,
    Fac =
        fun(X) ->
                try Guess(0, fun(10) -> throw(FacW(X));
                                (_) -> false end
                         )
                catch throw:Res -> Res
                end
        end,
    Fac(N).

test_completely_casual_foldl(F, Acc, L) ->
    Sick =
        fun Rec([]) ->
                throw(fun(X) -> X end);
            Rec([H|T]) ->
                try Rec(T)
                catch Cont ->
                        throw(fun(X) -> Cont(F(X, H)) end)
                end
        end,
    try Sick(L)
    catch Res ->
            Res(Acc)
    end.

test_deprecated_catch_throw() ->
    catch throw(ok).
test_deprecated_catch_error() ->
    case catch error(ok) of
        {E, {P, _}} -> {E, P};
        _ -> bad
    end.
test_deprecated_catch_exit() ->
    catch exit(ok).
