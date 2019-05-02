%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, OTP Bank Nyrt.
%%% @doc
%%% Supervise configured node connections.
%%% @end
%%% Created : 01. May 2019 17:13
%%%-------------------------------------------------------------------
-module(wms_dist_cluster_handler).
-author("Attila Makra").
-behaviour(gen_server).

%% API
-export([start_link/0,
         get_nodes/1,
         set_enabled/2]).

-export([init/1, handle_info/2,
         handle_call/3, handle_cast/2]).
-define(INACTIVE_NODE_CHECK_TIMEOUT_MSEC, 1000).

%% =============================================================================
%% State
%% =============================================================================
-type node_status() :: disconnected | connected | down | disabled.
-type node_info() :: {node(), node_status()}.
-record(state, {
  configured_nodes :: [node()],
  node_states :: [node_info()]
}).
-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() ->
  {ok, pid()} | ignore | {error, {already_started, pid()} | term()}.
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec get_nodes(connected | all) ->
  [node()].
get_nodes(connected) ->
  gen_server:call(?MODULE, {get_nodes, connected});
get_nodes(all) ->
  gen_server:call(?MODULE, {get_nodes, all}).

-spec set_enabled(atom(), boolean()) ->
  ok.
set_enabled(Node, Enable) ->
  gen_server:call(?MODULE, {set_enabled, Node, Enable}).

%% =============================================================================
%% get_server behaviour
%% =============================================================================

-spec init(Args :: term()) ->
  {ok, State :: state()}.
init(_) ->
  net_kernel:monitor_nodes(true),
  Nodes = wms_dist:get_cfg_nodes(),
  self() ! check_nodes,

  {ok, #state{configured_nodes = Nodes,
              node_states      = [{disconnected, Node} || Node <- Nodes]}}.

-spec handle_info(Info :: any(), State :: state()) ->
  {noreply, State :: state()}.
handle_info(check_nodes, #state{node_states = NodeStates} = State) ->
  erlang:send_after(?INACTIVE_NODE_CHECK_TIMEOUT_MSEC, self(), check_nodes),
  NewNodeStates = handle_nodes(NodeStates, []),
  {noreply, State#state{node_states = NewNodeStates}};
handle_info({nodeup, _Node}, State) ->
  {noreply, State};
handle_info({nodedown, Node}, #state{node_states = NodeStates} = State) ->
  NewNodeStates = lists:map(
    fun({connected, NodeS}) when NodeS =:= Node ->
      {down, NodeS};
       (Other) ->
         Other
    end, NodeStates),

  {noreply, State#state{node_states = NewNodeStates}};
handle_info(_Msg, State) ->
  {noreply, State}.

-spec handle_call(Info :: any(), From :: {pid(), term()}, State :: state())
                 ->
                   {reply, term(), State :: state()}.
handle_call({get_nodes, connected}, _From,
            #state{node_states = NodeStates} = State) ->
  {reply,
    lists:filtermap(
      fun({connected, Node}) ->
        {true, Node};
         (_) ->
           false
      end, NodeStates), State};
handle_call({get_nodes, all}, _From,
            #state{configured_nodes = Nodes} = State) ->
  {reply, Nodes, State};
handle_call({set_enabled, Node, Enable}, _From,
            #state{node_states = NodeStates} = State) ->
  NewNodeStates = lists:map(
    fun({_, NodeS}) when Node =:= NodeS andalso not Enable ->
      net_kernel:disconnect(Node),
      {disabled, NodeS};
       ({disabled, NodeS}) when Node =:= NodeS andalso Enable ->
         {disconnected, NodeS};
       (Other) ->
         Other
    end,
    NodeStates),
  {reply, ok, State#state{node_states = NewNodeStates}}.

-spec handle_cast(Request :: any(), State :: state())
                 ->
                   {noreply, State :: state()}.
handle_cast(_, State) ->
  {noreply, State}.

%% =============================================================================
%% Private functions
%% =============================================================================

handle_nodes([], Accu) ->
  Accu;
handle_nodes([{disconnected, Node} | Rest], Accu) ->
  handle_nodes(Rest, [{connect_node(Node), Node} | Accu]);
handle_nodes([{connected, _} = Connected | Rest], Accu) ->
  handle_nodes(Rest, [Connected | Accu]);
handle_nodes([{down, Node} | Rest], Accu) ->
  handle_nodes(Rest, [{ping_node(Node), Node} | Accu]);
handle_nodes([Disabled | Rest], Accu) ->
  handle_nodes(Rest, [Disabled | Accu]).

-spec connect_node(node()) ->
  connected | disconnected.
connect_node(Node) ->
  connect_node(Node, node()).

-spec connect_node(node(), node()) ->
  connected | disconnected.
connect_node(Node, Node) ->
  connected;
connect_node(Node, _) ->
  case net_kernel:connect_node(Node) of
    true ->
      connected;
    false ->
      disconnected
  end.

-spec ping_node(node()) ->
  connected | down.
ping_node(Node) ->
  case net_adm:ping(Node) of
    pong ->
      connected;
    _ ->
      down
  end.
