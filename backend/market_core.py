"""Shared NSE/Angel market core.

One process, one in-memory snapshot store.
Writers: Angel WebSocket/REST + NSE background poll.
Readers: APK REST + read-only MCP.
Requests never call NSE/Angel; they only read memory.
"""
from __future__ import annotations
import os, time, threading
from copy import deepcopy
from fastapi import APIRouter
from fastapi.responses import JSONResponse
from mcp.server import MCPServer

INDICES=("NIFTY","BANKNIFTY","FINNIFTY","MIDCPNIFTY","SENSEX","BANKEX")
STALE_SEC=float(os.getenv("MARKET_STALE_SEC","15"))
MCP_AUTH=os.getenv("MCP_AUTH_TOKEN","").strip()
MAX_ROWS=int(os.getenv("MARKET_CORE_MAX_ROWS","42"))
SOURCE_PRIORITY={"nse":1,"angel_rest":2,"angel_ws":3}
LOCK=threading.RLock()
STORE={}

def _idx(index):
    s=str(index or "NIFTY").upper().replace(" ","")
    return {"NIFTY50":"NIFTY","NIFTYBANK":"BANKNIFTY","BANKNIFTY":"BANKNIFTY",
            "FINNIFTY":"FINNIFTY","MIDCAPSELECT":"MIDCPNIFTY","MIDCPNIFTY":"MIDCPNIFTY",
            "SENSEX":"SENSEX","BANKEX":"BANKEX"}.get(s,s)

def _ts(value):
    try: return float(value)
    except (TypeError,ValueError): return time.time()

def _fresh(ts):
    return bool(ts and time.time()-float(ts)<=STALE_SEC)

def _ensure(index):
    return STORE.setdefault(_idx(index),{"spot":None,"atm":None,"expiry":None,"ts":0.0,
                                         "source":None,"source_ts":{},"rows":{}})

def put(index,strike,side,src,ts=None,**values):
    side=str(side or "").upper()
    if side not in ("CE","PE"): return False
    try: strike=float(strike)
    except (TypeError,ValueError): return False
    incoming=_ts(ts)
    with LOCK:
        idx=_ensure(index); legs=idx["rows"].setdefault(strike,{})
        leg=legs.setdefault(side,{"ts":0.0,"source":None})
        current_ts=float(leg.get("ts",0.0)); current_src=str(leg.get("source") or "")
        if incoming<current_ts: return False
        if current_src=="angel_ws" and src=="nse" and time.time()-current_ts<=STALE_SEC: return False
        if incoming==current_ts and SOURCE_PRIORITY.get(src,0)<SOURCE_PRIORITY.get(current_src,0): return False
        leg.update({k:v for k,v in values.items() if v is not None})
        leg["ts"]=incoming; leg["source"]=src
        idx["ts"]=max(float(idx["ts"]),incoming); idx["source"]=src
        return True

def put_spot(index,spot,src,ts=None,atm=None,expiry=None):
    incoming=_ts(ts)
    with LOCK:
        idx=_ensure(index)
        current_ts=float(idx["source_ts"].get("spot",0.0)); current_src=str(idx.get("source") or "")
        if incoming<current_ts: return False
        if current_src=="angel_ws" and src=="nse" and time.time()-current_ts<=STALE_SEC: return False
        if incoming==current_ts and SOURCE_PRIORITY.get(src,0)<SOURCE_PRIORITY.get(current_src,0): return False
        if spot is not None: idx["spot"]=float(spot)
        if atm is not None: idx["atm"]=float(atm)
        if expiry is not None: idx["expiry"]=expiry
        idx["source_ts"]["spot"]=incoming; idx["source"]=src
        idx["ts"]=max(float(idx["ts"]),incoming)
        return True

def ingest_chain(payload,src):
    if not isinstance(payload,dict): return 0
    index=_idx(payload.get("symbol") or payload.get("index") or "NIFTY")
    ts=_ts(payload.get("ts"))
    put_spot(index,payload.get("spot"),src,ts,payload.get("atm"),payload.get("expiry"))
    count=0
    for row in payload.get("rows",[]) or []:
        for side in ("CE","PE"):
            leg=row.get(side.lower()) if isinstance(row.get(side.lower()),dict) else None
            if leg is None and row.get("type")==side: leg=row
            if not leg: continue
            count+=int(put(index,row.get("strike"),side,src,ts,
                           ltp=leg.get("ltp"),oi=leg.get("oi"),
                           volume=leg.get("volume") or leg.get("vol"),
                           open=leg.get("open"),high=leg.get("high"),low=leg.get("low"),
                           close=leg.get("close"),iv=leg.get("iv"),chg=leg.get("chg"),
                           chg_oi=leg.get("chg_oi"),oiChangePct=leg.get("oiChangePct"),
                           symbol=leg.get("symbol") or row.get("symbol"),
                           token=leg.get("token") or row.get("token")))
    # Angel flat rows are also supported.
    if not count:
        for row in payload.get("rows",[]) or []:
            side=row.get("type") or row.get("side")
            if side:
                count+=int(put(index,row.get("strike"),side,src,ts,
                               ltp=row.get("ltp"),oi=row.get("oi"),
                               volume=row.get("volume") or row.get("vol"),
                               open=row.get("open"),high=row.get("high"),low=row.get("low"),
                               close=row.get("close"),oiChangePct=row.get("oiChangePct"),
                               symbol=row.get("symbol"),token=row.get("token")))
    return count

def ingest_angel_snapshot(index,snapshot):
    if not isinstance(snapshot,dict): return 0
    ts=_ts(snapshot.get("ts")); spot=snapshot.get("spot")
    put_spot(index,spot,"angel_ws",ts,snapshot.get("atm"),snapshot.get("expiry"))
    count=0
    for key,q in (snapshot.get("opts") or {}).items():
        try:
            strike,side=key
            count+=int(put(index,strike,side,"angel_ws",ts,
                           ltp=q.get("ltp"),oi=q.get("oi"),volume=q.get("vol"),
                           open_interest=q.get("oi")))
        except (TypeError,ValueError): continue
    return count

def snapshot(index,limit=MAX_ROWS,include_stale=True):
    index=_idx(index); now=time.time()
    with LOCK: idx=deepcopy(_ensure(index))
    rows=[]
    strikes=sorted(idx["rows"].keys())
    if idx.get("atm") is not None and strikes:
        atm=float(idx["atm"])
        strikes=sorted(strikes,key=lambda x:abs(float(x)-atm))[:max(1,min((MAX_ROWS+1)//2,21))]
        strikes=sorted(strikes)
    else:
        strikes=strikes[:max(1,min((MAX_ROWS+1)//2,21))]
    for strike in strikes:
        legs=idx["rows"].get(strike,{})
        for side in ("CE","PE"):
            leg=legs.get(side)
            if not leg: continue
            ts=float(leg.get("ts",0)); age=round(max(0,now-ts),2) if ts else None
            stale=not _fresh(ts)
            if include_stale or not stale:
                x=dict(leg); x.update({"strike":float(strike),"type":side,
                                       "age_s":age,"stale":stale})
                rows.append(x)
    rows=rows[:max(1,min(int(limit),MAX_ROWS))]
    spot_ts=float(idx["source_ts"].get("spot",0)); spot_age=round(max(0,now-spot_ts),2) if spot_ts else None
    fresh_rows=sum(1 for x in rows if not x["stale"])
    data_ok=bool(idx["spot"] is not None and spot_age is not None and spot_age<=STALE_SEC and fresh_rows>=4)
    return {"index":index,"spot":idx["spot"],"atm":idx["atm"],"expiry":idx["expiry"],
            "ts":idx["ts"],"age_s":spot_age,"stale":not bool(spot_age is not None and spot_age<=STALE_SEC),
            "data_ok":data_ok,"source":idx["source"],"fresh_rows":fresh_rows,
            "row_count":len(rows),"rows":rows}

def evidence(index):
    s=snapshot(index,MAX_ROWS,True)
    fresh=[r for r in s["rows"] if not r["stale"]]
    ce=[r for r in fresh if r["type"]=="CE"]; pe=[r for r in fresh if r["type"]=="PE"]
    ce_oi=sum(float(r.get("oi") or 0) for r in ce); pe_oi=sum(float(r.get("oi") or 0) for r in pe)
    pcr=round(pe_oi/ce_oi,4) if ce_oi else None
    top_ce=sorted(ce,key=lambda r:float(r.get("oi") or 0),reverse=True)[:5]
    top_pe=sorted(pe,key=lambda r:float(r.get("oi") or 0),reverse=True)[:5]
    return {"index":s["index"],"data_ok":s["data_ok"],"stale":s["stale"],"age_s":s["age_s"],
            "source":s["source"],"spot":s["spot"],"atm":s["atm"],"expiry":s["expiry"],"pcr":pcr,
            "ce_oi":ce_oi,"pe_oi":pe_oi,"fresh_rows":len(fresh),"total_rows":s["row_count"],
            "top_ce_oi":[{"strike":r["strike"],"oi":r.get("oi"),"ltp":r.get("ltp"),"age_s":r["age_s"]} for r in top_ce],
            "top_pe_oi":[{"strike":r["strike"],"oi":r.get("oi"),"ltp":r.get("ltp"),"age_s":r["age_s"]} for r in top_pe]}

router=APIRouter()

@router.get("/api/chain/{index}")
def api_chain(index:str):
    return snapshot(index)

@router.get("/api/evidence/{index}")
def api_evidence(index:str):
    return evidence(index)

@router.get("/api/market-core/health")
def core_health():
    with LOCK:
        counts={k:sum(len(vv) for vv in v["rows"].values()) for k,v in STORE.items()}
    return {"ok":True,"store_indexes":counts,"stale_sec":STALE_SEC,
            "mcp_auth_configured":bool(MCP_AUTH),"reader":"memory_only"}

mcp=MCPServer("NSE Market Core",
              instructions="Read-only market evidence from the shared in-memory store. No external calls and no order placement.")

@mcp.tool()
def get_chain(index:str="NIFTY",limit:int=MAX_ROWS)->dict:
    """Return the latest bounded option-chain snapshot from memory."""
    return snapshot(index,max(1,min(int(limit),MAX_ROWS)))

@mcp.tool()
def get_evidence(index:str="NIFTY")->dict:
    """Return compact PCR, OI-wall and freshness evidence from memory."""
    return evidence(index)

def mcp_http_app():
    # Mounted at the parent application's root with /mcp as the MCP path.
    # host=0.0.0.0 prevents the SDK's localhost-only host check on Render.
    return mcp.streamable_http_app(streamable_http_path="/mcp",
                                   host="0.0.0.0",json_response=True,stateless_http=True)

def mount_mcp(app):
    app.mount("/",mcp_http_app())
    return app

def install_mcp_auth(app):
    @app.middleware("http")
    async def _mcp_guard(request,call_next):
        if request.url.path.startswith("/mcp"):
            expected=os.getenv("MCP_AUTH_TOKEN","").strip()
            supplied=request.headers.get("x-mcp-token","").strip()
            bearer=request.headers.get("authorization","")
            if not supplied and bearer.lower().startswith("bearer "):
                supplied=bearer[7:].strip()
            if not expected or supplied!=expected:
                return JSONResponse({"detail":"MCP authentication required"},status_code=401)
        return await call_next(request)


def bind_angel_tick(index,strike,side,**data):
    """Receive a single Angel WebSocket tick into the shared store."""
    return put(index,strike,side,"angel_ws",**data)
