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
-export([get_cfg_mode/0,
         get_cfg_mode_config/0,
         get_cfg_config/2,
         get_cfg_nodes/0,
         get_dst_nodes/1,
         set_dst_node_enabled/2]).

%% =============================================================================
%% API functions
%% =============================================================================

%% -----------------------------------------------------------------------------
%% Config functions
%% -----------------------------------------------------------------------------

-spec get_cfg_mode() ->
  atom().
get_cfg_mode() ->
  env(mode).

-spec get_cfg_mode_config() ->
  term().
get_cfg_mode_config() ->
  env(get_cfg_mode()).

-spec get_cfg_config(term() | [term()], term()) ->
  term().
get_cfg_config(Keys, Default) ->
  wms_common:get_proplist_value(get_cfg_mode_config(), Keys, Default).

-spec get_cfg_nodes() ->
  [node()].
get_cfg_nodes() ->
  get_cfg_config(nodes, undefined).

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

%% =============================================================================
%% Private functions
%% =============================================================================
env(Key) ->
  {ok, Value} = application:get_env(?APP_NAME, Key),
  Value.