-module (fab).
-export ([fab/1, is_today/1, compare_week_releation/2]).

-export ([format_utc_timestamp/0]).

fab(N) when N >= 0 -> fab(N, 0, 1).

fab(0, _F1, F2) -> F2;
fab(N,  F1, F2) -> fab(N - 1, F2, F1 + F2).

unix_timestamp() ->
    {Msec, Sec, _} = os:timestamp(),
    Msec * 1000000 + Sec.

compare_week_releation(Last, Now) ->
    {DayLast, _} = calendar:gregorian_seconds_to_datetime(Last),
    {_, WeekLast} = calendar:iso_week_number(DayLast),
    {DayNow, _} = calendar:gregorian_seconds_to_datetime(Now),
    {_, WeekNow} = calendar:iso_week_number(DayNow),

    case WeekNow =:= WeekLast of
        true ->
            same_week;
        false ->
            io:format(":WeekNow~p,WeekLast~p~n", [WeekNow, WeekLast]),
            case WeekNow =:= (WeekLast + 1) of
                true ->
                    last_week;
                false ->
                    too_long
            end
    end.


is_today(TimeStamp)->
    {Date, _} = calendar:gregorian_seconds_to_datetime(TimeStamp),
    {Today, _} = calendar:gregorian_seconds_to_datetime(unix_timestamp()),
    Date =:= Today.



format_utc_timestamp() ->
    TS = {_,_,Micro} = os:timestamp(),
    {{Year,Month,Day},{Hour,Minute,Second}} =
    calendar:now_to_universal_time(TS),
    Mstr = element(Month,{"Jan","Feb","Mar","Apr","May","Jun","Jul",
              "Aug","Sep","Oct","Nov","Dec"}),
    lists:flatten(io_lib:format("~2w ~s ~4w ~2w:~2..0w:~2..0w.~6..0w", [Day,Mstr,Year,Hour,Minute,Second,Micro])).
