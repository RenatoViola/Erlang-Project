-module(vsc_client).

-export([register/2,
         new/4,
         invite/4,
         subscribe/4,
         token/5,
         add/4,
         push/4,
         status/3]).

% API - To interact with the server


register(Server, Username) ->
    Listener = spawn(fun() -> listen_for_notifications(Username) end),
    Reply = gen_server:call(Server, {register, Username}),
    io:format("~s: |REGISTER| -> ~p~n", [Username, Reply]),
    Listener.


new(Server, Username, RepoName, Listener) ->
    Reply = gen_server:call(Server, {new, Username, RepoName, Listener}),
    io:format("~s: |NEW| -> ~p~n", [Username, Reply]).


invite(Server, AdminName, RepoName, CollabName) ->
    Reply = gen_server:call(Server, {invite, AdminName, RepoName, CollabName}),
    io:format("~s: |INVITE| -> ~p~n", [AdminName, Reply]).


subscribe(Server, Username, RepoName, Listener) ->
    Reply = gen_server:call(Server, {subscribe, Username, RepoName, Listener}),
    io:format("~s: |SUBSCRIBE| -> ~p~n", [Username, Reply]).


token(Server, AdminName, RepoName, Username, Validity) ->
    Reply = gen_server:call(Server, {token, AdminName, RepoName, Username, Validity}),
    io:format("~s: |TOKEN| -> ~p~n", [AdminName, Reply]).


add(Server, Username, RepoName, FileName) ->
    Reply = gen_server:call(Server, {add, Username, RepoName, FileName}),
    io:format("~s: |ADD| -> ~p~n", [Username, Reply]).


push(Server, Username, RepoName, FileNames) ->
    Reply = gen_server:call(Server, {push, Username, RepoName, FileNames}),
    io:format("~s: |PUSH| -> ~p~n", [Username, Reply]).


status(Server, Username, RepoName) ->
    Reply = gen_server:call(Server, {status, Username, RepoName}),
    io:format("~s: |STATUS| -> ~s's status~n", [Username, RepoName]),
    io:format("~p~n", [Reply]).


% Helper function for the client to be listening to notifications in the background
listen_for_notifications(Username) ->
    receive
        {notification, Notification} ->
            io:format("| Notification for ~s | ~s~n", [Username, Notification]),
            listen_for_notifications(Username)
    end.
