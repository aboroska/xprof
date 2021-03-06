-module(xprof_ms_tests).

-include_lib("eunit/include/eunit.hrl").

-define(M, xprof_ms).
-define(DEFAULT_MS, {[{'_', [], [{return_trace}, {message, arity}]}],
                     [{'_', [], [{return_trace}, {message, '$_'}]}]}).

tokens_test_() ->
    [?_assertEqual(
        {error,"expression is not an xprof match-spec fun []"},
        ?M:fun2ms("")),
     ?_assertEqual(
        {error,"unterminated atom starting with 'true' at column 16"},
        ?M:fun2ms("m:f(_) -> 'true")),
     ?_assertMatch(
        {error,"expression is not an xprof match-spec fun" ++ _},
        ?M:fun2ms("a+b"))
    ].

parse_test_() ->
    [?_assertEqual(
        {ok, {{m, f, 1}, ?DEFAULT_MS}},
        ?M:fun2ms("m:f/1")),
     ?_assertEqual(
        {error,"syntax error before: '->' at column 4"},
        ?M:fun2ms("m:f(")),
     ?_assertEqual(
        {error,"syntax error before: '.' at column 16"},
        ?M:fun2ms("m:f() -> begin true")),
     ?_assertEqual(
        {error,"expression is not an xprof match-spec fun"},
        ?M:fun2ms("m:f f/1, case T of true"))
    ].

ensure_dot_test_() ->
    MSs = {[{['_'],[],[{return_trace},{message,arity},true]}],
           [{['_'],[],[{return_trace},{message,'$_'},true]}]},
    [?_assertEqual(
        {ok, {{m, f, 1}, MSs}},
        ?M:fun2ms("m:f(_) -> true")),
     ?_assertEqual(
        {ok, {{m, f, 1}, MSs}},
        ?M:fun2ms("m:f(_) -> true.")),
     ?_assertEqual(
        {ok, {{m, f, 1}, MSs}},
        ?M:fun2ms("m:f(_) -> true end."))
    ].

ensure_body_test_() ->
    MS = fun(Args, Guards) ->
                 {[{Args,Guards,[{return_trace},{message,arity},true]}],
                  [{Args,Guards,[{return_trace},{message,'$_'},true]}]
                 }
         end,
    [?_assertEqual(
        {error,"syntax error before: '->' at column 5"},
        ?M:fun2ms("m:f -> true")),
     ?_assertEqual(
        {error,"syntax error before: '->' at column 7"},
        ?M:fun2ms("m:f ( -> true")),
     ?_assertEqual(
        {error,"syntax error before: 'end' at column 19"},
        ?M:fun2ms("m:f (a) -> true;(_)")),
     ?_assertEqual(
        {ok, {{m, f, 1}, MS(['_'], [])}},
        ?M:fun2ms("m:f(_)")),
     ?_assertEqual(
        {ok, {{m, f, 1}, MS(['$1'], [{'>','$1',1}])}},
        ?M:fun2ms("m:f(A) when A > 1"))
    ].

ms_test_() ->
    [?_assertEqual(
       {error,
        "in fun head, only matching (=) on toplevel can be translated "
        "into match_spec at column 7"},
        ?M:fun2ms("m:f(A = {B, _}) -> {A, B}")),
     ?_assertEqual(
        {ok, {{m, f, 0},
              {[{[],[],[{return_trace},{message,arity},true]}],
               [{[],[],[{return_trace},{message,'$_'},true]}]}}},
        ?M:fun2ms("m:f() -> true"))
    ].

traverse_ms_test_() ->
    MSs =
    {%% capture args off
      [%% false -> false: no trace
       {[a,'_'], [], [{return_trace},{message,arity},{message,false}]},
       %% true -> arity: trace without args
       {[b,'_'], [], [{return_trace},{message,arity},{message,arity}]},
       %% custom msg -> arity: trace without args
       {['_','$1'], [], [{return_trace},{message,arity},{message,arity}]}],
      %% capture args on
      [%% false -> false: no trace
       {[a,'_'], [], [{return_trace},{message,'$_'},{message,false}]},
       %% true -> '$_' aka object(): trace with all args
       {[b,'_'], [], [{return_trace},{message,'$_'},{message,'$_'}]},
       %% custom msg -> custom msg: trace with one arg only
       {['_','$1'], [], [{return_trace},{message,'$_'},{message,'$1'}]}]},

    [?_assertEqual(
        {ok, {{m, f, 2}, MSs}},
        ?M:fun2ms("m:f(a, _) -> message(false);"
                  "   (b, _) -> message(true);"
                  "   (_, C) -> message(C) end."))
    ].

fun2ms_elixir_test_() ->
    Tests =
        {setup,
         fun() -> xprof_lib:set_mode(elixir) end,
         fun(_) -> application:unset_env(xprof, mode) end,
         [?_assertEqual(elixir, xprof_lib:get_mode()),
          ?_assertEqual({ok, {{'Elixir.Mod','fun',1}, ?DEFAULT_MS}},
                        ?M:fun2ms("Mod.fun/1")),
          ?_assertMatch({ok, {{'Elixir.Mod','fun',0},
                              {[{[], [], _}], [{[], [], _}]}}},
                        ?M:fun2ms("Mod.fun")),
          ?_assertMatch({ok,
                         {{'Elixir.Mod','fun',2},
                          {[{[data, '_'], [], _}], [{[data, '_'], [], _}]}
                         }},
                        ?M:fun2ms("Mod.fun(:data, _)")),
          ?_assertMatch({ok,
                         {{'Elixir.Mod','fun',2},
                          {[{[data,'$1'], [{'>','$1',1}], _}],
                           [{[data,'$1'], [{'>','$1',1}], _}]}
                         }},
                        ?M:fun2ms("Mod.fun(:data, a) when a > 1")),
          %% bug in Elixir up to 1.4.2
          %% https://github.com/elixir-lang/elixir/issues/5799
          %% ?_assertMatch({ok, {{'Elixir.Mod','fun',0},
          %%                     {[{[], [{'>',2,1}], _}], _}}},
          %%               ?M:fun2ms("Mod.fun() when 2 > 1")),

          %% full match-spec funs containing "->"
          ?_assertMatch({ok,
                         {{'Elixir.Mod','fun',0},
                          {[{[], [], _}],
                           [{[],[],
                             [{return_trace},{message,'$_'},{message,data}]}]}
                         }},
                        ?M:fun2ms("Mod.fun() -> message(:data)")),
          ?_assertMatch({ok,
                         {{'Elixir.Mod','fun',0},
                          {[{[], [], _}],
                           [{[],[],
                             [{return_trace},{message,'$_'},{message,data}]}]}
                         }},
                        ?M:fun2ms("Mod.fun -> message(:data)")),
          %% bug in Elixir up to 1.4.2
          %% https://github.com/elixir-lang/elixir/issues/5799
          %% ?_assertMatch({ok,
          %%                {{'Elixir.Mod','fun',
          %%                  {[{[], [{'>',2,1}], _}], _}}
          %%                }},
          %%               ?M:fun2ms("Mod.fun() when 2 > 1 -> true")),
          ?_assertMatch({ok,
                         {{'Elixir.Mod','fun',2},
                          {[{[data,'$1'], [{'>','$1',1}], _}],
                           [{[data,'$1'], [{'>','$1',1}],
                             [{return_trace},{message,'$_'},{message,'$1'}]}]}
                         }},
                        ?M:fun2ms("Mod.fun(:data, a) when a > 1 -> message(a)"))
         ]},
    xprof_test_lib:run_elixir_unit_tests(Tests).
