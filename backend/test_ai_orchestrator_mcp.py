import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from ai_orchestrator import _local_fallback


def test_local_fallback_uses_connected_nse_mcp_evidence():
    payload = {
        "terminal": {
            "market_open": True,
            "signals": {"action": "CALL BUY", "spot": 25000, "ltp": 120, "strike": 25000},
        },
        "nse_mcp": {
            "connected": True,
            "endpoint": "https://mcp.nseindia.in/cmmkt/mcp",
            "tool_count": 15,
            "data": [{"tool": "live_index", "result": {"symbol": "NIFTY", "ltp": 25000}}],
            "tool_errors": [],
        },
    }
    result = _local_fallback(payload)
    assert result["status"] == "ok_local"
    assert result["final"] == "CALL BUY"
    assert result["mcp"]["connected"] is True
    assert result["mcp"]["tool_count"] == 15


def test_local_fallback_forces_wait_when_mcp_is_unavailable():
    payload = {
        "terminal": {"market_open": True, "signals": {"action": "PUT BUY"}},
        "nse_mcp": {
            "connected": False,
            "tool_count": 0,
            "data": [],
            "tool_errors": [{"tool": "live_index", "error": "offline"}],
        },
    }
    result = _local_fallback(payload)
    assert result["final"] == "WAIT"
    assert result["mcp"]["connected"] is False
