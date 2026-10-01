import os, time, asyncio, pyotp, httpx
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from fastapi import APIRouter, HTTPException
from SmartApi import SmartConnect
from market_core import STORE

router = APIRouter()
IST = ZoneInfo("Asia/Kolkata")
TOKENS = {
    "NIFTY": "99926000",
    "BANKNIFTY": "99926009",
    "FINNIFTY": "99926037",
    "MIDCPNIFTY": "99926074",
}
INTERVAL = {
    "1m": "ONE_MINUTE",
    "5m": "FIVE_MINUTE",
    "15m": "FIFTEEN_MINUTE",
    "1h": "ONE_HOUR",
    "1D": "ONE_DAY",
}
DAYS = {"1m": 5, "5m": 20, "15m": 40, "1h": 120, "1D": 700}
_api, _ts, _cache = None, 0, {}

def _login():
    global _api, _ts
    client_code = os.getenv("ANGEL_CLIENT", os.getenv("ANGEL_CLIENT_CODE", ""))
    a = SmartConnect(api_key=os.environ["ANGEL_API_KEY"])
    a.generateSession(
        client_code,
        os.environ["ANGEL_PIN"],
        pyotp.TOTP(os.environ["ANGEL_TOTP_SECRET"]).now(),
    )
    _api, _ts = a, time.time()

def _fetch(index, tf):
    if not _api or time.time() - _ts > 6 * 3600:
        _login()
    now = datetime.now(IST)
    p = {
        "exchange": "NSE",
        "symboltoken": TOKENS[index],
        "interval": INTERVAL[tf],
        "fromdate": (now - timedelta(days=DAYS[tf])).strftime("%Y-%m-%d 09:15"),
        "todate": now.strftime("%Y-%m-%d %H:%M"),
    }
    r = _api.getCandleData(p)
    if not r or not r.get("status"):
        _login()
        r = _api.getCandleData(p)
    if not r or not r.get("status") or not r.get("data"):
        raise RuntimeError("Angel candle data unavailable")
    out = []
    for t, o, h, l, c, v in r["data"]:
        out.append({
            "t": int(datetime.fromisoformat(t).timestamp()),
            "o": o, "h": h, "l": l, "c": c, "v": v
        })
    return out

@router.get("/api/candles")
async def candles(index: str = "NIFTY", tf: str = "5m"):
    index = index.upper()
    if index not in TOKENS or tf not in INTERVAL:
        raise HTTPException(400, "bad index/tf")
    k = (index, tf)
    if k in _cache and time.time() - _cache[k][0] < 10:
        return _cache[k][1]
    try:
        data = await asyncio.to_thread(_fetch, index, tf)
    except Exception as e:
        if k in _cache:
            return _cache[k][1]
        raise HTTPException(503, repr(e)[:100])
    _cache[k] = (time.time(), data)
    return data

@router.get("/api/spot/{index}")
def spot(index: str):
    s = STORE.get(index.upper())
    if not s or s.get("spot") is None:
        raise HTTPException(503, "no spot")
    return {"spot": s["spot"], "age_s": round(time.time() - s.get("ts", 0), 1)}

@router.get("/api/search")
async def search(q: str, n: int = 8):
    key = os.getenv("BRAVE_API_KEY")
    if not key:
        raise HTTPException(503, "BRAVE_API_KEY not set")
    n = max(1, min(int(n), 20))
    async with httpx.AsyncClient(timeout=8) as c:
        r = await c.get(
            "https://api.search.brave.com/res/v1/web/search",
            params={"q": q, "count": n},
            headers={
                "X-Subscription-Token": key,
                "Accept": "application/json",
            },
        )
    r.raise_for_status()
    return [
        {
            "title": i["title"],
            "url": i["url"],
            "snippet": i.get("description", ""),
        }
        for i in r.json().get("web", {}).get("results", [])
    ]
