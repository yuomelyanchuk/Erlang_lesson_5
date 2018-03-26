
-module(my_cache).
-include_lib("stdlib/include/ms_transform.hrl").
-export([create/0, insert/3,lookup/1,delete_obsolete/0]).

-record(cacheItem,{key,value, lives_to=0}).


get_timestamp() ->
  {Mega, Sec, _Micro} = os:timestamp(),
  (Mega*1000000 + Sec) .

create() ->
  If_exists=ets:info(cache),
  if
    If_exists==undefined -> cache=ets:new(cache,[public,{keypos, #cacheItem.key},named_table])
      , ok;
    true-> ets:delete(cache),
      cache=ets:new(cache,[public,{keypos, #cacheItem.key},named_table]),
      ok
  end.


insert(K, V, T) ->
  ets:insert(cache, #cacheItem{key=K,value = V,lives_to = get_timestamp()+T}),
  ok.

lookup(K)  ->
  Ex=ets:member(cache,K),
  if
    Ex ->
      [Item|_T]=ets:lookup(cache,K),
      Is_alive=Item#cacheItem.lives_to>get_timestamp(),
      if
        Is_alive  -> {ok,Item#cacheItem.value};
        true -> []
      end;
    true -> []
  end.

delete_obsolete() ->
  T_now=get_timestamp(),
  ets:select_delete(cache, ets:fun2ms(fun(#cacheItem{lives_to = T})->  T < T_now  end))
  ,ok.


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
create_insert_test_()->[
  ?_assertException(error,badarg,insert(1,"hkjhkjdshfkh",10)),
  ?_assert(create()=:=ok),
  ?_assert(insert(1,"hkjhkjdshfkh",10)=:=ok),
  ?_assert(insert(1,"hkjhkjdshfkh",30)=:=ok)].

delete_test_()->
  fun()->
  create(),
  insert(1,"hkjhkjdshfkh",1),
  insert(2,"hkjhkjdshfkh",3),
  timer:sleep(2000),
  [
  ?_assert(lookup(1)=:=[]),
  ?_assert(lookup(2)=:={ok,"hkjhkjdshfkh"}),
  ?_assert(delete_obsolete()=:=ok)] end.

insert_many_test_()->
  fun()->
    L=lists:seq(1,1000,1),
    create(),
    lists:map(fun(L)->insert(L,"kjahdkjashkjsah",2) end,L),
    timer:sleep(2000),
    delete_obsolete(),
    L2=ets:tab2list(cache),
    ?_assert(length(L2)=:=0)  end.




-endif.