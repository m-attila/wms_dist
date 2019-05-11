%%%-------------------------------------------------------------------
%%% @author Attila Makra
%%% @copyright (C) 2019, OTP Bank Nyrt.
%%% @doc
%%% Test suites for wms_dist
%%% @end
%%% Created : 10. May 2019 12:42
%%%-------------------------------------------------------------------
-module(wms_dist_SUITE).
-author("Attila Makra").

-compile(nowarn_export_all).
-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("wms_logger/include/wms_logger.hrl").
-include("wms_dist.hrl").

-define(TEST_NODES, [t1, t2]).
-define(HOST(X), wms_common:add_host(X)).

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Function: suite() -> Info
%%
%% Info = [tuple()]
%%   List of key/value pairs.
%%
%% Description: Returns list of tuples to set default properties
%%              for the suite.
%%
%% Note: The suite/0 function is only meant to be used to return
%% default data values, not perform any other operations.
%%--------------------------------------------------------------------
suite() ->
  [{key, value}].

%%--------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the suite.
%%
%% Description: Initialization before the suite.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_suite(Config) ->
  [{key, value} | Config].

%%--------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> term() | {save_config,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%%
%% Description: Cleanup after the suite.
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
  ok.

%%--------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%% Reason = term()
%%   The reason for skipping all test cases and subgroups in the group.
%%
%% Description: Initialization before each test case group.
%%--------------------------------------------------------------------
init_per_group(GroupName, Config) ->
  ?MODULE:GroupName({prelude, Config}).

%%--------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%               term() | {save_config,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%%
%% Description: Cleanup after each test case group.
%%--------------------------------------------------------------------
end_per_group(GroupName, Config) ->
  ?MODULE:GroupName({postlude, Config}).

%%--------------------------------------------------------------------
%% Function: init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% TestCase = atom()
%%   Name of the test case that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%%
%% Description: Initialization before each test case.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_testcase(TestCase, Config) ->
  ?MODULE:TestCase({prelude, Config}).

%%--------------------------------------------------------------------
%% Function: end_per_testcase(TestCase, Config0) ->
%%               term() | {save_config,Config1} | {fail,Reason}
%%
%% TestCase = atom()
%%   Name of the test case that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for failing the test case.
%%
%% Description: Cleanup after each test case.
%%--------------------------------------------------------------------
end_per_testcase(TestCase, Config) ->
  ?MODULE:TestCase({postlude, Config}).

%%--------------------------------------------------------------------
%% Function: groups() -> [Group]
%%
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%%   The name of the group.
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%%   Group properties that may be combined.
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%%   The name of a test case.
%% Shuffle = shuffle | {shuffle,Seed}
%%   To get cases executed in random order.
%% Seed = {integer(),integer(),integer()}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%%   To get execution of cases repeated.
%% N = integer() | forever
%%
%% Description: Returns a list of test case group definitions.
%%--------------------------------------------------------------------
groups() ->
  [
    {cluster_group,
     [{repeat_until_any_fail, 1}],
     [
       connection_test,
       enable_test,
       actor_test
     ]
    }
  ].

%%--------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%%
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%%   Name of a test case group.
%% TestCase = atom()
%%   Name of a test case.
%% Reason = term()
%%   The reason for skipping all groups and test cases.
%%
%% Description: Returns the list of groups and test cases that
%%              are to be executed.
%%--------------------------------------------------------------------
all() ->
  [
    {group, cluster_group}
  ].

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Function: TestCase(Config0) ->
%%               ok | exit() | {skip,Reason} | {comment,Comment} |
%%               {save_config,Config1} | {skip_and_save,Reason,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%% Comment = term()
%%   A comment about the test case that will be printed in the html log.
%%
%% Description: Test case function. (The name of it must be specified in
%%              the all/0 list or in a test case group for the test case
%%              to be executed).
%%--------------------------------------------------------------------

%% =============================================================================
%% Table create group
%% =============================================================================

cluster_group({prelude, Config}) ->
  SaveMode = os:getenv("wms_mode"),
  os:putenv("wms_mode", "multi_test"),

  ok = wms_test:start_nodes(?TEST_NODES, [{env, [{"wms_mode", "multi_test"}]}]),
  {ok, StartedApps} = application:ensure_all_started(?APP_NAME),
  ok = wms_test:start_application(?APP_NAME),
  [{started, StartedApps}, {save_mode, SaveMode} | Config];
cluster_group({postlude, Config}) ->
  StartedApps = ?config(started, Config),
  [application:stop(App) || App <- StartedApps],
  ok = wms_test:stop_nodes(?TEST_NODES),
  wms_test:stop_application(?APP_NAME),
  os:putenv("wms_mode", ?config(save_mode, Config)),
  ok.


%%--------------------------------------------------------------------
%% Connections tes
%%
%%--------------------------------------------------------------------

%% test case information
connection_test({info, _Config}) ->
  [""];
connection_test(suite) ->
  ok;
%% init test case
connection_test({prelude, Config}) ->
  Config;
%% destroy test case
connection_test({postlude, _Config}) ->
  ok;
%% test case implementation
connection_test(_Config) ->
  % cluster connected
  ?assertEqual(true, wms_dist_cluster_handler:wait_for_cluster_connected()),
  ?assertEqual(true, wms_dist_cluster_handler:is_cluster_connected()),
  ?assertEqual(true, wms_dist_cluster_handler:is_all_node_connected()),

  ?assertEqual(lists:usort(wms_dist_cluster_handler:get_nodes(all)),
               lists:usort(wms_dist_cluster_handler:get_nodes(connected))),

  % disconnect t1
  T1 = [?HOST('t1')],
  wms_test:stop_nodes(T1),
  % wait for disconnected
  wait_for_all_connstat(3000, false),
  wms_test:start_nodes(T1, [{env, [{"wms_mode", "multi_test"}]}]),
  ok = wms_test:start_application(T1, ?APP_NAME),
  %wait for connected again
  wait_for_all_connstat(2000, true),

  % auto reconnect
  ?assertEqual(true, wms_dist_cluster_handler:wait_for_cluster_connected()),
  ?assertEqual(true, wms_dist_cluster_handler:is_cluster_connected()),
  ?assertEqual(true, wms_dist_cluster_handler:is_all_node_connected()).

%%--------------------------------------------------------------------
%% Enable/disable test
%%
%%--------------------------------------------------------------------

%% test case information
enable_test({info, _Config}) ->
  [""];
enable_test(suite) ->
  ok;
%% init test case
enable_test({prelude, Config}) ->
  Config;
%% destroy test case
enable_test({postlude, _Config}) ->
  ok;
%% test case implementation
enable_test(_Config) ->

  % cluster connected
  ?assert(wms_dist_cluster_handler:wait_for_cluster_connected()),
  wait_for_all_defined_connstat(2000, true),

  % disable t1
  ?assertEqual(ok, wms_dist_cluster_handler:set_enabled(?HOST('t1'), false)),
  wait_for_all_defined_connstat(2000, false),
  ?assertEqual(true, wms_dist_cluster_handler:is_cluster_connected()),
  ?assertEqual(true, wms_dist_cluster_handler:is_all_node_connected()),

  ?debug("set_enable"),
  % enable t1
  ?assertEqual(ok, wms_dist_cluster_handler:set_enabled(?HOST('t1'), true)),
  ?assertEqual(true, wms_dist_cluster_handler:is_cluster_connected()),
  % wait for auto reconnect
  wait_for_all_defined_connstat(2000, true),
  ?assertEqual(true, wms_dist_cluster_handler:is_all_node_connected()).

%%--------------------------------------------------------------------
%% Test for actors
%%
%%--------------------------------------------------------------------

%% test case information
actor_test({info, _Config}) ->
  [""];
actor_test(suite) ->
  ok;
%% init test case
actor_test({prelude, Config}) ->
  true = wms_dist_cluster_handler:wait_for_cluster_connected(),
  Config;
%% destroy test case
actor_test({postlude, _Config}) ->
  ok;
%% test case implementation
actor_test(_Config) ->
  ?assertEqual(true, wms_dist_cluster_handler:is_all_defined_node_connected()),

  Actors = wms_dist_cluster_handler:multi_get_actors(2000),
  lists:foreach(
    fun({N, Act}) ->
      ?assertEqual([], Act)
    end, Actors),
  ?assertEqual(3, length(Actors)),

  % disable current node, actor will be started on t1 or t2
  Current = node(),
  ?assertEqual(ok, wms_dist_cluster_handler:set_enabled(Current, false)),
  wait_for_all_defined_connstat(2000, false),

  % no registered actors (only 2 node enabled)
  Actors2 = wms_dist_cluster_handler:multi_get_actors(2000),
  lists:foreach(
    fun({N, Act}) ->
      ?assertEqual([], Act)
    end, Actors2),
  ?assertEqual(2, length(Actors2)),

  % first call successed
  {Node, Result} = wms_dist:call(test_actor_module, add, [1, 2]),
  ?assertEqual(1 + 2, Result),
  Actors3 = wms_dist_cluster_handler:multi_get_actors(2000),
  lists:foreach(
    fun({N, Act}) when N =:= Node ->
      ?assertEqual([test_actor_module], Act);
       ({_, Act}) ->
         ?assertEqual([], Act)
    end, Actors3),
  ?assertEqual(2, length(Actors3)),

  % second call successed (same node, same result)
  {Node, Result} = wms_dist:call(test_actor_module, add, [1, 2]),

  % stop actor node
  wms_test:stop_nodes([Node]),

  % Function evaluated on other node
  {Node2, Result} = wms_dist:call(test_actor_module, add, [1, 2]),
  ?assertNotEqual(Node, Node2),

  ?assertEqual(1 + 2, Result),

  % start stopped node again, but not start application
  wms_test:start_nodes([Node], [{env, [{"wms_mode", "multi_test"}]}]),
  % stop second node
  wms_test:stop_nodes([Node2]),
  {error,
   {not_available, test_actor_module, _}} = wms_dist:call(test_actor_module,
                                                          add, [1, 2]),

  % start application not restarted Node
  ok = wms_test:start_application([Node], ?APP_NAME),
  {Node, Result} = wms_dist:call(test_actor_module, add, [1, 2]),
  ?assertEqual(1 + 2, Result),

  % actor error
  ?assertMatch({error, {actor_error, _, _, _}}, wms_dist:call(test_actor_module,
                                                              add, [x, 12])),

  % restart Node2
  wms_test:start_nodes([Node2], [{env, [{"wms_mode", "multi_test"}]}]),
  ok = wms_test:start_application([Node2], ?APP_NAME),
  {Node, Result} = wms_dist:call(test_actor_module, add, [1, 2]),
  ?assertEqual(1 + 2, Result),
  

  % enable current
  ?assertEqual(ok, wms_dist_cluster_handler:set_enabled(Current, true)),
  wait_for_all_defined_connstat(2000, true),

  ok.

%% =============================================================================
%% Private functions
%% =============================================================================

wait_for_all_connstat(Timeout, Expected) when Timeout =< 0 ->
  not Expected;
wait_for_all_connstat(Timeout, Expected) ->
  case wms_dist_cluster_handler:is_all_node_connected() of
    Expected ->
      Expected;
    _ ->
      timer:sleep(100),
      wait_for_all_connstat(Timeout - 100, Expected)
  end.

wait_for_all_defined_connstat(Timeout, Expected) when Timeout =< 0 ->
  not Expected;
wait_for_all_defined_connstat(Timeout, Expected) ->
  case wms_dist_cluster_handler:is_all_defined_node_connected() of
    Expected ->
      Expected;
    _ ->
      timer:sleep(100),
      wait_for_all_defined_connstat(Timeout - 100, Expected)
  end.

