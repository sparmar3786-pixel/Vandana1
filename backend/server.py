"""Network/API gateway for NSE Algo Signal. PAPER signals only; no order placement."""
import threading,time,datetime as dt
from typing import Optional
from fastapi import FastAPI,Header,HTTPException,Response
from pydantic import BaseModel
import uvicorn
import config as C
from angel_client import AngelClient
from signals import Engine
from nse_client import NSEClient
import nse_features
from nse_mcp import NSEMCP,result_to_csv

app=FastAPI(title="NSE Algo Signal API"); eng=Engine(); client=AngelClient(); nse=NSEClient(); nse_mcp=NSEMCP()
state={"error":None,"nse_error":None,"last_update":None,"angel_message":"Not connected","nse_mcp_error":None}; prev_chain={"c":None}

class AngelLoginRequest(BaseModel):
    clientId:str
    pin:str
    totp:str
    apiKey:Optional[str]=None

def market_open():
    now=dt.datetime.now(dt.timezone(dt.timedelta(hours=5,minutes=30)))
    return now.weekday()<5 and dt.time(9,15)<=now.time()<=dt.time(15,30)

def _ensure_angel():
    if client.api is None:
        client.login(); state["angel_message"]="Connected using server credentials."

def loop():
    while True:
        try:
            _ensure_angel()
            if market_open():
                eng.update(client.snapshot()); state["last_update"]=time.time(); state["error"]=None
        except Exception as e:
            state["error"]=str(e); state["angel_message"]="Angel connection failed."; client.api=None; time.sleep(10)
        time.sleep(C.POLL_SEC)

def nse_loop():
    while True:
        try:
            if market_open():
                ch=nse.fetch(C.SYMBOL); features=nse_features.compute(ch,prev_chain["c"]); prev_chain["c"]=ch
                eng.set_nse(features,ch["ts"]); state["nse_error"]=None
        except Exception as e: state["nse_error"]=str(e)
        time.sleep(C.NSE_POLL_SEC)

def auth(x_token:str):
    if x_token!=C.API_TOKEN: raise HTTPException(401,"bad token")

@app.get("/health")
def health():
    return {"ok":True,"market_open":market_open(),"angel_connected":client.api is not None,"angel_message":state["angel_message"],"nse_mcp":"configured","last_update":state["last_update"],"error":state["error"],"nse_error":state["nse_error"],"nse_mcp_error":state["nse_mcp_error"]}

@app.post("/v1/angel/login")
def angel_login(body:AngelLoginRequest,x_token:str=Header(None)):
    auth(x_token)
    if len(body.totp)!=6 or not body.totp.isdigit(): raise HTTPException(400,"TOTP must be the current 6-digit code.")
    try:
        result=client.login(api_key=body.apiKey or C.API_KEY,client_code=body.clientId,pin=body.pin,totp=body.totp)
        state["angel_message"]="Angel One connected."; state["error"]=None
        return {"ok":True,"connected":True,"message":"Angel One connected.","profile":result.get("data",{}).get("clientcode")}
    except Exception:
        client.api=None; state["angel_message"]="Angel connection failed."; state["error"]="Angel login failed"
        raise HTTPException(401,"Angel login failed. Check Client ID, PIN, TOTP and API key.")

@app.get("/v1/angel/status")
def angel_status(x_token:str=Header(None)):
    auth(x_token); return {"connected":client.api is not None,"message":state["angel_message"],"last_update":state["last_update"],"error":state["error"]}

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

@app.get("/signal")
def signal(x_token:str=Header(None)): auth(x_token); return terminal_snapshot()

@app.get("/v1/terminal")
def terminal_snapshot_endpoint(x_token:str=Header(None)): auth(x_token); return terminal_snapshot()

def terminal_snapshot():
    last=eng.last if isinstance(eng.last,dict) else {}; nse_view=eng.nse_view if isinstance(eng.nse_view,dict) else {}
    return {"ts":time.time(),"market_open":market_open(),"connection":{"angel":client.api is not None,"nse":state["nse_error"] is None,"server":True,"last_update":state["last_update"],"error":state["error"],"nse_error":state["nse_error"],"angel_message":state["angel_message"]},"market":{"symbol":C.SYMBOL,"spot":last.get("spot"),"atm":last.get("strike"),"action":last.get("action","WAIT"),"ltp":last.get("ltp")},"signals":last,"oi_lab":nse_view,"option_chain":last.get("chain",last.get("opts")),"charts":{"spot":last.get("spot"),"ltp":last.get("ltp"),"timestamp":state["last_update"]},"nse":nse_view,"nse_mcp":{"status":"official NSE Streamable HTTP MCP","endpoint":nse_mcp.url,"connected":state["nse_mcp_error"] is None,"error":state["nse_mcp_error"],"csv_endpoint":"/v1/nse/option-chain.csv"},"angel_api":{"connected":client.api is not None,"message":state["angel_message"]},"data":last,"instruments":{"source":"Angel One SmartAPI instrument master","loaded":bool(client.chain),"expiry":str(client.expiry) if client.expiry else None,"strike_count":len(client.strikes)},"watchlist":{"source":"Angel One SmartAPI","items":[]},"search":{"source":"Angel One SmartAPI","items":[]},"commodity":{"source":"Angel One SmartAPI","items":[]},"market_details":nse_view,"news":{"source":"server-side news adapter","items":[]},"settings":{"symbol":C.SYMBOL,"poll_sec":C.POLL_SEC,"nse_poll_sec":C.NSE_POLL_SEC},"more":{"paper_only":True,"orders_enabled":False},"error":state["error"],"nse_error":state["nse_error"]}

if __name__=="__main__":
    threading.Thread(target=loop,daemon=True).start(); threading.Thread(target=nse_loop,daemon=True).start()
    uvicorn.run(app,host="0.0.0.0",port=8000)
