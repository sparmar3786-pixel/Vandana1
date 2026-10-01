"""Shared in-memory NSE/Angel market store + read-only MCP evidence tools.

One process / one store:
  Angel WebSocket/5s snapshot -> STORE
  NSE background refresh       -> STORE
  APK REST                    -> STORE
  AI MCP                      -> STORE

No order placement. Missing/stale data is surfaced, never invented.
"""
from __future__ import annotations
import os
import time
import threading
from typing import Any
from mcp.server import MCPServer

STALE_SEC=float(os.getenv("MARKET_STALE_SEC","15"))
MAX_CHAIN_ROWS=int(os.getenv("MCP_MAX_CHAIN_ROWS","42"))

class MarketStore:
    def __init__(self, stale_sec=STALE_SEC):
        self.stale_sec=float(stale_sec)
        self._data={}
        self._lock=threading.RLock()

    @staticmethod
    def _ts(value):
        try: return float(value)
        except (TypeError,ValueError): return time.time()

    def _index(self,index):
        key=str(index or "").upper().replace(" ","")
        return self._data.setdefault(key,{"spot":None,"spot_ts":0.0,"source":None,"updated_ts":0.0,"rows":{}})

    def _put_spot_locked(self,idx,spot,ts,source):
        if ts>=float(idx.get("spot_ts",0)):
            idx["spot"]=float(spot); idx["spot_ts"]=ts; idx["source"]=source

    def put(self,index,strike,side,source,ts=None,spot=None,**values):
        side=str(side or "").upper()
        if side not in {"CE","PE"}: return False
        event_ts=self._ts(ts)
        with self._lock:
            idx=self._index(index)
            row=idx["rows"].setdefault(float(strike),{}).get(side)
            if row and event_ts<float(row.get("ts",0)): return False
            clean={k:v for k,v in values.items() if v is not None}
            clean.update({"strike":float(strike),"side":side,"source":source,"ts":event_ts})
            idx["rows"].setdefault(float(strike),{})[side]=clean
            if spot is not None: self._put_spot_locked(idx,spot,event_ts,source)
            idx["updated_ts"]=max(float(idx.get("updated_ts",0)),event_ts)
            return True

    def put_spot(self,index,spot,source,ts=None):
        event_ts=self._ts(ts)
        with self._lock:
            idx=self._index(index)
            if event_ts<float(idx.get("spot_ts",0)): return False
            self._put_spot_locked(idx,spot,event_ts,source)
            idx["updated_ts"]=max(float(idx.get("updated_ts",0)),event_ts)
            return True

    def ingest_angel_snapshot(self,index,snapshot):
        ts=self._ts(snapshot.get("ts")); spot=snapshot.get("spot")
        if spot is not None: self.put_spot(index,spot,"ANGEL_WS",ts)
        count=0
        for key,q in (snapshot.get("opts") or {}).items():
            try:
                strike,side=key
                if self.put(index,strike,side,"ANGEL_WS",ts=ts,spot=spot,
                            ltp=q.get("ltp"),oi=q.get("oi"),volume=q.get("vol"),
                            open_interest=q.get("oi")): count+=1
            except (TypeError,ValueError): continue
        return count

    def ingest_nse(self,index,snapshot):
        ts=self._ts(snapshot.get("ts")); spot=snapshot.get("spot")
        if spot is not None: self.put_spot(index,spot,"NSE",ts)
        count=0
        for row in snapshot.get("rows") or []:
            strike=row.get("strike")
            if strike is None: continue
            for side,leg in (("CE",row.get("ce")),("PE",row.get("pe"))):
                leg=leg or {}
                if self.put(index,strike,side,"NSE",ts=ts,spot=spot,
                            ltp=leg.get("ltp"),oi=leg.get("oi"),
                            volume=leg.get("vol"),chg_oi=leg.get("chg_oi"),
                            iv=leg.get("iv"),chg=leg.get("chg")): count+=1
        return count

    @staticmethod
    def _decorate(row,now,stale_sec):
        out=dict(row); age=max(0.0,now-float(row.get("ts",0)))
        out["age_s"]=round(age,2); out["stale"]=age>stale_sec
        return out

    def snapshot(self,index,limit=MAX_CHAIN_ROWS):
        key=str(index or "").upper().replace(" ",""); now=time.time()
        with self._lock:
            idx=self._data.get(key,{"spot":None,"spot_ts":0,"source":None,"updated_ts":0,"rows":{}})
            rows=[]
            for strike,legs in idx.get("rows",{}).items():
                for side in ("CE","PE"):
                    if side in legs: rows.append(self._decorate(legs[side],now,self.stale_sec))
            rows.sort(key=lambda x:(float(x["strike"]),0 if x["side"]=="CE" else 1))
            rows=rows[:min(max(1,int(limit)),MAX_CHAIN_ROWS)]
            spot_age=max(0.0,now-float(idx.get("spot_ts",0)))
            fresh=[r for r in rows if not r["stale"]]
            return {"index":key,"spot":idx.get("spot"),"source":idx.get("source"),
                    "ts":idx.get("updated_ts",0),"spot_age_s":round(spot_age,2),
                    "stale":spot_age>self.stale_sec,
                    "data_ok":bool(idx.get("spot") is not None and spot_age<=self.stale_sec and len(fresh)>=4),
                    "row_count":len(rows),"fresh_rows":len(fresh),"rows":rows}

    def evidence(self,index):
        snap=self.snapshot(index)
        rows=snap["rows"]
        ce=sum(float(r.get("oi") or 0) for r in rows if r["side"]=="CE")
        pe=sum(float(r.get("oi") or 0) for r in rows if r["side"]=="PE")
        pcr=round(pe/ce,4) if ce else None
        ce_top=sorted((r for r in rows if r["side"]=="CE"),key=lambda r:float(r.get("oi") or 0),reverse=True)[:5]
        pe_top=sorted((r for r in rows if r["side"]=="PE"),key=lambda r:float(r.get("oi") or 0),reverse=True)[:5]
        return {"index":snap["index"],"spot":snap["spot"],"pcr":pcr,"source":snap["source"],
                "data_ok":snap["data_ok"],"stale":snap["stale"],"spot_age_s":snap["spot_age_s"],
                "fresh_rows":snap["fresh_rows"],
                "top_ce_oi":[{"strike":x["strike"],"oi":x.get("oi"),"age_s":x["age_s"],"stale":x["stale"]} for x in ce_top],
                "top_pe_oi":[{"strike":x["strike"],"oi":x.get("oi"),"age_s":x["age_s"],"stale":x["stale"]} for x in pe_top]}

STORE=MarketStore()
mcp=MCPServer("NSE Market Evidence",instructions="Read-only evidence from the shared market store. Never invent missing data. If data_ok is false, do not create a signal.")

@mcp.tool()
def get_evidence(index: str="NIFTY")->dict:
    """Compact PCR, freshness and top-OI evidence."""
    return STORE.evidence(index)

@mcp.tool()
def get_chain(index: str="NIFTY",limit: int=MAX_CHAIN_ROWS)->dict:
    """Bounded option-chain rows from the same snapshot the APK reads."""
    return STORE.snapshot(index,max(1,min(int(limit),MAX_CHAIN_ROWS)))

def mcp_http_app():
    return mcp.streamable_http_app(host="0.0.0.0",json_response=True,stateless_http=True)
