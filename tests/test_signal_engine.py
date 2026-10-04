from signal_engine import age, klass, quality
def test_klass_2x2():
 assert klass(1,1)=="Long Buildup"
 assert klass(1,-1)=="Short Covering"
 assert klass(-1,1)=="Short Buildup"
 assert klass(-1,-1)=="Long Unwinding"
def test_missing_spot():
 ok,reason=quality({},[])
 assert not ok and reason=="Missing spot"
def test_bad_timestamp_is_stale():
 assert age({"exchFeedTime":"bad"})>5
