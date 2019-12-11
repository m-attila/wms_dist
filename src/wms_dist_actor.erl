%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, Attila Makra.
%%% @doc
%%% Actor module for wms_dis
%%% @end
%%% Created : 10. May 2019 11:35
%%%-------------------------------------------------------------------
-module(wms_dist_actor).
-author("Attila Makra").

-behaviour(gen_server).

-export([start_link/1, forward/4]).

-export([init/1,
         handle_info/2,
         handle_call/3,
         handle_cast/2,
         terminate/2]).

-include_lib("wms_logger/include/wms_logger.hrl").

-define(RETRIES, 5).

%% =============================================================================
%% State
%% =============================================================================
-record(state, {
  actor_module :: atom(),
  actors_state :: term()
}).

-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(ActorModule :: atom()) ->
  {ok, pid()} | ignore | {error, already_registered | term()}.
start_link(ActorModule) ->
  Ret = gen_server:start_link(?MODULE, ActorModule, []),
  ?info("started"),
  Ret.

-spec forward(pid(), {pid(), term()}, atom(), [term()]) ->
  ok.
forward(Pid, From, Function, Arguments) ->
  gen_server:cast(Pid,
                  {From, Function, Arguments}).

%% =============================================================================
%% get_server behaviour
%% =============================================================================

-spec init(ActorModule :: module()) ->
  {ok, State :: state()} | {stop, term()}.
init(ActorModule) ->
  init(ActorModule, is_actor_module_exist(ActorModule)).

-spec init(module(), boolean()) ->
  {ok, State :: state()} | {stop, term()}.
init(_, false) ->
  {stop, not_found};
init(ActorModule, true) ->
  case global:set_lock({ActorModule, self()}, [node() | nodes()], 1) of
    true ->
      register(ActorModule);
    false ->
      ?debug("~p module already registered", [ActorModule]),
      {stop, already_registered}
  end.

-spec register(atom()) ->
  {ok, state()} | {stop, term()}.
register(ActorModule) ->
  case global:register_name(ActorModule, self()) of
    yes ->
      global:sync(),
      ?info("~p module successfull registered on node ~p", [ActorModule, node()]),
      {ok, #state{actor_module = ActorModule,
                  actors_state = init_actor(ActorModule)}};
    _ ->
      ?debug("~ module already registered", [ActorModule]),
      {stop, {error, already_registered}}
  end.

-spec handle_info(Info :: any(), State :: state()) ->
  {noreply, State :: state()}.
handle_info(_Msg, State) ->
  {noreply, State}.

-spec handle_call(Info :: any(), From :: {pid(), term()}, State :: state())
                 ->
                   {reply, term(), State :: state()}.
handle_call(_, _From, State) ->
  {reply, ok, State}.

-spec handle_cast(Request :: any(), State :: state())
                 ->
                   {noreply, State :: state()}.
handle_cast({OriginalCaller, Function, Arguments},
            #state{actor_module = ActorModule,
                   actors_state = ActorState} = State) ->
  {NewActorState, Reply} =
    try
      call_actor_function(ActorModule, Function, ActorState, Arguments)
    catch
      St:C:R ->
        ?error("DIS-0001", "Actor function call was failed: ~s ~s ~0p",
               [ActorModule, Function, R]),
        {ActorState, {error, {actor_error, C, R, St}}}
    end,
  gen_server:reply(OriginalCaller, Reply),
  {noreply, State#state{actors_state = NewActorState}}.

call_actor_function(ActorModule, Function, ActorState, Arguments) ->
  apply(ActorModule,
        Function,
        [ActorState | Arguments]).

-spec terminate(Reason :: (normal | shutdown | {shutdown, term()} |
term()),
                State :: term()) ->
                 term().
terminate(Reason, #state{actor_module = ActorModule}) ->
  ?info("~p module terminated with reason ~p on node ~p", [ActorModule,
                                                           Reason, node()]),
  ok.


-spec init_actor(atom()) ->
  term().
init_actor(ActorModule) ->
  case lists:member({init, 0}, apply(ActorModule, module_info, [exports])) of
    true ->
      apply(ActorModule, init, []);
    false ->
      #{}
  end.

-spec is_actor_module_exist(module()) ->
  boolean().
is_actor_module_exist(ActorModule) ->
  code:which(ActorModule) =/= non_existing.