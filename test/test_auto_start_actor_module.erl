%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, OTP Bank Nyrt.
%%% @doc
%%%
%%% @end
%%% Created : 30. Oct 2019 04:40
%%%-------------------------------------------------------------------
-module(test_auto_start_actor_module).
-author("Attila Makra").

-include_lib("wms_logger/include/wms_logger.hrl").

%% API
-export([init/0,
         add/3,
         crash/1]).

% Initialize auto-starting actor
init() ->
  #{initialized => true}.

% simple test function to add two numbers
add(#{initialized := true} = State, A, B) ->
  {State, A + B}.

% test function for crashing actor
crash(_State) ->
  exit(self(), kill).