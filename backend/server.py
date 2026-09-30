"""Network/API gateway for NSE Algo Signal. PAPER signals only; no order placement."""
import threading, time, datetime as dt
from fastapi import FastAPI, Header, HTTPException
import uvicorn
import config as C
from angel_client import AngelClient
from signals import Engine
from nse_client import NSEClient
import nse_features

app = FastAPI(title="NSE Algo Signal API")
eng = Engine()
client = AngelClient()
nse = NSEClient()
state = {"error": None, "nse_error": None, "last_update": None}
prev_chain = {"c": None}


def market_open():
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30)))
    return now.weekday() < 5 and dt.time(9, 15) <= now.time() <= dt.time(15, 30)


def _ensure_angel():
    if client.api is None:
        client.login()
        client.build_chain()


def loop():
    while True:
        try:
            _ensure_angel()
            if market_open():
                eng.update(client.snapshot())
                state["last_update"] = time.time()
                state["error"] = None
        except Exception as e:
            state["error"] = str(e)
            client.api = None
            time.sleep(10)
        time.sleep(C.POLL_SEC)


def nse_loop():
    while True:
        try:
            if market_open():
                ch = nse.fetch(C.SYMBOL)
                features = nse_features.compute(ch, prev_chain["c"])
                prev_chain["c"] = ch
                eng.set_nse(features, ch["ts"])
                state["nse_error"] = None
        except Exception as e:
            state["nse_error"] = str(e)
        time.sleep(C.NSE_POLL_SEC)


def auth(x_token: str):
    if x_token != C.API_TOKEN:
        raise HTTPException(401, "bad token")


@app.get("/health")
def health():
    return {
        "ok": True,
        "market_open": market_open(),
        "angel_connected": client.api is not None,
        "last_update": state["last_update"],
        "error": state["error"],
        "nse_error": state["nse_error"],
    }


@app.get("/signal")
def signal(x_token: str = Header(None)):
    auth(x_token)
    return terminal_snapshot()


@app.get("/v1/terminal")
def terminal_snapshot_endpoint(x_token: str = Header(None)):
    auth(x_token)
    return terminal_snapshot()


def terminal_snapshot():
    last = eng.last if isinstance(eng.last, dict) else {}
    nse_view = eng.nse_view if isinstance(eng.nse_view, dict) else {}
    return {
        "ts": time.time(),
        "market_open": market_open(),
        "connection": {
            "angel": client.api is not None,
            "nse": state["nse_error"] is None,
            "server": True,
            "last_update": state["last_update"],
            "error": state["error"],
            "nse_error": state["nse_error"],
        },
        "market": {
            "symbol": C.SYMBOL,
            "spot": last.get("spot"),
            "atm": last.get("strike"),
            "action": last.get("action", "WAIT"),
            "ltp": last.get("ltp"),
        },
        "signals": last,
        "oi_lab": nse_view,
        "option_chain": last.get("chain", last.get("opts")),
        "charts": {
            "spot": last.get("spot"),
            "ltp": last.get("ltp"),
            "timestamp": state["last_update"],
        },
        "nse": nse_view,
        "nse_mcp": {"status": "server-side adapter", "connected": False},
        "angel_api": {"connected": client.api is not None},
        "data": last,
        "instruments": {
            "source": "Angel One SmartAPI instrument master",
            "loaded": bool(client.chain),
            "expiry": str(client.expiry) if client.expiry else None,
            "strike_count": len(client.strikes),
        },
        "watchlist": {"source": "Angel One SmartAPI", "items": []},
        "search": {"source": "Angel One SmartAPI", "items": []},
        "commodity": {"source": "Angel One SmartAPI", "items": []},
        "market_details": nse_view,
        "news": {"source": "server-side news adapter", "items": []},
        "settings": {
            "symbol": C.SYMBOL,
            "poll_sec": C.POLL_SEC,
            "nse_poll_sec": C.NSE_POLL_SEC,
        },
        "more": {"paper_only": True, "orders_enabled": False},
        "error": state["error"],
        "nse_error": state["nse_error"],
    }


if __name__ == "__main__":
    threading.Thread(target=loop, daemon=True).start()
    threading.Thread(target=nse_loop, daemon=True).start()
    uvicorn.run(app, host="0.0.0.0", port=8000)
