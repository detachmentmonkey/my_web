-module(test_svr).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/0]).
-export ([start/0]).
-export ([init/3]).
-export ([handle/2]).
-export ([terminate/3]).
%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).


start() ->
    Port = 9013,
    N_acceptors = 10,
    Dispatch = cowboy_router:compile([
    	    {'_', [{'_', test_svr, []}]}
    	]),
    cowboy:start_http(test_svr,
    	    N_acceptors,
    	    [{port, Port}],
    	    [{env, [{dispatch, Dispatch}]}]
    	).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init({tcp, http}, Req, _Opts) ->
    {ok, Req, undefined}.


handle(Req, State) ->
    io:format("handle Req:~p, pid is~p", [Req, self()]),
    lager:info("handle Req:~p", [Req]),
    % io:format("handle Req:~p~n", [Req]),
    {Method, Req1} = cowboy_req:method(Req),
    {ok, Req2} = handle1(Method, Req1),
    {ok, Req2, State}.

handle1(<<"GET">>, Req) ->
    handleGet(Req);
handle1(_Method, Req) ->
    HasBody = cowboy_req:has_body(Req),
    try
        handlePost(HasBody, Req)
    catch
        Class:ExceptionPattern ->
            io:format("handlePost failed with ~p~n",
                [{Class, ExceptionPattern}]),
            cowboy_req:reply(400, [], <<"catch exception.">>, Req)
    end.

handlePost(true, Req) ->
    lager:info("POST Req :~p~n", [Req]),
    {ok, PostVals, _ReqB1} = cowboy_req:body_qs(Req),
    lager:info("PostVals :~p~n", [PostVals]),
    {_, PostData} = lists:keyfind(<<"data_packet">>, 1, PostVals),
    DecodeData = jsx:decode(PostData),
    {_, ReqHead} = lists:keyfind(<<"head">>, 1, DecodeData),
    {_, ReqBody} = lists:keyfind(<<"body">>, 1, DecodeData),

    Function = proplists:get_value(<<"Function">>, ReqHead),
    DelHead1 = proplists:delete(<<"Function">>, ReqHead),
    DelHead2 = proplists:delete(<<"Result">>, DelHead1),
    DelHead3 = proplists:delete(<<"RetErrMsg">>, DelHead2),
    PreHead = DelHead3 ++ [{<<"Function">>, Function}],
    Args = proplists:get_value(<<"Args">>, ReqBody),
    {RetHead, RetBody} = handleFunc(Function, Args),
    FinalHead = PreHead ++ RetHead,
    SendData = [
        {<<"head">>, FinalHead},
        {<<"body">>, RetBody}
    ],
    % io:format("SendData :~p~n", [SendData]),
    JsonData = jsx:encode(SendData),
    cowboy_req:reply(200, [], JsonData, Req);
handlePost(false, Req) ->
    cowboy_req:reply(400, [], <<"Missing body.">>, Req).


handleGet(Req) ->
    % io:format("GET Req :~p~n", [Req]),
    lager:info("Get Req :~p~n", [Req]),
    {Function, Req1} = cowboy_req:qs_val(<<"Function">>, Req),
    {Args, _Req2} = cowboy_req:qs_val(<<"Args">>, Req1),
    lager:info("Function:~p,Args:~p ~n", [Function, Args]),
    {RetHead, RetBody} = handleFunc(Function, {Args}),
    SendData = [
        {<<"head">>, RetHead},
        {<<"body">>, RetBody}
    ],
    lager:info("SendData:~p~n", [SendData]),
    JsonData = jsx:encode(SendData),
    cowboy_req:reply(200, [], JsonData, Req1).


handleFunc(<<"fab">>, {Num}) ->
    Val = binary_to_integer(Num),
    case Val >= 0 of
        true ->
            RetHead = [{<<"Result">>,0},{<<"RetErrMsg">>,<<"sucess">>}],
            RetBody = [{<<"original num">>,Val},{<<"fab num">>,fab:fab(Val)}],
            {RetHead, RetBody};
        false ->
            RetHead = [{<<"Result">>,1},{<<"RetErrMsg">>,<<"only positive number">>}],
            RetBody = [{<<"original num">>,Val},{<<"fab num">>,<<"can not caculate">>}],
            {RetHead, RetBody}
    end;

handleFunc(Func, {Args}) ->
    RetHead = [{<<"Result">>,1},{<<"RetErrMsg">>,<<"unkonwn Function">>}],
    RetBody = [{<<"original Function">>, Func},{<<"original Args">>, Args}],
    {RetHead, RetBody}.


init(Args) ->
    {ok, Args}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _Req, _State) ->
    ok.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
