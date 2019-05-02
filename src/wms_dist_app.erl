%%%-------------------------------------------------------------------
%% @doc wms_dist public API
%% @end
%%%-------------------------------------------------------------------

-module(wms_dist_app).

-include("wms_dist.hrl").

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================
-spec start(Type :: application:start_type(), Args :: term()) ->
  {ok, Pid :: pid()} |
  {error, Reason :: term()}.
start(_StartType, []) ->
  wms_dist:load_config(wms_cfg:get(?APP_NAME, load_config, true)),
  wms_dist_sup:start_link().

%%--------------------------------------------------------------------
-spec stop(State :: term()) ->
  ok.
stop(_State) ->
  ok.

%%====================================================================
%% Internal functions
%%====================================================================

