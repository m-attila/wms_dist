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
         load_config/1]).

%% =============================================================================
%% API functions
%% =============================================================================

%% -----------------------------------------------------------------------------
%% Configuration values
%% -----------------------------------------------------------------------------
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