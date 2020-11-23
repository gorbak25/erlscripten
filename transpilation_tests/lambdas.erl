
-module(lambdas).
-erlscripten_output(autogenerated_transpilation_tests).
-compile({parse_transform, erlps_parse_transform}).
-compile(nowarn).
-compile(export_all).

%% API
-export([]).

test_can_be_called() ->
    A = fun(Q) -> Q end,
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
    B = fun (W) -> A = W end,
    B(ok). %% should throw exception

test_match_semantics_3() ->
    A = 2,
    F = fun (X) when X==A -> ok; (_) -> match_failed end,
    ok = F(2),
    match_failed = F(3),
    ok.

test_scope_does_not_leak_1() ->
    (fun() -> X=2 end)(),
    X = ok.

test_scope_does_not_leak_2() ->
    (fun X() -> ok end)(),
    X = ok.

test_can_use_stdlib() ->
    R = lists:map(fun(X) -> X*2 end, lists:seq(1,10)),
    [2,4,6,8,10,12,14,16,18,20] = R,
    ok.

test_factorial_abuse_1() ->
    %% http://www.willamette.edu/~fruehr/haskell/evolution.html OwO
    A = fun FacCps(K, 0) -> K(1);
            FacCps(K, N) -> FacCps(fun(R) -> K(R*N) end, N-1) end,
    720 = A(fun(X) -> X end, 6),
    ok.

y(X) ->
   F = fun (P) -> X(fun (Arg) -> (P(P))(Arg) end) end,
   F(F).

mk_fact() ->
   F =
     fun (FA) ->
          fun (N) ->
              if (N == 0) -> 1;
                 true -> N * FA(N-1)
              end
          end
     end,
   y(F).

test_factorial_abuse_2() ->
    F = mk_fact(),
    720 = F(6),
    ok.

get_cancer_factorial() ->
    %% Abuse combinators xD
    %% If this monstrosity properly evaluates then lambdas are handled properly
    Y = fun(X) -> F = fun (P) -> X(fun (Arg) -> (P(P))(Arg) end) end, F(F) end,
    S = fun(F, G, X) -> F(X, G(X)) end,
    K = fun(X, Y) -> X end,
    B = fun(F, G, X) -> F(G(X)) end,
    Cond = fun(P, F, G, X) -> case P(X) of true -> F(X); false -> G(X) end end,
    Y(
        fun(FA) ->
            fun(X) ->
                Cond(
                    fun(X) -> X==0 end,
                    fun(X) -> K(1, X) end,
                    fun(X) ->
                        S(
                            fun(X,Y) ->
                                (fun(X,Y) ->
                                    (K(fun() ->
                                        X*Y end, FA)
                                    )() end)(Y,X)
                            end,
                            fun(X) ->
                                B(FA,
                                    fun(X) ->
                                        (fun (X) ->
                                            B(fun(X) ->
                                                X-1
                                              end, fun (X) -> X end, X)
                                         end)(X)
                                    end, X)
                            end, X)
                    end, X)
            end
        end).

test_factorial_abuse_3() ->
    Fac = get_cancer_factorial(),
    1 = Fac(1),
    2 = Fac(2),
    720 = Fac(6),
    5040 = Fac(7),
    40320 = Fac(8),
    ok.

test_factorial_comp() ->
    [true = ((get_cancer_factorial())(X) =:= (mk_fact())(X)) || X <- lists:seq(1,20)],
    ok.

test_apply_and_make_fun() ->
    A = lists,
    B = seq,
    C = [1,10],
    [1,2,3,4,5,6,7,8,9,10] = apply(A, B, C),
    [1,2,3,4,5,6,7,8,9,10] = apply(fun A:B/2, C),
    D = erlang:make_fun(A,B,2),
    [1,2,3,4,5,6,7,8,9,10] = apply(D, C),
    [1,2,3,4,5,6,7,8,9,10] = D(1,10),
    ok.

test_apply_exceptions() ->
    try
        erlang:apply(fun(_) -> ok end, []),
        1=2
    catch
        error:{badarity, _} ->
            ok
    end,
    try
        erlang:apply(a,b,[]),
        1=2
    catch
        error:undef ->
            ok
    end,
    try
        (erlang:make_fun(a,b,3))(1,2,3,4),
        1=2
    catch
        error:{badarity, _} ->
            ok
    end,
    try
        (erlang:make_fun(a,b,3))(1,2,3),
        1=2
    catch
        error:undef ->
            ok
    end,
    ok.

test_local_rec_1() ->
    (fun F(0) -> ok;
         F(X) when is_integer(X) ->
             case F(X - 1) of
                 ok -> ok;
                 _ -> bad
             end;
         F(_) -> bad
     end
    )(10).


test_local_rec_2() ->
    (fun F(X) when X > 0 ->
             F(X - 1);
         F(F) ->
             case F of
                 0 -> ok;
                 _ -> bad
             end
     end
    )(10).

test_local_rec_3() ->
    F = the_worst,
    (fun F(F) when is_function(F) ->
             F(F(ok));
         F(F) when F == ok ->
             ok;
         F(_) ->
             F(F)
     end
    )(bawimy_sie).

test_local_tailrec_1() ->
    Go = fun Go([H|T]) ->
                 Go(T);
             Go(Go) ->
                 Go
         end,
    case Go([Go, Go, Go, Go]) of
        [] ->
            ok;
        _ ->
            bad
    end.

test_local_tailrec_2() ->
    Go = fun Go([H|T]) ->
                 Go(T);
             Go(Go) ->
                 ok
         end,
   Go(lists:seq(1, 1000000)).

test_local_rec_scoping_1() ->
    F = fun F(a) ->
                F(b);
            F(b) ->
                H = fun F(a) -> F(b);
                        F(b) -> F(ok);
                        F(F) -> F
                    end,
                H(a);
            F(F) ->
                ok
        end,
    F(a).

test_local_rec_scoping_2() ->
    F = fun F(a) ->
                F({F, b});
            F({G, b}) ->
                H = fun F(a) -> F(b);
                        F(b) -> F(c);
                        F(F) -> F
                    end,
                G(H(a));
            F(F) ->
                ok
        end,
    F(a).
