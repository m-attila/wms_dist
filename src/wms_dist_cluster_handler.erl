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

-include("wms_dist.hrl").
-include_lib("wms_common/include/wms_common.hrl").
-include_lib("wms_logger/include/wms_logger.hrl").

%% API
-export([start_link/0,
         get_nodes/1,
         set_enabled/2,
         call/3,
         multi_call/4,
         get_actors/0,
         multi_get_actors/1,
         is_cluster_connected/0,
         wait_for_cluster_connected/1,
         wait_for_cluster_connected/0,
         is_all_node_connected/0,
         is_all_defined_node_connected/0]).

-export([init/1,
         handle_info/2,
         handle_call/3,
         handle_cast/2,
         call_server/2,
         process_async_call/2,
         multi_call_server/2]).

-define(INACTIVE_NODE_CHECKING_TIMEOUT, 1000).
-define(WAIT_FOR_CLUSTER_CONNECTED_TIMEOUT, 10000).

%% =============================================================================
%% State
%% =============================================================================
-type node_status() :: disconnected | connected | down | disabled.
-type node_info() :: {node_status(), node()}.
-type auto_start_actors() :: [module()].

-record(state, {
  configured_nodes :: [node()],
  node_states :: [node_info()],
  cluster_connected = false :: boolean(),
  cluster_connected_end :: timestamp(),
  actor_modules = #{} :: #{pid() := atom(), atom() := pid()},
  auto_start_actors = [] :: auto_start_actors()
}).
-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() ->
  {ok, pid()} | ignore | {error, {already_started, pid()} | term()}.
start_link() ->
  Ret = gen_server:start_link({local, ?MODULE}, ?MODULE, [], []),
  ?info("started"),
  Ret.

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% get_nodes/1
%% ###### Purpose
%% Returns all defined or connected nodes
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end

-spec get_nodes(connected | all) ->
  [node()].
get_nodes(connected) ->
  gen_server:call(?MODULE, {get_nodes, connected});
get_nodes(all) ->
  gen_server:call(?MODULE, {get_nodes, all}).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% set_enable/2
%% ###### Purpose
%% Enable or disable node. If disabled reconnecting mechanism does not
%% work for it.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec set_enabled(atom(), boolean()) ->
  ok.
set_enabled(Node, Enable) ->
  gen_server:call(?MODULE, {set_enabled, Node, Enable}).


%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% call/4
%% ###### Purpose
%% Call function on given actor module with arguments.
%% If actor is not registered in cluster, function failed.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end

-spec call(atom(), atom(), [term()]) ->
  term().
call(ActorModule, Function, Arguments) ->
  call_server(false, {call, ActorModule, Function, Arguments, false}).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% get_actors/0
%% ###### Purpose
%% Returns registered actors on current node.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec get_actors() ->
  {node(), [atom()]}.
get_actors() ->
  call_server(false, get_actors).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% call_server/2
%% ###### Purpose
%% Calls synchron on asyncron command on current node.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec call_server(boolean(), term()) ->
  term().
call_server(Synch, Command) ->
  gen_server:call(?MODULE, {Synch, Command}).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% is_cluster_connected/0
%% ###### Purpose
%% Returns cluster is connected within given timeout.
%% If wait_for_cluster_connected_timeout expired, it sets true.
%% If node goes down, restart timeout for building cluster.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec is_cluster_connected() ->
  boolean().
is_cluster_connected() ->
  gen_server:call(?MODULE, is_cluster_connected).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% is_all_node_connected/0
%% ###### Purpose
%% Returns if all nodes are connected (disabled nodes will be ignored).
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec is_all_node_connected() ->
  boolean().
is_all_node_connected() ->
  gen_server:call(?MODULE, is_all_node_connected).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% is_all_node_connected/0
%% ###### Purpose
%% Returns if all configured nodes are connected (disabled not ignored).
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec is_all_defined_node_connected() ->
  boolean().
is_all_defined_node_connected() ->
  gen_server:call(?MODULE, is_all_defined_node_connected).


%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% wait_for_cluster_connected/1
%% ###### Purpose
%% Wait for all node connected within given timeout.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec wait_for_cluster_connected() ->
  boolean().
wait_for_cluster_connected() ->
  wait_for_cluster_connected(
    wms_cfg:get(?APP_NAME,
                wait_for_cluster_connected_timeout,
                ?WAIT_FOR_CLUSTER_CONNECTED_TIMEOUT)).

-spec wait_for_cluster_connected(pos_integer()) ->
  boolean().
wait_for_cluster_connected(TimeoutMsec) when TimeoutMsec =< 0 ->
  false;
wait_for_cluster_connected(TimeoutMsec) ->
  case is_cluster_connected() of
    false ->
      timer:sleep(100),
      wait_for_cluster_connected(TimeoutMsec - 100);
    true ->
      true
  end.


%% -----------------------------------------------------------------------------
%% Multi calls
%% -----------------------------------------------------------------------------

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% multi_call_server/2
%% ###### Purpose
%% Calls synchron on asyncron command on all connected nodes.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end
-spec multi_call_server(term(), pos_integer()) ->
  term().
multi_call_server(Command, Timeout) ->
  rpc:multicall(wms_dist:get_dst_nodes(connected),
                ?MODULE,
                call_server,
                [false, Command], Timeout).

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% multi_call/4
%% ###### Purpose
%% Execute function call on this node, where ActorModule is registered.
%% If actor not registered yet, call all nodes to register it, then
%% call asynchron command where registration was successed.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end

-spec multi_call(atom(), atom(), [term()], pos_integer()) ->
  {error, {not_available, atom(), Replies :: term()}} |
  {error, {invalid_reply, atom(), term}} |
  {error, term()} |
  {ok, term()}.
multi_call(ActorModule, Function, Arguments, Timeout) ->
  {Replies, _} =
    registered_name_call_server(ActorModule,
                                {call, ActorModule, Function, Arguments},
                                Timeout),

  filter_positive_replies(ActorModule, Replies, false).

-spec registered_name_call_server(atom(), term(), pos_integer()) ->
  term().
registered_name_call_server(Name, Command, Timeout) ->
  case global:whereis_name(Name) of
    undefined ->
      multi_call_server(Command, Timeout);
    Pid ->
      SingleReply = rpc:call(node(Pid),
                             ?MODULE,
                             call_server,
                             [false, Command], Timeout),
      {SingleReply, any}
  end.

%% @doc
%%
%%-------------------------------------------------------------------
%%
%% ### Function
%% multi_get_actors/1
%% ###### Purpose
%% Returns all registered actor modules in cluster.
%% ###### Arguments
%%
%% ###### Returns
%%
%%-------------------------------------------------------------------
%%
%% @end

-spec multi_get_actors(pos_integer()) ->
  {ok, [{node(), [atom()]}]} | {error, term()}.
multi_get_actors(Timeout) ->
  {Replies, _} =
    multi_call_server(get_actors, Timeout),

  filter_positive_replies(get_actors, Replies, true).

-spec filter_positive_replies(term(), term() | [term()], boolean()) ->
  {ok, term()} | {error, term()}.
filter_positive_replies(Identify, Replies, MoreRepliesEnabled)
  when is_list(Replies) ->
  Reply =
    lists:filtermap(
      fun(Reply) ->
        case Reply of
          {error, {failed_to_start, _, _}} ->
            false;
          {badrpc, _} ->
            false;
          Other ->
            {true, Other}
        end
      end, Replies),
  case Reply of
    [] ->
      {error, {not_available, Identify, Replies}};
    [R] ->
      {ok, R};
    Other when not MoreRepliesEnabled ->
      {error, {invalid_reply, Identify, Other}};
    Other ->
      Other
  end;
filter_positive_replies(Identify, {badrpc, Reason}, _) ->
  {error, {not_available, Identify, Reason}};
filter_positive_replies(_, Reply, _) ->
  {ok, Reply}.


%% =============================================================================
%% get_server behaviour
%% =============================================================================

-spec init(Args :: term()) ->
  {ok, State :: state()}.
init(_) ->
  process_flag(trap_exit, true),

  net_kernel:monitor_nodes(true),
  Nodes = wms_dist:get_configured_nodes(),

  self() ! check_nodes,


  {ok, #state{configured_nodes      = Nodes,
              cluster_connected_end = wait_for_cluster_expired(),
              auto_start_actors     = wms_cfg:get(?APP_NAME, auto_start_actors, []),
              node_states           = [{disconnected, Node} || Node <- Nodes]}}.

-spec wait_for_cluster_expired() ->
  timestamp().
wait_for_cluster_expired() ->
  Delay = {millisecond,
           wms_cfg:get(?APP_NAME,
                       wait_for_cluster_connected_timeout,
                       ?WAIT_FOR_CLUSTER_CONNECTED_TIMEOUT)},
  wms_common:add(wms_common:timestamp(), Delay).

-spec handle_info(Info :: any(), State :: state()) ->
  {noreply, State :: state()}.

%% -----------------------------------------------------------------------------
%% check nodes message
%% -----------------------------------------------------------------------------

handle_info(check_nodes, #state{node_states = NodeStates} = State) ->
  Delay = wms_cfg:get(?APP_NAME,
                      inactive_node_checking_timeout,
                      ?INACTIVE_NODE_CHECKING_TIMEOUT),
  erlang:send_after(Delay, self(), check_nodes),

  NewNodeStates = handle_nodes(NodeStates, []),
  NewState = check_cluster_connected(State#state{node_states = NewNodeStates}),

  {noreply, NewState};

%% -----------------------------------------------------------------------------
%% nodeup message
%% -----------------------------------------------------------------------------

handle_info({nodeup, _Node}, State) ->
  self() ! check_nodes,
  {noreply, State};

%% -----------------------------------------------------------------------------
%% nodedown message
%% -----------------------------------------------------------------------------

handle_info({nodedown, Node}, #state{node_states = NodeStates} = State) ->
  ?debug("Node down: ~p", [Node]),
  NewNodeStates = lists:map(
    fun({connected, NodeS}) when NodeS =:= Node ->
      {down, NodeS};
       (Other) ->
         Other
    end, NodeStates),

  NewState = State#state{node_states           = NewNodeStates,
                                cluster_connected     = false,
                                cluster_connected_end = wait_for_cluster_expired()},
  {noreply, auto_start_actors(NewState)};

%% -----------------------------------------------------------------------------
%% Process reply of asynchron call.
%% -----------------------------------------------------------------------------

handle_info({'EXIT', _, {async_reply, CallerPid, Reply}}, State) ->
  gen_server:reply(CallerPid, Reply),
  {noreply, State};

%% -----------------------------------------------------------------------------
%% Process actor exited signal.
%% -----------------------------------------------------------------------------

handle_info({'EXIT', Pid, _}, State) ->
  {noreply, actor_exited(Pid, State)};

%% -----------------------------------------------------------------------------
%% Any other messages was received.
%% -----------------------------------------------------------------------------

handle_info(Msg, State) ->
  ?warning("Unknown message was received: ~p", [Msg]),
  {noreply, State}.

-spec handle_call(Info :: any(), From :: {pid(), term()}, State :: state())
                 ->
                   {reply, term(), State :: state()}.

%% -----------------------------------------------------------------------------
%% Execute synchron or asynchron call with Command,
%% -----------------------------------------------------------------------------
handle_call({true, Command}, From, State) ->
  handle_call(Command, From, State);
handle_call({false, Command}, From, State) ->
  spawn_link(?MODULE, process_async_call, [From, Command]),
  {noreply, State};

%% -----------------------------------------------------------------------------
%% Process is_cluster_connected message.
%% -----------------------------------------------------------------------------

handle_call(is_cluster_connected, _From, #state{cluster_connected =
                                                Connected} = State) ->
  {reply, Connected, State};

%% -----------------------------------------------------------------------------
%% Process is_all_node_connected message.
%% -----------------------------------------------------------------------------

handle_call(is_all_node_connected, _From, State) ->
  {reply, is_all_node_connected(State), State};

%% -----------------------------------------------------------------------------
%% Process is_all_defined_node_connected message.
%% -----------------------------------------------------------------------------

handle_call(is_all_defined_node_connected, _From, State) ->
  {reply, is_all_defined_node_connected(State), State};

%% -----------------------------------------------------------------------------
%% Process get_nodes (connected, all) message.
%% -----------------------------------------------------------------------------

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

%% -----------------------------------------------------------------------------
%% Process set_enabled message.
%% -----------------------------------------------------------------------------

handle_call({set_enabled, Node, Enable}, _From,
            #state{node_states = NodeStates} = State) ->
  ?info("~p node enabled: ~p", [Node, Enable]),
  NewNodeStates = lists:map(
    fun
      ({_, NodeS}) when Node =:= NodeS andalso not Enable ->
        {disabled, NodeS};
      ({disabled, NodeS}) when Node =:= NodeS andalso Enable ->
        {disconnected, NodeS};
      (Other) ->
        Other
    end,
    NodeStates),
  {reply, ok, State#state{node_states = NewNodeStates}};

%% -----------------------------------------------------------------------------
%% Process local call for given actor module.
%% -----------------------------------------------------------------------------

handle_call({call, ActorModule, Function, Arguments},
            From, State) ->
  call_actor(ActorModule, Function, Arguments, From, State);

%% -----------------------------------------------------------------------------
%% Returns registered actor on current node.
%% -----------------------------------------------------------------------------

handle_call(get_actors, _From, State) ->
  {reply, {node(), get_available_actors(State)}, State}.

%% -----------------------------------------------------------------------------
%% cast message
%% -----------------------------------------------------------------------------
-spec handle_cast(Request :: any(), State :: state()) ->
  {noreply, State :: state()}.

handle_cast(_, State) ->
  {noreply, State}.

%% =============================================================================
%% Private functions
%% =============================================================================

%% -----------------------------------------------------------------------------
%% Node operations
%% -----------------------------------------------------------------------------

-spec handle_nodes([node_info()], [node_info()]) ->
  [node_info()].
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
      ?debug("Unable to connect node: ~p", [Node]),
      disconnected;
    ignored ->
      ?debug("Unable to connect node: ~p", [Node]),
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

-spec check_cluster_connected(state()) ->
  state().
check_cluster_connected(#state{cluster_connected = true} = State) ->
  State;
check_cluster_connected(#state{cluster_connected     = false,
                               cluster_connected_end = WhenEnd} = State) ->
  case is_all_node_connected(State) of
    true ->
      ?info("Cluster connected, because all node are connected."),
      auto_start_actors(State#state{cluster_connected = true});
    false ->
      case wms_common:compare(wms_common:timestamp(), WhenEnd) > 0 of
        true ->
          ?info("Cluster connected, because connecion timeout expired."),
          auto_start_actors(State#state{cluster_connected = true});
        false ->
          State
      end
  end.

%% -----------------------------------------------------------------------------
%% Actor operations
%% -----------------------------------------------------------------------------

% actor kilepett esemeny kerelese
-spec actor_exited(pid(), state()) ->
  state().
actor_exited(Pid, State) ->
  ?debug("Actor exited at pid: ~p", [Pid]),
  case is_auto_start_actor(get_actor_module(Pid, State), State) of
    true ->
      auto_start_actors(remove_actor(Pid, State));
    false ->
      remove_actor(Pid, State)
  end.

% megprobalja elinditani az auto startos actorokat

-spec auto_start_actors(state()) ->
  state().
auto_start_actors(#state{auto_start_actors = []} = State) ->
  State;
auto_start_actors(#state{auto_start_actors = Actors} = State) ->
  case is_node_connected(State) of
    true ->
      do_auto_start_actors(Actors, State);
    false ->
      State
end.

-spec do_auto_start_actors([module()], state()) ->
  state().
do_auto_start_actors([], State) ->
  State;
do_auto_start_actors([ActorModule | RestActors], State) ->
  do_auto_start_actors(ActorModule, RestActors,
                       get_actor_pid(ActorModule, State), State).

-spec do_auto_start_actors(module(), [module()], undefined | pid(), state()) ->
  state().
do_auto_start_actors(ActorModule, RestActors, undefined, State) ->
  NewState =
    case start_actor_module(ActorModule, true) of
      {ok, Pid} ->
        ?info("~s actor started automatically.", [ActorModule]),
        add_actor(Pid, ActorModule, State);
      {error, already_registered} ->
        State
    end,
  do_auto_start_actors(RestActors, NewState);
do_auto_start_actors(_ActorModule, _RestActors, _, State) ->
  % actor already started locally
  State.

-spec call_actor(atom(), atom(), [term()], {pid(), term()}, state()) ->
  {noreply, state()} | {reply, term(), state()}.
call_actor(ActorModule, Function, Arguments, From, State) ->
  call_actor(ActorModule, Function, Arguments, From, State,
             get_actor_pid(ActorModule, State), true).

-spec call_actor(atom(), atom(), [term()], {pid(), term()}, state(),
                 ActorPid :: pid() | undefined,
                 EnableStart :: boolean()) ->
                  {noreply, state()} | {reply, term(), state()}.

call_actor(ActorModule, Function, Arguments, From, State, undefined, EnableStart) ->
  try
    {ok, Pid} = start_actor_module(ActorModule, EnableStart),
    call_actor(ActorModule, Function, Arguments, From,
               add_actor(Pid, ActorModule, State), Pid, false)
  catch
    St:Cl:Reason ->
      ?debug("Unable to call actor ~p, ~p : ~p~n~p", [ActorModule, Cl, Reason, St]),
      {reply, {error, {failed_to_start, node(), ActorModule}}, State}
  end;
call_actor(ActorModule, Function, Arguments, From, State, Pid, EnableStart) ->
  try
    ok = wms_dist_actor:forward(Pid, From, Function, Arguments),
    {noreply, State}
  catch
    _:_ ->
      call_actor(ActorModule, Function, Arguments,
                 From, remove_actor(ActorModule, State), undefined, EnableStart)
  end.

-spec start_actor_module(atom(), EnableStart :: boolean()) ->
  {ok, pid()} | ignore | error | {error, already_registered | term()}.
start_actor_module(_ActorModule, false) ->
  error;
start_actor_module(ActorModule, true) ->
  wms_dist_actor:start_link(ActorModule).

-spec remove_actor(atom() | pid(), state()) ->
  state().
remove_actor(ModuleOrPid, #state{actor_modules = ActorModules} = State) ->
  NewActorModules =
    case maps:get(ModuleOrPid, ActorModules, undefined) of
      undefined ->
        ActorModules;
      Pair ->
        maps:remove(Pair, maps:remove(ModuleOrPid, ActorModules))
    end,
  State#state{actor_modules = NewActorModules}.

-spec add_actor(pid(), atom(), state()) ->
  state().
add_actor(ActorPid, ActorModule, #state{actor_modules = ActorModules} = State) ->
  State#state{actor_modules =
              ActorModules#{ActorPid => ActorModule,
                            ActorModule => ActorPid}}.

-spec get_actor_pid(atom(), state()) ->
  pid() | undefined.
get_actor_pid(ActorModule, #state{actor_modules = ActorModules}) ->
  maps:get(ActorModule, ActorModules, undefined).

-spec get_actor_module(pid(), state()) ->
  module() | undefined.
get_actor_module(Pid, #state{actor_modules = ActorModules}) ->
  maps:get(Pid, ActorModules, undefined).

-spec is_auto_start_actor(module(), state()) ->
  boolean().
is_auto_start_actor(ActorModule, #state{auto_start_actors = AutoActors}) ->
  lists:member(ActorModule, AutoActors).

-spec get_available_actors(state()) ->
  [atom()].
get_available_actors(#state{actor_modules = ActorModules}) ->
  maps:keys(
    maps:filter(
      fun(K, _V) ->
        is_atom(K)
      end, ActorModules)).

-spec is_all_node_connected(state()) ->
  boolean().
is_all_node_connected(#state{node_states = NodeStates}) ->
  not lists:any(
    fun({Status, _}) ->
      Status =/= connected
    end,
    lists:filter(
      fun({Status, _}) ->
        Status =/= disabled
      end, NodeStates)).

-spec is_all_defined_node_connected(state()) ->
  boolean().
is_all_defined_node_connected(#state{node_states = NodeStates}) ->
  not lists:any(
    fun({Status, _}) ->
      Status =/= connected
    end,
    NodeStates).

-spec is_node_connected(state()) ->
  boolean().
is_node_connected(#state{node_states = NodeStates}) ->
  lists:any(
    fun
      ({connected, Node}) when Node =:= node() ->
        true;
      (_) ->
        false
    end, NodeStates).
%% -----------------------------------------------------------------------------
%% Asynchron calls.
%% -----------------------------------------------------------------------------

-spec process_async_call(pid(), tuple()) ->
  any().
process_async_call(CallerPid, Command) ->
  Reply =
    try
      execute_call(Command)
    catch
      _:_ ->
        {error, {failed_to_start, node(), Command}}
    end,
  exit({async_reply, CallerPid, Reply}).

-spec execute_call(term()) ->
  term().
execute_call(Command) ->
  gen_server:call(?MODULE, Command).
