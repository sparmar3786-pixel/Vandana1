import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from strategy_registry import STRATEGIES, evaluate_strategies

def test_master_registry_contains_all_377_modules():
    assert len(STRATEGIES) == 377
    ids = [s["id"] for s in STRATEGIES]
    names = [s["name"] for s in STRATEGIES]
    assert ids == list(range(1, 378))
    assert len(set(names)) == 377

def test_core_option_classification_is_evaluable():
    rows = [{
        "strike": 25000,
        "ce": {"ltp": 120, "prev_ltp": 100, "oi": 100000, "prev_oi": 80000, "vol": 50000},
        "pe": {"ltp": 80, "prev_ltp": 90, "oi": 120000, "prev_oi": 110000, "vol": 45000},
    }]
    result = evaluate_strategies({"spot": 25000, "rows": rows, "timestamp": 1})
    by_name = {x["name"]: x for x in result}
    assert by_name["Long Buildup"]["state"] == "active"
    assert by_name["Short Buildup"]["state"] == "active"
    assert by_name["Fresh OI Addition"]["state"] == "active"

def test_missing_data_never_creates_fake_signal():
    result = evaluate_strategies({"spot": 25000, "rows": [], "timestamp": 1})
    assert all(x["state"] in {"unavailable", "inactive"} for x in result)
