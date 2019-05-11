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
-export([get_node/0,
         add/2]).

get_node() ->
  node().

add(X, Y) ->
  {node(), X + Y}.
