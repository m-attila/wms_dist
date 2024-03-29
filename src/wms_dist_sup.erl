%%%-------------------------------------------------------------------
%% @doc wms_dist top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(wms_dist_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================
-spec start_link() ->
  supervisor:startlink_ret().
start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: #{id => Id, start => {M, F, A}}
%% Optional keys are restart, shutdown, type, modules.
%% Before OTP 18 tuples must be used to specify a child. e.g.
%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
-spec init(Args :: term()) ->
  {ok, {SupFlags :: supervisor:sup_flags(), [ChildSpec :: supervisor:child_spec()]}}
  | ignore.
init([]) ->
  ChildSpecs = [#{id => wms_dist_cluster_handler,
                  start => {wms_dist_cluster_handler, start_link, []}
                }
               ],
  SupFlags = #{strategy => one_for_one,
               intensity => 1,
               period => 1
             },
  {ok, {SupFlags, ChildSpecs}}.

%%====================================================================
%% Internal functions
%%====================================================================
