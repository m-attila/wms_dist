%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, OTP Bank Nyrt.
%%% @doc
%%% API module
%%% @end
%%% Created : 01. May 2019 16:31
%%%-------------------------------------------------------------------
-module(wms_dist).
-author("Attila Makra").

-include("wms_dist.hrl").

%% API
-export([get_dst_nodes/1,
         set_dst_node_enabled/2,
         get_configured_nodes/0,
         load_config/0,
         call/3,
         call/4, get_actors/0, is_cluster_connected/0, is_all_node_connected/0]).

%% =============================================================================
%% API functions
%% =============================================================================

%% -----------------------------------------------------------------------------
%% Configuration values
%% -----------------------------------------------------------------------------

-spec load_config() ->
  ok.
load_config() ->
  load_config(wms_cfg:get(?APP_NAME, load_config, true)).

-spec load_config(boolean()) ->
  ok.
load_config(true) ->
  Path = filename:join(code:priv_dir(?APP_NAME), "wms_dist.config"),
  ok = wms_cfg:load_config(wms_cfg:get_mode(), [Path]);
load_config(_) ->
  ok.

-spec get_configured_nodes() ->
  [node()].
get_configured_nodes() ->
  wms_cfg:get(?APP_NAME, nodes, []).

%% -----------------------------------------------------------------------------
%% Distribution functions
%% -----------------------------------------------------------------------------

-spec get_dst_nodes(all | connected) ->
  [node()].
get_dst_nodes(Type) ->
  wms_dist_cluster_handler:get_nodes(Type).

-spec set_dst_node_enabled(node(), boolean()) ->
  ok.
set_dst_node_enabled(Node, Enable) ->
  wms_dist_cluster_handler:set_enabled(Node, Enable).

-spec is_cluster_connected() ->
  boolean().
is_cluster_connected() ->
  wms_dist_cluster_handler:is_cluster_connected().

-spec is_all_node_connected() ->
  boolean().
is_all_node_connected() ->
  wms_dist_cluster_handler:is_all_node_connected().

%% -----------------------------------------------------------------------------
%% Actor functions
%% -----------------------------------------------------------------------------

-spec call(atom(), atom(), [term()]) ->
  {error, {actor_error, Class :: atom(), Reason :: term(), Stack :: term()}} |
  {error, {not_available, atom(), Replies :: term()}} |
  {error, {invalid_reply, atom(), term}} |
  term().
call(ActorModule, Function, Arguments) ->
  Timeout = wms_cfg:get(?APP_NAME, actor_call_timeout, ?ACTOR_CALL_TIMEOUT_MSEC),
  call(ActorModule, Function, Arguments, Timeout).

-spec call(atom(), atom(), [term()], pos_integer()) ->
  term().
call(ActorModule, Function, Arguments, TimeoutMsec) ->
  case wms_dist_cluster_handler:multi_call(ActorModule, Function,
                                           Arguments, TimeoutMsec) of
    {ok, Reply} ->
      Reply;
    Other ->
      Other
  end.
-spec get_actors() ->
  {ok, [{node(), [atom()]}]} | {error, term()}.
get_actors() ->
  wms_dist_cluster_handler:multi_get_actors(?ACTOR_CALL_TIMEOUT_MSEC).
