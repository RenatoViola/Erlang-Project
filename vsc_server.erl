-module(vsc_server).

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

% Records
-record(repo, {name, admin, collaborators = [], files = #{}, subscribers = [], tokens = #{}}).
-record(file, {name, version, modified_by}).
-record(state, {users = [], repos = #{}}).


% Start the server
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


%Callbacks


init([]) ->
    {ok, #state{}}.


handle_call({register, Username}, _From, State) ->
    Users = State#state.users,

    case lists:member(Username, Users) of
        true ->
            {reply, username_is_taken, State};
        false ->
            NewState = State#state{users = [Username | Users]},
            {reply, registered_successfully, NewState}
    end;

handle_call({new, Username, RepoName, Listener}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case lists:member(Username, Users) of
        false ->
            {reply, unregistered_user, State};
        true ->
            case maps:is_key(RepoName, Repos) of
                true ->
                    {reply, repo_name_is_taken, State};
                false ->
                    Repo = #repo{
                             name = RepoName,
                             admin = Username,
                             subscribers = [Listener]  % Makes sense that the admin of the repository wants to be kept to date
                            },
                    NewRepos = maps:put(RepoName, Repo, Repos),
                    NewState = State#state{repos = NewRepos},
                    {reply, repo_created_successfully, NewState}
            end
    end;

handle_call({invite, AdminName, RepoName, CollabName}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case maps:is_key(RepoName, Repos) of
        false ->
            {reply, unknown_repo, State};
        true ->
            Repo = maps:get(RepoName, Repos),
            #repo{admin = Admin, collaborators = Collaborators} = Repo,

            case lists:member(AdminName, Users) of
                false ->
                    {reply, unregistered_admin, State};
                true ->
                    case Admin =:= AdminName of
                        false ->
                            {reply, admin_mismatch, State};
                        true ->
                            case lists:member(CollabName, Users) of
                                false ->
                                    {reply, unregistered_collaborator, State};
                                true ->
                                    case AdminName =:= CollabName of
                                        true ->
                                            {reply, admin_cannot_invite_itself, State};
                                        false ->
                                            case lists:member(CollabName, Collaborators) of
                                                true ->
                                                    {reply, is_already_a_collaborator, State};
                                                false ->
                                                    NewRepo = Repo#repo{
                                                                collaborators = [CollabName | Collaborators]
                                                               },
                                                    NewRepos = maps:put(RepoName, NewRepo, Repos),
                                                    NewState = State#state{repos = NewRepos},
                                                    {reply, collaborator_invited_successfully, NewState}
                                            end
                                    end
                            end
                    end
            end
    end;

handle_call({subscribe, Username, RepoName, Listener}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case lists:member(Username, Users) of
        false ->
            {reply, unregistered_user, State};
        true ->
            case maps:is_key(RepoName, Repos) of
                false ->
                    {reply, unknown_repo, State};
                true ->
                    Repo = maps:get(RepoName, Repos),
                    #repo{collaborators = Collaborators, subscribers = Subscribers} = Repo,

                    case lists:member(Username, Collaborators) of
                        false ->
                            {reply, not_a_collaborator, State};
                        true ->
                            case lists:member(Listener, Subscribers) of
                                true ->
                                    {reply, user_is_already_subscribed, State};
                                false ->
                                    NewRepo = Repo#repo{
                                                subscribers = [Listener | Subscribers]
                                               },
                                    NewRepos = maps:put(RepoName, NewRepo, Repos),
                                    NewState = State#state{repos = NewRepos},
                                    {reply, subscribed_successfully, NewState}
                            end
                    end
            end
    end;

handle_call({token, AdminName, RepoName, Username, Validity}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case maps:is_key(RepoName, Repos) of
        false ->
            {reply, unknown_repo, State};
        true ->
            Repo = maps:get(RepoName, Repos),
            #repo{admin = Admin, collaborators = Collaborators, files = _Files, subscribers = _Subscribers, tokens = Tokens} = Repo,

            case lists:member(AdminName, Users) of
                false ->
                    {reply, unregistered_admin, State};
                true ->
                    case Admin =:= AdminName of
                        false ->
                            {reply, admin_mismatch, State};
                        true ->
                            case lists:member(Username, Users) of
                                false ->
                                    {reply, unregistered_user, State};
                                true ->
                                    case AdminName =:= Username of
                                        true ->
                                            {reply, admin_has_access_already, State};
                                        false ->
                                            case lists:member(Username, Collaborators) of
                                                true ->
                                                    {reply, collaborator_has_access_already, State};
                                                false ->
                                                    case Validity < 0 of
                                                        true ->
                                                            {reply, validity_must_be_positive, State};
                                                        false ->
                                                            ExpirationTime = erlang:system_time(second) + Validity,
                                                            NewTokens = maps:put(Username, ExpirationTime, Tokens),
                                                            NewRepo = Repo#repo{tokens = NewTokens},
                                                            NewRepos = maps:put(RepoName, NewRepo, Repos),
                                                            NewState = State#state{repos = NewRepos},
                                                            % After this time, the token will be deleted
                                                            % erlang:send_after(Validity * 1000, self(), {expired_token, Username, RepoName}),
                                                            {reply, token_generated_successfully, NewState}
                                                    end
                                            end
                                    end
                            end
                    end
            end
    end;

handle_call({add, Username, RepoName, FileName}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case lists:member(Username, Users) of
        false ->
            {reply, unregistered_user, State};
        true ->
            case maps:is_key(RepoName, Repos) of
                false ->
                    {reply, unknown_repo, State};
                true ->
                    Repo = maps:get(RepoName, Repos),
                    #repo{admin = Admin, collaborators = Collaborators, files = Files, subscribers = Subscribers, tokens = Tokens} = Repo,

                    case (lists:member(Username, [Admin | Collaborators]) orelse valid_token(Username, Tokens)) of
                        false ->
                            {reply, unauthorized_user, State};
                        true ->
                            case maps:is_key(FileName, Files) of
                                true ->
                                    {reply, file_already_exists, State};
                                false ->
                                    NewFile = #file{name = FileName, version = 0, modified_by = Username},
                                    NewFiles = maps:put(FileName, NewFile, Files),
                                    NewRepo = Repo#repo{files = NewFiles},
                                    NewRepos = maps:put(RepoName, NewRepo, Repos),
                                    NewState = State#state{repos = NewRepos},
                                    % Asynchronously notify subscribers
                                    Notification = lists:flatten(io_lib:format("~s | ~s added the file: ~s", [RepoName, Username, FileName])),
                                    spawn(fun() -> notify_subscribers(Subscribers, Notification) end),
                                    {reply, file_added_successfully, NewState}
                            end
                    end
            end
    end;

handle_call({push, Username, RepoName, FileNames}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case lists:member(Username, Users) of
        false ->
            {reply, unregistered_user, State};
        true ->
            case maps:is_key(RepoName, Repos) of
                false ->
                    {reply, unknown_repo, State};
                true ->
                    Repo = maps:get(RepoName, Repos),
                    #repo{admin = Admin, collaborators = Collaborators, files = Files, subscribers = Subscribers, tokens = Tokens} = Repo,

                    case (lists:member(Username, [Admin | Collaborators]) orelse valid_token(Username, Tokens)) of
                        false ->
                            {reply, unauthorized_user, State};
                        true ->
                            case files_exist_in_repo(FileNames, Files) of
                                false ->
                                    {reply, not_all_files_exist_in_repo, State};
                                true ->
                                    NewFiles = lists:foldl(
                                                 fun(FileName, Acc) ->
                                                         #file{name = Name, version = Version, modified_by = _ModifiedBy} = maps:get(FileName, Acc),
                                                         NewFile = #file{
                                                                     name = Name,
                                                                     version = Version + 1,
                                                                     modified_by = Username
                                                                    },
                                                         maps:put(FileName, NewFile, Acc)
                                                 end,
                                                 Files,
                                                 FileNames),
                                    NewRepo = Repo#repo{files = NewFiles},
                                    NewRepos = maps:put(RepoName, NewRepo, Repos),
                                    NewState = State#state{repos = NewRepos},
                                    % Asynchronously notify subscribers
                                    Notification = lists:flatten(io_lib:format("~s | ~s pushed ~p files", [RepoName, Username, length(FileNames)])),
                                    spawn(fun() -> notify_subscribers(Subscribers, Notification) end),
                                    {reply, pushed_files_successfully, NewState}
                            end
                    end
            end
    end;

handle_call({status, Username, RepoName}, _From, State) ->
    #state{users = Users, repos = Repos} = State,

    case lists:member(Username, Users) of
        false ->
            {reply, unregistered_user, State};
        true ->
            case maps:is_key(RepoName, Repos) of
                false ->
                    {reply, unknown_repo, State};
                true ->
                    Repo = maps:get(RepoName, Repos),
                    #repo{
                      admin = Admin,
                      collaborators = Collaborators,
                      files = Files,
                      subscribers = _Subscribers,
                      tokens = Tokens
                     } = Repo,

                    case (lists:member(Username, [Admin | Collaborators]) orelse valid_token(Username, Tokens)) of
                        false ->
                            {reply, unauthorized_user, State};
                        true ->
                            Status = #{
                                       admin => Admin,
                                       collaborators => Collaborators,
                                       files => maps:values(Files)
                                      },
                            {reply, Status, State}
                    end
            end
    end.


handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info({expired_token, Username, RepoName}, State) ->
    Repos = State#state.repos,
    Repo = maps:get(RepoName, Repos),
    Tokens = Repo#repo.tokens,
    NewTokens = maps:remove(Username, Tokens),
    NewRepo = Repo#repo{tokens = NewTokens},
    NewRepos = maps:put(RepoName, NewRepo, Repos),
    NewState = State#state{repos = NewRepos},
    {noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


% Helper Functions


% Check if the provided filenames exist in the repository
files_exist_in_repo([], _Files) ->
    true;
files_exist_in_repo([F | Fs], Files) ->
    maps:is_key(F, Files) andalso files_exist_in_repo(Fs, Files).


% Notify all the subscribers of a repository
notify_subscribers(Subscribers, Notification) ->
    lists:foreach(
      fun(Pid) ->
              Pid ! {notification, Notification}
      end,
      Subscribers).


% Check if the user has a valid token for the repository it's trying to access
valid_token(Username, Tokens) ->
    maps:is_key(Username, Tokens) andalso erlang:system_time(second) < maps:get(Username, Tokens).
