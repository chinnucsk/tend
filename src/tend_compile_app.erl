-module(tend_compile_app).

-export([compile/1,
         add_codepath/1
        ]).

%% @doc Takes a path to an app, it tries to determine which build
%%      type the app uses and calls it.  The supported build
%%      types in the order they are checked:
%%      Makefile
%%      rebar
%%      Emakefile
-spec compile(file:name()) -> ok | {error, {unknown_compile_type, file:name()}}.
compile(App) ->
    io:format("Compiling app in ~s~n", [App]),
    case compile_type(App) of
        makefile ->
            [chmod_rebar(filename:join(App, "rebar"))
             || filelib:is_file(filename:join(App, "rebar"))],
            run_cmd(App, "make");
        rebar ->
            chmod_rebar(filename:join(App, "rebar")),
            run_cmd(App, "./rebar get-deps"),
            run_cmd(App, "./rebar compile");
        emakefile ->
            run_cmd(App, "erl -make");
        unknown ->
            {error, {unknown_compile_type, App}}
    end.

add_codepath(App) ->
    lists:foreach(fun code:add_pathz/1, find_ebins(App)),
    ok.


compile_type(App) ->
    is_makefile(App).

is_makefile(App) ->
    case filelib:is_file(filename:join(App, "Makefile")) of
        true  -> makefile;
        false -> is_rebar(App)
    end.

is_rebar(App) ->
    case filelib:is_file(filename:join(App, "rebar")) of
        true  -> rebar;
        false -> is_emakefile(App)
    end.

is_emakefile(App) ->
    case filelib:is_file(filename:join(App, "Emakefile")) of
        true  -> emakefile;
        false -> unknown
    end.


run_cmd(Cwd, Cmd) ->
    Port = erlang:open_port({spawn, Cmd},
                            [{cd, Cwd}, {line, 1000000}, exit_status]),
    ok   = wait_for_exit(Port).

wait_for_exit(Port) ->
    receive
        {Port, {exit_status, 0}} ->
            ok;
        {Port, {exit_status, _}} ->
            error;
        {Port, _} ->
            wait_for_exit(Port)
    end.

chmod_rebar(Rebar) ->
    os:cmd("chmod +x " ++ Rebar).

find_ebins(App) ->
    string:tokens(os:cmd("find " ++ App ++ " -name ebin"), "\n").
