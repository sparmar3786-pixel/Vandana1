"""Network/API gateway for NSE Algo Signal. PAPER signals only; no order placement."""
import asyncio,threading,time,datetime as dt,os
from typing import Optional
from fastapi import FastAPI,Header,HTTPException,Response
from fastapi.middleware.gzip import GZipMiddleware
from pydantic import BaseModel
import uvicorn
import config as C
from angel_client import AngelClient
from signals import Engine
from nse_client import NSEClient
import nse_features
from nse_mcp import NSEMCP,result_to_csv
from ai_model import p_up,label
from ai_orchestrator import provider_status, validate_all, NSE_SITE_URL, _nse_site_evidence
from market_core import router as market_core_router, ingest_chain, put_spot, evidence as market_evidence, mount_mcp, install_mcp_auth
from strategy_api import router as strategy_router
from council import router as council_router
from notifier import router as alert_router, alert_loop
from strategy_store import save_oi_snapshot
from strategy_mcp_server import mount_strategy_mcp

app=FastAPI(title="NSE Algo Signal API"); app.add_middleware(GZipMiddleware,minimum_size=1024); app.include_router(strategy_router); app.include_router(market_core_router); app.include_router(council_router); app.include_router(alert_router); eng=Engine(); client=AngelClient(); nse=NSEClient(); nse_mcp=NSEMCP()
state={"error":None,"nse_error":None,"last_update":None,"angel_message":"Not connected","nse_mcp_error":None}
prev_chain={"c":None}; workers_started=False; last_oi_save=0.0

# Two read-only MCP servers live in this same Railway/Fly process.
# /mcp serves the shared market snapshot; /mcp-strategy serves strategy evidence/backtests.
mount_mcp(app)
mount_strategy_mcp(app)
install_mcp_auth(app)

class AIValidationRequest(BaseModel):
    payload:dict = {}

class AngelLoginRequest(BaseModel):
    # The APK uses clientId/pin/totp/apiKey. clientCode is accepted as a
    # compatibility alias for simple Railway clients.
    clientId:Optional[str]=None
    clientCode:Optional[str]=None
    pin:str
    totp:str
    apiKey:Optional[str]=None

    @property
    def client_code(self) -> str:
        return (self.clientId or self.clientCode or "").strip()

def market_open():
    now=dt.datetime.now(dt.timezone(dt.timedelta(hours=5,minutes=30)))
    return now.weekday()<5 and dt.time(9,15)<=now.time()<=dt.time(15,30)

@app.on_event("startup")
def start_workers():
    global workers_started
    if workers_started:
        return
    workers_started = True
    threading.Thread(target=loop, daemon=True, name="angel-data-loop").start()
    threading.Thread(target=nse_loop, daemon=True, name="nse-data-loop").start()
    asyncio.create_task(alert_loop(), name="qualified-alert-loop")

def _ensure_angel():
    # App login is the normal path. Only auto-login on startup when complete
    # server-side Angel credentials are configured in Railway environment.
    if client.api is None and C.API_KEY and C.CLIENT and C.PIN and C.TOTP_SECRET:
        client.login()
        state["angel_message"]="Connected using server credentials (6h session reuse)."

def loop():
    global last_oi_save
    while True:
        try:
            _ensure_angel()
            if market_open():
                snap=client.snapshot()
                eng.update(snap); state["last_update"]=time.time(); state["error"]=None
                if time.time()-last_oi_save >= max(60, min(180, int(C.NSE_POLL_SEC))):
                    try:
                        save_oi_snapshot(C.SYMBOL, snap)
                        last_oi_save=time.time()
                    except Exception:
                        pass
        except Exception as e:
            state["error"]=str(e); state["angel_message"]="Angel connection failed."; client.api=None; time.sleep(10)
        time.sleep(C.POLL_SEC)

def nse_loop():
    while True:
        try:
            if market_open():
                ch=nse.fetch(C.SYMBOL)
                features=nse_features.compute(ch,prev_chain["c"]); prev_chain["c"]=ch
                eng.set_nse(features,ch["ts"])
                ingest_chain(ch,"nse")
                state["nse_error"]=None
        except Exception as e: state["nse_error"]=str(e)
        time.sleep(C.NSE_POLL_SEC)

def auth(x_token:str):
    if x_token!=C.API_TOKEN: raise HTTPException(401,"bad token")

@app.get("/health")
def health():
    return {"ok":True,"market_open":market_open(),"angel_connected":client.api is not None,"angel_message":state["angel_message"],"nse_mcp":"configured","last_update":state["last_update"],"error":state["error"],"nse_error":state["nse_error"],"nse_mcp_error":state["nse_mcp_error"]}

@app.post("/v1/angel/login")
@app.post("/angel/login")
def angel_login(body:AngelLoginRequest,x_token:str=Header(None)):
    auth(x_token)
    client_code=body.client_code
    if not client_code: raise HTTPException(400,"Client ID is required.")
    if len(body.totp)!=6 or not body.totp.isdigit(): raise HTTPException(400,"TOTP must be the current 6-digit code.")
    try:
        result=client.login(api_key=body.apiKey or C.API_KEY,client_code=client_code,pin=body.pin,totp=body.totp)
        reused=bool(result.get("data",{}).get("session_reused"))
        state["angel_message"]="Angel One session reused (6h)." if reused else "Angel One connected."
        state["error"]=None
        return {"ok":True,"connected":True,"session_reused":reused,"message":"Existing Angel session reused." if reused else "Angel One connected.","profile":result.get("data",{}).get("clientcode")}
    except Exception:
        client.api=None; client.session_started=0.0; state["angel_message"]="Angel connection failed."; state["error"]="Angel login failed"
        raise HTTPException(401,"Angel login failed. Check Client ID, PIN, TOTP and API key.")

@app.get("/v1/angel/status")
@app.get("/angel/status")
def angel_status(x_token:str=Header(None)):
    auth(x_token); return {"connected":client.api is not None,"message":state["angel_message"],"last_update":state["last_update"],"error":state["error"]}


def angel_required():
    if client.api is None:
        raise HTTPException(503,"Angel One is not connected. Connect from Angel API screen first.")

@app.get("/v1/angel/commodities")
def angel_commodities(x_token:str=Header(None)):
    auth(x_token); angel_required()
    try: return client.commodity_quotes()
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/indices")
def angel_indices(x_token:str=Header(None)):
    auth(x_token); angel_required()
    try: return client.index_catalog_quotes()
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/market")
def angel_market(x_token:str=Header(None)):
    auth(x_token); angel_required()
    try:
        return client.index_quote()
    except Exception as e:
        raise HTTPException(502,str(e))

@app.get("/v1/angel/candles")
def angel_candles(exchange:str="NSE",token:str="99926000",interval:str="FIVE_MINUTE",days:int=1,x_token:str=Header(None)):
    auth(x_token); angel_required()
    allowed={"ONE_MINUTE","THREE_MINUTE","FIVE_MINUTE","TEN_MINUTE","FIFTEEN_MINUTE","THIRTY_MINUTE","ONE_HOUR","ONE_DAY"}
    if interval not in allowed: raise HTTPException(400,"Unsupported interval")
    try: return client.candles(exchange,token,interval,days)
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/option-chain")
def unified_option_chain(symbol:str="NIFTY",count:int=10,x_token:str=Header(None)):
    auth(x_token); angel_required()
    aliases={"NIFTY 50":"NIFTY","NIFTYBANK":"BANKNIFTY","BANK NIFTY":"BANKNIFTY","MIDCAP SELECT":"MIDCPNIFTY"}
    key=symbol.upper().replace(" ","")
    key=aliases.get(symbol.upper(), aliases.get(key,key))
    try:
        result=client.option_chain_rows(symbol=key,count=max(5,min(count,25)))
        rows=result.get("rows",[]) if isinstance(result,dict) else []
        return {**result,"source":"Angel One SmartAPI","rows":rows}
    except Exception as e:
        raise HTTPException(502,"Option chain unavailable: "+str(e))

@app.get("/v1/angel/option-chain")
def angel_option_chain(symbol:str="NIFTY",count:int=200,x_token:str=Header(None)):
    auth(x_token); angel_required()
    allowed={"NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY","MIDCAPSELECT","SENSEX","BANKEX"}
    symbol=symbol.upper().replace(" ","")
    if symbol not in allowed: raise HTTPException(400,"Unsupported index")
    try:
        result=client.option_chain_rows(symbol=symbol,count=max(10,min(count,250)))
        # Angel's Option Greeks endpoint is currently NSE-only. Enrich NSE rows when live expiry data is available.
        if symbol in {"NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY","MIDCAPSELECT"} and result.get("expiry"):
            try:
                expiry_value=str(result["expiry"])
                try:
                    expiry_value=dt.datetime.fromisoformat(expiry_value).strftime("%d%b%Y").upper()
                except Exception:
                    expiry_value=expiry_value.upper()
                gd=client.option_greeks(symbol, expiry_value)
                greeks=gd.get("data",[]) if isinstance(gd,dict) else []
                gm={(float(g.get("strikePrice")),str(g.get("optionType")).upper()):g for g in greeks if isinstance(g,dict) and g.get("strikePrice") is not None}
                for row in result.get("rows",[]):
                    g=gm.get((float(row.get("strike")),str(row.get("type")).upper()))
                    if g:
                        row.update({"delta":g.get("delta"),"gamma":g.get("gamma"),"theta":g.get("theta"),"vega":g.get("vega"),"iv":g.get("impliedVolatility")})
            except Exception:
                pass
        return result
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/oi")
def angel_oi(token:str,interval:str="THREE_MINUTE",hours:int=6,x_token:str=Header(None)):
    auth(x_token); angel_required()
    try: return client.oi_history(token,interval,hours)
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/search")
def angel_search(exchange:str="NSE",q:str="",x_token:str=Header(None)):
    auth(x_token); angel_required()
    if not q.strip(): raise HTTPException(400,"Search query is required")
    try: return client.search(exchange,q.strip())
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/portfolio")
def angel_portfolio(x_token:str=Header(None)):
    auth(x_token); angel_required()
    try: return client.portfolio()
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/gainers-losers")
def angel_gainers_losers(datatype:str="PercPriceGainers",expirytype:str="NEAR",x_token:str=Header(None)):
    auth(x_token); angel_required()
    try: return client.gainers_losers(datatype,expirytype)
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/oi-buildup")
def angel_oi_buildup(datatype:str="Long Built Up",expirytype:str="NEAR",x_token:str=Header(None)):
    auth(x_token); angel_required()
    try: return client.oi_buildup(datatype,expirytype)
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/angel/greeks")
def angel_greeks(name:str="NIFTY",expiry:str="",x_token:str=Header(None)):
    auth(x_token); angel_required()
    if not expiry: raise HTTPException(400,"Expiry is required")
    try: return client.option_greeks(name,expiry)
    except Exception as e: raise HTTPException(502,str(e))

@app.get("/v1/mcp/status")
def mcp_status(x_token:str=Header(None)):
    auth(x_token)
    return {
        "market_mcp":{"mounted":True,"endpoint":"/mcp","auth":"x-mcp-token or Bearer"},
        "strategy_mcp":{"mounted":True,"endpoint":"/mcp-strategy","auth":"x-mcp-token or Bearer"},
        "official_nse_mcp":{"configured":True,"endpoint":nse_mcp.url},
        "paper_only":True,"orders_enabled":False,
    }

@app.get("/v1/nse/mcp/tools")
def nse_mcp_tools(x_token:str=Header(None)):
    auth(x_token)
    try:
        tools=nse_mcp.tools()
        state["nse_mcp_error"]=None
        return {"connected":True,"endpoint":nse_mcp.url,"tools":[{"name":t.get("name"),"description":t.get("description")} for t in tools]}
    except Exception as e:
        state["nse_mcp_error"]=str(e)
        raise HTTPException(502,"NSE MCP unavailable")

@app.get("/v1/nse/mcp/context")
def nse_mcp_context(symbol:str="NIFTY",x_token:str=Header(None)):
    auth(x_token)
    try:
        data=nse_mcp.context(symbol.upper())
        state["nse_mcp_error"]=None
        return data
    except Exception as e:
        state["nse_mcp_error"]=str(e)
        return {"connected":False,"endpoint":nse_mcp.url,"tool_count":0,"tools":[],"data":[],"error":str(e)[:500]}
@app.get("/v1/nse/option-chain.csv")
def nse_option_chain_csv(symbol:str="NIFTY",expiry:Optional[str]=None,x_token:str=Header(None)):
    auth(x_token)
    try:
        tool,result=nse_mcp.option_chain(symbol.upper(),expiry)
        state["nse_mcp_error"]=None
        csv=result_to_csv(result)
        return Response(
            content=csv,
            media_type="text/csv",
            headers={"Content-Disposition":f'attachment; filename="{symbol.upper()}_NSE_option_chain.csv"',"X-NSE-MCP-Tool":tool}
        )
    except Exception as e:
        state["nse_mcp_error"]=str(e)
        raise HTTPException(502,str(e))

def _strategy_refresh(index: str = "NIFTY"):
    symbol = str(index or C.SYMBOL).upper().replace(" ", "")
    live = None
    try:
        if client.api is not None:
            live = client.snapshot() if symbol == str(C.SYMBOL).upper() else None
            if live is None:
                chain = client.option_chain_rows(symbol=symbol, count=15)
                live = {"symbol": chain.get("symbol", symbol), "spot": chain.get("spot"), "atm": chain.get("atm"),
                        "expiry": chain.get("expiry"), "opts": {(float(r["strike"]), str(r["type"])): {
                            "ltp": float(r.get("ltp") or 0), "oi": float(r.get("oi") or 0), "vol": float(r.get("volume") or 0)}
                            for r in chain.get("rows", []) if r.get("strike") is not None and r.get("type")}}
    except Exception as e:
        live = None
    if not live:
        last = eng.last if isinstance(eng.last, dict) else {}
        return {"ok":False,"index":symbol,"error":"Live Angel option-chain snapshot unavailable","engine":last,
                "nse":eng.nse_view or {}, "source_status":{"angel":client.api is not None,"nse_mcp":state["nse_mcp_error"] is None}}
    opts=live.get("opts",{}) or {}
    ce=sorted([{"strike":k[0],"ltp":v.get("ltp"),"oi":v.get("oi"),"volume":v.get("vol")} for k,v in opts.items() if k[1]=="CE"],
              key=lambda x: float(x.get("oi") or 0), reverse=True)
    pe=sorted([{"strike":k[0],"ltp":v.get("ltp"),"oi":v.get("oi"),"volume":v.get("vol")} for k,v in opts.items() if k[1]=="PE"],
              key=lambda x: float(x.get("oi") or 0), reverse=True)
    nse=eng.nse_view or {}
    return {"ok":True,"index":live.get("symbol",symbol),"spot":live.get("spot"),"atm":live.get("atm"),
            "expiry":live.get("expiry"),"trend":nse.get("trend","UNAVAILABLE"),"p_up":nse.get("p_up"),
            "pcr":nse.get("pcr"),"support":nse.get("support"),"resistance":nse.get("resistance"),
            "max_pain":nse.get("max_pain"),"score":(eng.last or {}).get("score"),
            "call_oi_zones":ce[:5],"put_oi_zones":pe[:5],
            "potential_call_seller_zone":ce[0] if ce else None,
            "potential_put_seller_zone":pe[0] if pe else None,
            "engine_signal":eng.last,"source_status":{"angel":client.api is not None,"nse_adapter":state["nse_error"] is None,
            "nse_mcp":state["nse_mcp_error"] is None}}

@app.get("/v1/strategy/refresh")
def strategy_refresh(index:str="NIFTY",x_token:str=Header(None)):
    auth(x_token)
    return _strategy_refresh(index)

@app.get("/v1/ai/context")
def ai_context(index:str="NIFTY",x_token:str=Header(None)):
    auth(x_token)
    terminal=terminal_snapshot()
    compact={}
    try:
        compact=market_evidence(index)
    except Exception as e:
        compact={"index":index,"data_ok":False,"error":str(e)}
    mcp={}
    try:
        tool,result=nse_mcp.option_chain(index.upper(),None)
        mcp={"connected":True,"tool":tool,"result":result}
        state["nse_mcp_error"]=None
    except Exception as e:
        mcp={"connected":False,"endpoint":nse_mcp.url,"error":str(e)[:500]}
        state["nse_mcp_error"]=str(e)
    official=_nse_site_evidence({"terminal":terminal,"symbol":index})
    return {"ts":time.time(),"three_sources":{
        "angel_api":{"connected":client.api is not None,"data":terminal.get("market"),"option_chain":terminal.get("option_chain")},
        "nse_mcp":mcp,
        "nse_internet":{"connected":official.get("connected",False),"evidence":official}},
        "market_evidence":compact,"terminal":terminal,
        "ai_rule":"All AI answers must reconcile API + official NSE MCP + Internet evidence; missing/conflicting evidence forces WAIT."}

@app.get("/v1/ai/status")
def ai_status(x_token:str=Header(None)):
    auth(x_token)
    providers=provider_status()
    return {"providers":[{**p,"status":"configured" if p["configured"] else "server key required"} for p in providers],
            "configured":sum(1 for p in providers if p["configured"]),"total":len(providers),
            "nse_official_site":{"url":NSE_SITE_URL,"status":"source_enabled"},
            "local_fallback":True}

@app.post("/v1/ai/validate")
def ai_validate(body:AIValidationRequest,x_token:str=Header(None)):
    auth(x_token)
    payload=body.payload if isinstance(body.payload,dict) else {}
    try:
        return validate_all(payload)
    except Exception as e:
        return {"final":"WAIT","cross_verified":False,"reason":"AI orchestration failed safely; local evidence path remains active.",
                "configured":0,"successful":0,"parsed_states":0,"total":6,"providers":[],
                "local_fallback":{"status":"error_local","text":str(e)[:300]}}

@app.get("/v1/diagnostics")
def diagnostics(x_token:str=Header(None)):
    auth(x_token); providers=ai_status(x_token)["providers"]; ev=getattr(eng,"strategy_evidence",[]) if hasattr(eng,"strategy_evidence") else []
    return {"angel":{"connected":client.api is not None,"message":state["angel_message"]},"nse":{"available":state["nse_error"] is None,"error":state["nse_error"]},"ai":{"configured":sum(1 for p in providers if p["configured"]),"providers":providers},"strategies":{"registered":len(ev),"evaluated":len(ev),"active":sum(1 for x in ev if isinstance(x,dict) and x.get("state")=="active"),"unavailable":sum(1 for x in ev if isinstance(x,dict) and x.get("state")=="unavailable"),"not_evaluated":0}}

@app.get("/v1/strategy/refresh")
def strategy_refresh(x_token:str=Header(None)):
    auth(x_token)
    last=eng.last if isinstance(eng.last,dict) else {}
    nse_view=eng.nse_view if isinstance(eng.nse_view,dict) else {}
    chain=last.get("chain") or last.get("opts") or {}
    try:
        if client.api is not None:
            fresh=client.snapshot()
            chain=fresh.get("opts") or chain
            last={**last,"spot":fresh.get("spot"),"atm":fresh.get("atm")}
    except Exception:
        pass
    rows=[]
    if isinstance(chain,dict):
        for key,val in chain.items():
            try: strike,side=key; item=dict(val); item["strike"]=strike; item["type"]=side; rows.append(item)
            except Exception: pass
    ce=sorted([x for x in rows if x.get("type")=="CE"],key=lambda x:float(x.get("oi") or 0),reverse=True)
    pe=sorted([x for x in rows if x.get("type")=="PE"],key=lambda x:float(x.get("oi") or 0),reverse=True)
    ce_oi=sum(float(x.get("oi") or 0) for x in ce); pe_oi=sum(float(x.get("oi") or 0) for x in pe)
    pcr=(pe_oi/ce_oi) if ce_oi else nse_view.get("pcr")
    return {"timestamp":time.time(),"index":C.SYMBOL,"spot":last.get("spot"),"atm":last.get("atm"),
            "action":last.get("action","WAIT"),"optionSymbol":last.get("optionSymbol"),"ltp":last.get("ltp"),
            "strike":last.get("strike",last.get("atm")),"entry":last.get("entry"),"sl":last.get("sl"),"target":last.get("target"),
            "trend":nse_view.get("trend") or ("UP" if float(last.get("score") or 0)>0 else "DOWN" if float(last.get("score") or 0)<0 else "FLAT"),
            "score":last.get("score"),"pcr":pcr,"support":nse_view.get("support"),"resistance":nse_view.get("resistance"),
            "max_pain":nse_view.get("max_pain"),"ce_total_oi":ce_oi,"pe_total_oi":pe_oi,
            "call_seller_pressure":ce[:5],"put_seller_pressure":pe[:5],
            "buildup":nse_view,"reasons":last.get("reasons",[]),
            "sources":["Angel One SmartAPI","NSE engine/MCP","Internet AI evidence"]}
@app.get("/v1/audit/latest")
def latest_audit(x_token:str=Header(None)):
    auth(x_token); last=eng.last if isinstance(eng.last,dict) else {}; return {"action":last.get("action","WAIT"),"reasons":last.get("reasons",[]),"timestamp":state["last_update"]}

@app.get("/signal")
def signal(x_token:str=Header(None)): auth(x_token); return terminal_snapshot()

@app.get("/v1/terminal")
def terminal_snapshot_endpoint(x_token:str=Header(None)): auth(x_token); return terminal_snapshot()

def terminal_snapshot():
    last=eng.last if isinstance(eng.last,dict) else {}; nse_view=eng.nse_view if isinstance(eng.nse_view,dict) else {}
    return {"ts":time.time(),"market_open":market_open(),"connection":{"angel":client.api is not None,"nse":state["nse_error"] is None,"server":True,"last_update":state["last_update"],"error":state["error"],"nse_error":state["nse_error"],"angel_message":state["angel_message"]},"market":{"symbol":C.SYMBOL,"spot":last.get("spot"),"atm":last.get("strike"),"action":last.get("action","WAIT"),"ltp":last.get("ltp")},"signals":last,"oi_lab":nse_view,"option_chain":last.get("chain",last.get("opts")),"charts":{"spot":last.get("spot"),"ltp":last.get("ltp"),"timestamp":state["last_update"],"source":"Angel One SmartAPI","endpoint":"/v1/angel/candles"},"nse":nse_view,"angel_data":{"market_endpoint":"/v1/angel/market","candles_endpoint":"/v1/angel/candles","option_chain_endpoint":"/v1/angel/option-chain","oi_endpoint":"/v1/angel/oi","search_endpoint":"/v1/angel/search","portfolio_endpoint":"/v1/angel/portfolio","gainers_losers_endpoint":"/v1/angel/gainers-losers","oi_buildup_endpoint":"/v1/angel/oi-buildup","greeks_endpoint":"/v1/angel/greeks"},"nse_mcp":{"status":"official NSE Streamable HTTP MCP","endpoint":nse_mcp.url,"connected":state["nse_mcp_error"] is None,"error":state["nse_mcp_error"],"csv_endpoint":"/v1/nse/option-chain.csv"},"angel_api":{"connected":client.api is not None,"message":state["angel_message"]},"data":last,"instruments":{"source":"Angel One SmartAPI instrument master","loaded":bool(client.chain),"expiry":str(client.expiry) if client.expiry else None,"strike_count":len(client.strikes)},"watchlist":{"source":"Angel One SmartAPI","items":[]},"search":{"source":"Angel One SmartAPI","items":[]},"commodity":{"source":"Angel One SmartAPI","items":[]},"market_details":nse_view,"news":{"source":"server-side news adapter","items":[]},"settings":{"symbol":C.SYMBOL,"poll_sec":C.POLL_SEC,"nse_poll_sec":C.NSE_POLL_SEC},"more":{"paper_only":True,"orders_enabled":False},"error":state["error"],"nse_error":state["nse_error"]}

if __name__=="__main__":
    uvicorn.run(app,host="0.0.0.0",port=8000)
