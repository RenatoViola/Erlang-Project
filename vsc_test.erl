-module(vsc_test).

-export([run/0]).

% This module is here just to assert that the functionality is as intended.
% Each command defined in the assignment is executed, in a short demo with a server instance and two clients interacting with it.


run() ->
    {ok, Server} = vsc_server:start_link(),
    io:format("Server is active.~n"),

    spawn(fun() -> client1(Server) end),
    spawn(fun() -> client2(Server) end),
    spawn(fun() -> client3(Server) end),

    spawn(fun() -> erroneousClient(Server) end).


client1(Server) ->
    % Register as "Renato"
    ListenerPid1 = vsc_client:register(Server, "Renato"),
    vsc_client:new(Server, "Renato", "dialetica_socratica", ListenerPid1),
    vsc_client:invite(Server, "Renato", "dialetica_socratica", "Daniel"),
    vsc_client:token(Server, "Renato", "dialetica_socratica", "Cho Ang Ah", 10),
    vsc_client:subscribe(Server, "Renato", "dialetica_socratica", ListenerPid1),
    vsc_client:add(Server, "Renato", "dialetica_socratica", "file1.txt"),
    vsc_client:push(Server, "Renato", "dialetica_socratica", ["file1.txt"]),
    vsc_client:invite(Server, "Renato", "dialetica_socratica", "ronaldo"),
    vsc_client:push(Server, "Renato", "dialetica_socratica", ["file101.txt"]),
    vsc_client:status(Server, "Renato", "dialetica_socratica").


client2(Server) ->
    % Register as "Daniel"
    ListenerPid2 = vsc_client:register(Server, "Daniel"),
    % Small sleep so that Client1 has the time to create the repository and operate on it,
    % So that Client2 won't be trying to perform operations on 'my_repo' before it was even created.
    % Just trying to simulate some order of events.
    timer:sleep(200),  % Just commment this line for the clients to be actually concurrent
    vsc_client:subscribe(Server, "Daniel", "dialetica_socratica", ListenerPid2),
    vsc_client:add(Server, "Daniel", "dialetica_socratica", "file2.txt"),
    vsc_client:push(Server, "Daniel", "dialetica_socratica", ["file2.txt"]),
    vsc_client:new(Server, "Daniel", "segredos_de_estado", ListenerPid2),
    vsc_client:invite(Server, "Daniel", "segredos_de_estado", "Cho Ang Ah"),
    vsc_client:token(Server, "Daniel", "segredos_de_estado", "Renato", 5),
    vsc_client:add(Server, "Daniel", "segredos_de_estado", "secretRecipe.txt"),
    vsc_client:push(Server, "Daniel", "segredos_de_estado", ["secretRecipe.txt"]),
    vsc_client:status(Server, "Daniel", "dialetica_socratica"),
    vsc_client:status(Server, "Daniel", "segredos_de_estado").


client3(Server) ->
    % Register as "Cho Ang Ah"
    ListenerPid3 = vsc_client:register(Server, "Cho Ang Ah"),
    timer:sleep(400),  % A bit after "Daniel"
    vsc_client:subscribe(Server, "Cho Ang Ah", "dialetica_socratica", ListenerPid3),  % has token but can't subscribe
    vsc_client:subscribe(Server, "Cho Ang Ah", "segredos_de_estado", ListenerPid3),
    vsc_client:push(Server, "Cho Ang Ah", "dialetica_socratica", ["file2.txt"]),
    vsc_client:add(Server, "Cho Ang Ah", "segredos_de_estado", "even_more_secretRecipe.txt"),
    vsc_client:push(Server, "Cho Ang Ah", "segredos_de_estado", ["secretRecipe.txt"]),
    vsc_client:status(Server, "Cho Ang Ah", "dialetica_socratica"),
    vsc_client:status(Server, "Cho Ang Ah", "segredos_de_estado").


erroneousClient(Server) ->
    timer:sleep(1000),  % Last client to do something
    % Register as "Very Erroneous Individual"
    io:format("~nThe output that follows is supposed to represent requests from very erroneous people, who get the requests right at first, but then stumble into every error case.~n~n"),

    ListenerPid5 = vsc_client:register(Server, "Little Helper"),  % SUCCESS: registered_successfully
    ListenerPid4 = vsc_client:register(Server, "Very Erroneous Individual"),  % SUCCESS: registered_successfully
    _ListenerPid4 = vsc_client:register(Server, "Very Erroneous Individual"),  % ERROR: username_is_taken

    vsc_client:new(Server, "Very Erroneous Individual", "erroneous_repo", ListenerPid4),  % SUCCESS: repo_created_successfully
    vsc_client:new(Server, "Quite Erroneous Individual", "erroneous_repo", ListenerPid4),  % ERROR: unregistered_user
    vsc_client:new(Server, "Very Erroneous Individual", "segredos_de_estado", ListenerPid4),  % ERROR: repo_name_is_taken

    vsc_client:invite(Server, "Very Erroneous Individual", "erroneous_repo", "Little Helper"),  % SUCCESS: collaborator_invited_successfully
    vsc_client:invite(Server, "Very Erroneous Individual", "erroneously_a_repo", "Daniel"),  % ERROR: unknown_repo
    vsc_client:invite(Server, "Quite Erroneous Individual", "erroneous_repo", "Daniel"),  % ERROR: unregistered_admin
    vsc_client:invite(Server, "Renato", "erroneous_repo", "Daniel"),  % ERROR: admin_mismatch
    vsc_client:invite(Server, "Very Erroneous Individual", "erroneous_repo", "Danny"),  % ERROR: unregistered_collaborator
    vsc_client:invite(Server, "Very Erroneous Individual", "erroneous_repo", "Very Erroneous Individual"),  % ERROR: admin_cannot_invite_itself
    vsc_client:invite(Server, "Very Erroneous Individual", "erroneous_repo", "Little Helper"),  % ERROR: is_already_a_collaborator

    vsc_client:subscribe(Server, "Little Helper", "erroneous_repo", ListenerPid5),  % SUCCESS: subscribed_successfully
    vsc_client:subscribe(Server, "Danny", "erroneous_repo", ListenerPid5),  % ERROR: unregistered_user
    vsc_client:subscribe(Server, "Little Helper", "erroneously_a_repo", ListenerPid5),  % ERROR: unknown_repo
    vsc_client:subscribe(Server, "Renato", "erroneous_repo", ListenerPid5),  % ERROR: not_a_collaborator
    vsc_client:subscribe(Server, "Little Helper", "erroneous_repo", ListenerPid5),  % ERROR: user_is_already_subscribed

    vsc_client:token(Server, "Very Erroneous Individual", "erroneous_repo", "Renato", 2),  % SUCCESS: token_generated_successfully
    vsc_client:token(Server, "Very Erroneous Individual", "erroneously_a_repo", "Renato", 1),  % ERROR: unknown_repo
    vsc_client:token(Server, "Quite Erroneous Individual", "erroneous_repo", "Renato", 1),  % ERROR: unregistered_admin
    vsc_client:token(Server, "Daniel", "erroneous_repo", "Renato", 1),  % ERROR: admin_mismatch
    vsc_client:token(Server, "Very Erroneous Individual", "erroneous_repo", "RRenato", 1),  % ERROR: unregistered_user
    vsc_client:token(Server, "Very Erroneous Individual", "erroneous_repo", "Very Erroneous Individual", 1),  % ERROR: admin_has_access_already
    vsc_client:token(Server, "Very Erroneous Individual", "erroneous_repo", "Daniel", 1),  % ERROR: collaborator_has_access_already
    vsc_client:token(Server, "Very Erroneous Individual", "erroneous_repo", "Renato", -1),  % ERROR: validity_must_be_positive

    vsc_client:add(Server, "Very Erroneous Individual", "erroneous_repo", "file.txt"),  % SUCCESS: file_added_successfully
    vsc_client:add(Server, "Quite Erroneous Individual", "erroneous_repo", "file.txt"),  % ERROR: unregistered_user
    vsc_client:add(Server, "Very Erroneous Individual", "erroneously_a_repo", "file.txt"),  % ERROR: unknown_repo
    vsc_client:add(Server, "Cho Ang Ah", "erroneous_repo", "file.txt"),  % ERROR: unauthorized_user
    vsc_client:add(Server, "Very Erroneous Individual", "erroneous_repo", "file.txt"),  % ERROR: file_already_exists

    vsc_client:push(Server, "Very Erroneous Individual", "erroneous_repo", ["file.txt"]),  % SUCCESS: pushed_files_successfully
    vsc_client:push(Server, "Quite Erroneous Individual", "erroneous_repo", ["file.txt"]),  % ERROR: unregistered_user
    vsc_client:push(Server, "Very Erroneous Individual", "erroneously_a_repo", ["file.txt"]),  % ERROR: unknown_repo
    vsc_client:push(Server, "Cho Ang Ah", "erroneous_repo", ["file.txt"]),  % ERROR: unauthorized_user
    vsc_client:push(Server, "Very Erroneous Individual", "erroneous_repo", ["file_5.txt"]),  % ERROR: not_all_files_exist_in_repo

    vsc_client:status(Server, "Very Erroneous Individual", "erroneous_repo"),  % SUCCESS
    vsc_client:status(Server, "Quite Erroneous Individual", "erroneous_repo"),  % ERROR: unregistered_user
    vsc_client:status(Server, "Very Erroneous Individual", "erroneously_a_repo"),  % ERROR: unknown_repo
    vsc_client:status(Server, "Cho Ang Ah", "erroneous_repo"),  % ERROR: unauthorized_user

    % Renato has an active token
    vsc_client:push(Server, "Renato", "erroneous_repo", ["file.txt"]),  % SUCCESS: pushed_files_successfully
    % Wait for the token to die out
    timer:sleep(2000),
    vsc_client:push(Server, "Renato", "erroneous_repo", ["file.txt"]).  % ERROR: unauthorized_user
