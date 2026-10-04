"""NSE option-chain client with cookie refresh, bounded retry and backoff.
Network access happens only in the background poller; API/MCP requests read memory.
"""
import time, requests

BASE="https://www.nseindia.com"
HEAD={
 "User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36",
 "Accept":"application/json, text/plain, */*",
 "Accept-Language":"en-US,en;q=0.9",
 "Referer":BASE+"/option-chain",
}

class NSEClient:
    def __init__(self):
        """Initialize the HTTP session, cached response, and retry state."""
        self.s=requests.Session(); self.s.headers.update(HEAD)
        self.warm_t=0.0; self.last_good=None; self.last_error=None
        self.failures=0; self.next_retry_at=0.0

    def _reset(self):
        """Replace the HTTP session to discard cookies and reset the warm-up time."""
        try: self.s.close()
        except Exception: pass
        self.s=requests.Session(); self.s.headers.update(HEAD); self.warm_t=0.0

    def _warm(self):
        """Visit NSE pages to acquire cookies and record the warm-up time."""
        self.s.get(BASE+"/",timeout=10)
        self.s.get(BASE+"/option-chain",timeout=10)
        self.warm_t=time.time()

    def _get_once(self,url):
        """Fetch JSON, refreshing cookies once on auth/rate-limit or non-JSON responses."""
        if time.time()-self.warm_t>240:
            self._warm()
        r=self.s.get(url,timeout=12)
        text=r.text.lstrip()
        if r.status_code in (401,403,429) or not text.startswith(("{","[")):
            self._reset(); self._warm()
            r=self.s.get(url,timeout=12)
        r.raise_for_status()
        return r.json()

    def _get(self,url):
        """Fetch JSON with up to three attempts and bounded exponential delays.

        Raise RuntimeError during an active backoff or after exhausting retries;
        record the last error and schedule a cooldown after repeated failures."""
        if time.time()<self.next_retry_at:
            raise RuntimeError(f"NSE backoff active for {round(self.next_retry_at-time.time(),1)}s")
        last=None
        for attempt in range(3):
            try:
                result=self._get_once(url)
                self.failures=0; self.next_retry_at=0.0; self.last_error=None
                return result
            except Exception as e:
                last=e; self.failures+=1
                if attempt<2:
                    delay=min(8.0,2.0**attempt)
                    self.next_retry_at=time.time()+delay
                    time.sleep(delay)
                    self._reset()
        self.last_error=str(last)
        self.next_retry_at=time.time()+min(120.0,15.0*(2**min(self.failures-1,3)))
        raise RuntimeError(str(last))

    def fetch(self,symbol="NIFTY"):
        """Fetch and cache the nearest-expiry chain with spot, timestamp, and sorted legs."""
        info=self._get(f"{BASE}/api/option-chain-contract-info?symbol={symbol}")
        expiry=info["expiryDates"][0]
        try:
            j=self._get(f"{BASE}/api/option-chain-v3?type=Indices&symbol={symbol}&expiry={expiry}")
        except Exception:
            j=self._get(f"{BASE}/api/option-chain-indices?symbol={symbol}")
        rec=j["records"]; rows=[]
        for d in rec["data"]:
            if d.get("expiryDate",expiry)!=expiry: continue
            rows.append({"strike":float(d["strikePrice"]),"ce":self._leg(d.get("CE")),"pe":self._leg(d.get("PE"))})
        rows.sort(key=lambda r:r["strike"])
        spot=float(rec.get("underlyingValue") or next((d["CE"]["underlyingValue"] for d in rec["data"] if d.get("CE")),0))
        result={"ts":time.time(),"spot":spot,"expiry":expiry,"rows":rows,"source":"NSE"}
        self.last_good=result
        return result

    def fetch_safe(self,symbol="NIFTY"):
        """Fetch a chain, falling back to the last good result on failure.

        The fallback retains its original timestamp and includes fetch_error.
        Re-raise the fetch error when no cached result is available."""
        try:
            return self.fetch(symbol)
        except Exception as e:
            self.last_error=str(e)
            if self.last_good:
                return {**self.last_good,"fetch_error":str(e)[:240]}
            raise

    @staticmethod
    def _leg(x):
        """Normalize NSE option fields to floats, defaulting missing fields to zero."""
        x=x or {}
        return {"oi":float(x.get("openInterest",0)),"chg_oi":float(x.get("changeinOpenInterest",0)),
                "ltp":float(x.get("lastPrice",0)),"chg":float(x.get("change",0)),
                "iv":float(x.get("impliedVolatility",0)),"vol":float(x.get("totalTradedVolume",0))}
