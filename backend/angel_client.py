"""Angel One SmartAPI wrapper: login, option-chain tokens, live LTP/OI snapshots."""
import json, os, time, urllib.request, datetime as dt
import pyotp
from SmartApi import SmartConnect
import config as C

MASTER_URL="https://margincalculator.angelbroking.com/OpenAPI_File/files/OpenAPIScripMaster.json"
INDEX={"NIFTY":"99926000","BANKNIFTY":"99926009","FINNIFTY":"99926037"}
CACHE="scrip_master.json"

class AngelClient:
    def __init__(self):
        self.api=None; self.chain={}; self.strikes=[]; self.expiry=None
    def login(self, api_key=None, client_code=None, pin=None, totp=None):
        api_key=api_key or C.API_KEY; client_code=client_code or C.CLIENT; pin=pin or C.PIN
        totp=totp or (pyotp.TOTP(C.TOTP_SECRET).now() if C.TOTP_SECRET else None)
        if not api_key or not client_code or not pin or not totp:
            raise RuntimeError("Angel credentials are not configured.")
        self.api=SmartConnect(api_key=api_key)
        d=self.api.generateSession(client_code,pin,totp)
        if not d.get("status"):
            self.api=None
            raise RuntimeError(f"Angel login failed: {d.get('message', d)}")
        self.build_chain()
        return d
    def _master(self):
        fresh=os.path.exists(CACHE) and time.time()-os.path.getmtime(CACHE)<43200
        if not fresh: urllib.request.urlretrieve(MASTER_URL,CACHE)
        with open(CACHE) as f: return json.load(f)
    def build_chain(self):
        today=dt.date.today()
        rows=[r for r in self._master() if r["name"]==C.SYMBOL and r["exch_seg"]=="NFO" and r["instrumenttype"]=="OPTIDX"]
        def exp(r): return dt.datetime.strptime(r["expiry"],"%d%b%Y").date()
        expiries=sorted({exp(r) for r in rows if exp(r)>=today})
        if not expiries: raise RuntimeError(f"No active {C.SYMBOL} option expiry found.")
        self.expiry=expiries[0]; self.chain={}
        for r in rows:
            if exp(r)!=self.expiry: continue
            strike=float(r["strike"])/100; typ=r["symbol"][-2:]
            self.chain[(strike,typ)]={"token":r["token"],"symbol":r["symbol"]}
        self.strikes=sorted({k[0] for k in self.chain})
    def spot(self):
        r=self.api.getMarketData("LTP",{"NSE":[INDEX[C.SYMBOL]]})
        return float(r["data"]["fetched"][0]["ltp"])
    def snapshot(self):
        if self.api is None: raise RuntimeError("Angel session is not connected.")
        spot=self.spot(); atm=min(self.strikes,key=lambda s:abs(s-spot)); i=self.strikes.index(atm)
        sel=self.strikes[max(0,i-C.N):i+C.N+1]; tok2key={}
        for s in sel:
            for t in ("CE","PE"):
                if (s,t) in self.chain: tok2key[self.chain[(s,t)]["token"]]=(s,t)
        opts={}; toks=list(tok2key)
        for j in range(0,len(toks),50):
            r=self.api.getMarketData("FULL",{"NFO":toks[j:j+50]})
            for q in r["data"]["fetched"]:
                k=tok2key.get(q["symbolToken"])
                if k: opts[k]={"ltp":float(q["ltp"]),"oi":float(q.get("opnInterest",0)),"vol":float(q.get("tradeVolume",0))}
        return {"ts":time.time(),"spot":spot,"atm":atm,"opts":opts}
