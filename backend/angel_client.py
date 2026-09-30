"""Angel One SmartAPI wrapper: login, option-chain tokens, live LTP/OI snapshots."""
import json, os, time, urllib.request, datetime as dt
import pyotp
from SmartApi import SmartConnect
import config as C

MASTER_URL="https://margincalculator.angelbroking.com/OpenAPI_File/files/OpenAPIScripMaster.json"
INDEX={"NIFTY":"99926000","BANKNIFTY":"99926009","FINNIFTY":"99926037","SENSEX":"99919000"}
CACHE="scrip_master.json"

class AngelClient:
    def __init__(self):
        self.api=None; self.chain={}; self.strikes=[]; self.expiry=None; self.chain_symbol=C.SYMBOL; self.chain_exchange="NFO"
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
    def _symbol_config(self, symbol):
        s=(symbol or C.SYMBOL).upper().replace(" ","")
        aliases={"NIFTY50":"NIFTY","NIFTY":"NIFTY","BANKNIFTY":"BANKNIFTY","FINNIFTY":"FINNIFTY",
                 "MIDCPNIFTY":"MIDCPNIFTY","MIDCAPSELECT":"MIDCPNIFTY","SENSEX":"SENSEX","BANKEX":"BANKEX"}
        s=aliases.get(s,s)
        if s in ("SENSEX","BANKEX"): return s,"BFO"
        return s,"NFO"

    def build_chain(self, symbol=None):
        symbol, exchange=self._symbol_config(symbol)
        today=dt.date.today()
        master=self._master()
        rows=[r for r in master if str(r.get("name","")).upper()==symbol and r.get("exch_seg")==exchange and r.get("instrumenttype")=="OPTIDX"]
        if not rows and symbol=="MIDCPNIFTY":
            rows=[r for r in master if str(r.get("name","")).upper() in ("MIDCPNIFTY","MIDCPNIFTY") and r.get("exch_seg")==exchange and r.get("instrumenttype")=="OPTIDX"]
        def exp(r): return dt.datetime.strptime(r["expiry"],"%d%b%Y").date()
        expiries=sorted({exp(r) for r in rows if r.get("expiry") and exp(r)>=today})
        if not expiries: raise RuntimeError(f"No active {symbol} option expiry found in {exchange}.")
        self.expiry=expiries[0]; self.chain={}; self.chain_symbol=symbol; self.chain_exchange=exchange
        for r in rows:
            if exp(r)!=self.expiry: continue
            strike=float(r["strike"])/100; typ=str(r["symbol"])[-2:]
            if typ in ("CE","PE"): self.chain[(strike,typ)]={"token":r["token"],"symbol":r["symbol"]}
        self.strikes=sorted({k[0] for k in self.chain})

    def _index_token(self, symbol):
        symbol,_=self._symbol_config(symbol)
        if symbol in INDEX: return INDEX[symbol]
        master=self._master()
        aliases={"MIDCPNIFTY":["MIDCPNIFTY","MIDCAP SELECT","NIFTY MID SELECT"],"BANKEX":["BANKEX"]}
        wanted=[symbol]+aliases.get(symbol,[])
        for r in master:
            if r.get("exch_seg") not in ("NSE","BSE") or r.get("instrumenttype")!="AMXIDX": continue
            name=str(r.get("name","")).upper(); sym=str(r.get("symbol","")).upper()
            if any(w.upper() in name or w.upper() in sym for w in wanted):
                return str(r.get("token"))
        raise RuntimeError(f"Index token not found for {symbol}.")

    def spot(self, symbol=None):
        symbol,exchange=self._symbol_config(symbol)
        token=self._index_token(symbol)
        r=self.api.getMarketData("LTP",{exchange:[token]})
        return float(r["data"]["fetched"][0]["ltp"])

    def require_api(self):
        if self.api is None:
            raise RuntimeError("Angel One session is not connected.")
        return self.api

    def index_catalog(self):
        master=self._master()
        rows=[]; seen=set()
        for r in master:
            if r.get("instrumenttype")=="AMXIDX" and r.get("exch_seg") in ("NSE","BSE"):
                token=str(r.get("token",""))
                if not token or token in seen: continue
                seen.add(token)
                rows.append({"token":token,"name":r.get("name") or r.get("symbol"),"symbol":r.get("symbol"),"exchange":r.get("exch_seg")})
        fixed=[
            {"token":"99926000","name":"NIFTY 50","symbol":"Nifty 50","exchange":"NSE"},
            {"token":"99926009","name":"NIFTY BANK","symbol":"Nifty Bank","exchange":"NSE"},
            {"token":"99926037","name":"NIFTY FIN SERVICE","symbol":"Nifty Fin Service","exchange":"NSE"},
            {"token":"99919000","name":"SENSEX","symbol":"SENSEX","exchange":"BSE"}]
        bytoken={r["token"]:r for r in rows}
        for r in fixed: bytoken[r["token"]]=r
        return sorted(bytoken.values(),key=lambda x:(x["exchange"],x["name"] or ""))

    def index_catalog_quotes(self):
        api=self.require_api(); instruments=self.index_catalog(); grouped={"NSE":[],"BSE":[]}
        for r in instruments: grouped[r["exchange"]].append(r["token"])
        fetched=[]
        for exchange,tokens in grouped.items():
            for i in range(0,len(tokens),40):
                batch=tokens[i:i+40]
                if batch:
                    result=api.getMarketData("FULL",{exchange:batch})
                    fetched.extend(result.get("data",{}).get("fetched",[]) or [])
        q={str(r.get("symbolToken")):r for r in fetched}
        return {"data":[{**inst,"ltp":q.get(inst["token"],{}).get("ltp"),"open":q.get(inst["token"],{}).get("open"),"high":q.get(inst["token"],{}).get("high"),"low":q.get(inst["token"],{}).get("low"),"close":q.get(inst["token"],{}).get("close"),"netChange":q.get(inst["token"],{}).get("netChange"),"percentChange":q.get(inst["token"],{}).get("percentChange"),"volume":q.get(inst["token"],{}).get("tradeVolume")} for inst in instruments]}

    def index_quote(self, symbols=None):
        api=self.require_api()
        symbols=symbols or {
            "NIFTY":"99926000","BANKNIFTY":"99926009","FINNIFTY":"99926037",
            "SENSEX":"99919000"
        }
        tokens=list(symbols.values())
        result=api.getMarketData("FULL", {"NSE": [t for t in tokens if t!="99919000"], "BSE":["99919000"]})
        return result

    def candles(self, exchange, token, interval="FIVE_MINUTE", days=1):
        api=self.require_api()
        now=dt.datetime.now(dt.timezone(dt.timedelta(hours=5,minutes=30)))
        start=now-dt.timedelta(days=max(1,min(int(days),30)))
        p={"exchange":exchange,"symboltoken":str(token),"interval":interval,
           "fromdate":start.strftime("%Y-%m-%d %H:%M"),"todate":now.strftime("%Y-%m-%d %H:%M")}
        return api.getCandleData(p)

    def oi_history(self, token, interval="THREE_MINUTE", hours=6):
        api=self.require_api()
        now=dt.datetime.now(dt.timezone(dt.timedelta(hours=5,minutes=30)))
        start=now-dt.timedelta(hours=max(1,min(int(hours),24)))
        p={"exchange":"NFO","symboltoken":str(token),"interval":interval,
           "fromdate":start.strftime("%Y-%m-%d %H:%M"),"todate":now.strftime("%Y-%m-%d %H:%M")}
        return api.getOIData(p)

    def option_greeks(self, name, expiry):
        api=self.require_api()
        return api._postRequest("api.optionGreek", {"name":name,"expirydate":expiry})

    def gainers_losers(self, datatype="PercPriceGainers", expirytype="NEAR"):
        api=self.require_api()
        return api._postRequest("api.gainersLosers", {"datatype":datatype,"expirytype":expirytype})

    def oi_buildup(self, datatype="Long Built Up", expirytype="NEAR"):
        api=self.require_api()
        return api._postRequest("api.oIBuildup", {"datatype":datatype,"expirytype":expirytype})

    def put_call_ratio(self, expirytype="NEAR"):
        api=self.require_api()
        return api._postRequest("api.putCallRatio", {"expirytype":expirytype})

    def search(self, exchange, query):
        return self.require_api().searchScrip(exchange, query)

    def portfolio(self):
        api=self.require_api()
        return {
            "holdings": api.holding(),
            "positions": api.position(),
            "orders": api.orderBook(),
            "trades": api.tradeBook()
        }


    def commodity_quotes(self):
        api=self.require_api()
        master=self._master()
        wanted=("CRUDEOIL","NATURALGAS","GOLD","SILVER","COPPER","ALUMINIUM","ZINC","LEAD")
        today=dt.date.today()
        selected=[]
        for name in wanted:
            candidates=[]
            for r in master:
                if r.get("exch_seg")!="MCX" or not r.get("name","").upper().startswith(name): continue
                exp=r.get("expiry","")
                if exp:
                    try:
                        ed=dt.datetime.strptime(exp,"%d%b%Y").date()
                        if ed>=today: candidates.append((ed,r))
                    except Exception:
                        pass
            if candidates:
                candidates.sort(key=lambda x:x[0])
                selected.append(candidates[0][1])
        tokens=[str(r["token"]) for r in selected]
        if not tokens: return {"data":{"fetched":[],"unfetched":[]},"instruments":[]}
        result=api.getMarketData("FULL",{"MCX":tokens})
        by={str(r["symbolToken"]):r for r in result.get("data",{}).get("fetched",[])}
        rows=[]
        for r in selected:
            q=by.get(str(r["token"]))
            if q:
                rows.append({"name":r.get("name"),"tradingSymbol":r.get("symbol"),"token":str(r["token"]),
                             "expiry":r.get("expiry"),"ltp":q.get("ltp"),"open":q.get("open"),
                             "high":q.get("high"),"low":q.get("low"),"close":q.get("close"),
                             "volume":q.get("tradeVolume"),"oi":q.get("opnInterest")})
        return {"data":{"fetched":rows,"unfetched":[]},"instruments":selected}

    def option_chain_rows(self, symbol=None, around=None, count=10):
        self.require_api()
        requested,_=self._symbol_config(symbol)
        if not self.chain or self.chain_symbol!=requested:
            self.build_chain(requested)
        spot=self.spot(requested)
        atm=around if around is not None else min(self.strikes,key=lambda s:abs(s-spot))
        idx=min(range(len(self.strikes)),key=lambda i:abs(self.strikes[i]-atm))
        count=max(10,min(int(count),250))
        selected=self.strikes[max(0,idx-count):idx+count+1]
        token_map={}
        for strike in selected:
            for typ in ("CE","PE"):
                item=self.chain.get((strike,typ))
                if item: token_map[item["token"]]=(strike,typ,item["symbol"])
        rows=[]
        toks=list(token_map)
        for j in range(0,len(toks),50):
            result=self.api.getMarketData("FULL",{self.chain_exchange:toks[j:j+50]})
            for q in result.get("data",{}).get("fetched",[]) or []:
                item=token_map.get(str(q.get("symbolToken")))
                if not item: continue
                strike,typ,sym=item
                rows.append({"strike":strike,"type":typ,"symbol":sym,"token":str(q.get("symbolToken")),
                             "ltp":q.get("ltp"),"open":q.get("open"),"high":q.get("high"),"low":q.get("low"),
                             "close":q.get("close"),"oi":q.get("opnInterest"),"volume":q.get("tradeVolume"),
                             "buyQty":q.get("totalBuyQuantity"),"sellQty":q.get("totalSellQuantity"),
                             "netChange":q.get("netChange"),"priceChange":q.get("netChange")})
        rows.sort(key=lambda r:(float(r["strike"]),0 if r["type"]=="CE" else 1))
        return {"symbol":requested,"exchange":self.chain_exchange,"spot":spot,"atm":atm,"expiry":str(self.expiry),"rows":rows}

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
