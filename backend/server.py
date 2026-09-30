"""Run: python server.py   -> API on :8000 (PAPER signals only, no orders are placed)."""
import threading, time, datetime as dt
from fastapi import FastAPI, Header, HTTPException
import uvicorn
import config as C
from angel_client import AngelClient
from signals import Engine
from nse_client import NSEClient
import nse_features

app = FastAPI()
eng = Engine(); client = AngelClient(); nse = NSEClient(); state = {"error": None, "nse_error": None}
prev_chain = {"c": None}


def market_open():
    n = dt.datetime.now(dt.timezone(dt.timedelta(hours=5, minutes=30)))
    return n.weekday() < 5 and dt.time(9, 15) <= n.time() <= dt.time(15, 30)


def loop():
    while True:
        try:
            if client.api is None:
                client.login(); client.build_chain()
            if market_open():
                eng.update(client.snapshot()); state["error"] = None
        except Exception as e:
            state["error"] = str(e); client.api = None
            time.sleep(10)
        time.sleep(C.POLL_SEC)


def nse_loop():
    while True:
        try:
            if market_open():
                ch = nse.fetch(C.SYMBOL)
                f = nse_features.compute(ch, prev_chain["c"]); prev_chain["c"] = ch
                eng.set_nse(f, ch["ts"]); state["nse_error"] = None
        except Exception as e:
            state["nse_error"] = str(e)
        time.sleep(C.NSE_POLL_SEC)


@app.get("/signal")
def signal(x_token: str = Header(None)):
    if x_token != C.API_TOKEN:
        raise HTTPException(401, "bad token")
    return {"symbol": C.SYMBOL, "market_open": market_open(), "error": state["error"], "nse_error": state["nse_error"],
            "nse": eng.nse_view, **eng.last}


@app.get("/health")
def health(): return {"ok": True}


if __name__ == "__main__":
    threading.Thread(target=loop, daemon=True).start()
    threading.Thread(target=nse_loop, daemon=True).start()
    uvicorn.run(app, host="0.0.0.0", port=8000)
