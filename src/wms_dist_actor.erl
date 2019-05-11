%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, OTP Bank Nyrt.
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
  actor_module :: atom()
}).

-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(ActorModule :: atom()) ->
  {ok, pid()} | ignore | {error, {already_started, pid()} | term()}.
start_link(ActorModule) ->
  gen_server:start_link(?MODULE, ActorModule, []).

-spec forward(pid(), {pid(), term()}, atom(), [term()]) ->
  ok.
forward(Pid, From, Function, Arguments) ->
  gen_server:cast(Pid,
                  {From, Function, Arguments}).

%% =============================================================================
%% get_server behaviour
%% =============================================================================

-spec init(Args :: term()) ->
  {ok, State :: state()} | {stop, term()}.
init(ActorModule) ->
  case global:set_lock({ActorModule, self()}, [node() | nodes()], 1) of
    true ->
      register(ActorModule);
    false ->
      ?debug("~p module already registered", [ActorModule]),
      {stop, {error, already_registered}}
  end.

-spec register(atom()) ->
  {ok, state()} | {stop, term()}.
register(ActorModule) ->
  case global:register_name(ActorModule, self()) of
    yes ->
      global:sync(),
      ?info("~p module successfull registered on node ~p", [ActorModule, node()]),
      {ok, #state{actor_module = ActorModule}};
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
            #state{actor_module = ActorModule} = State) ->
  Reply =
    try
      apply(ActorModule, Function, Arguments)
    catch
      St:C:R ->
        {error, {actor_error, C, R, St}}
    end,
    gen_server:reply(OriginalCaller, Reply),
{noreply, State}.

-spec terminate(Reason :: (normal | shutdown | {shutdown, term()} |
term()),
                State :: term()) ->
                 term().
terminate(Reason, #state{actor_module = ActorModule}) ->
  ?info("~p module terminated with reason ~p on node ~p", [ActorModule,
                                                           Reason, node()]),
  ok.
