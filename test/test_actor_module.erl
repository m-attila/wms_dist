%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, OTP Bank Nyrt.
%%% @doc
%%%
%%% @end
%%% Created : 10. May 2019 13:23
%%%-------------------------------------------------------------------
-module(test_actor_module).
-author("Attila Makra").

%% API
-export([get_node/1,
         add/3,
         init/0,
         inc/1]).

init() ->
  #{counter => 1}.

get_node(State) ->
  {State, node()}.

add(State, X, Y) ->
  {State, {node(), X + Y}}.

inc(#{counter := Counter} = State) ->
  {State#{counter := Counter + 1}, Counter + 1}.

