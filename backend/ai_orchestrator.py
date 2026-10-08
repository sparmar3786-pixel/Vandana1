"""Six-layer OpenAI AI engine for the NSE options terminal.

All six analytical layers use the SAME OpenAI Access Key. No other AI provider,
local ML model, Puter model, or offline AI fallback is used.

The key may be supplied as OPENAI_API_KEY on the server or at runtime from the
app's OpenAI Access Key setting. Runtime keys are kept in process memory only.
"""
from __future__ import annotations
import concurrent.futures
import hashlib
import json
import os
import re
import threading
import time
import requests

TIMEOUT = int(os.getenv("AI_TIMEOUT_SEC", "30"))
AI_CACHE_SEC = int(os.getenv("AI_CACHE_SEC", "30"))
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5.6-luna")
OPENAI_URL = "https://api.openai.com/v1/responses"
NSE_SITE_URL = os.getenv("NSE_SITE_URL", "https://www.nseindia.com/option-chain")

_runtime_key = ""
_runtime_lock = threading.Lock()
_ai_cache = {}
_ai_cache_lock = threading.Lock()

LAYERS = [
    {"id":"layer-1","name":"Layer 1 • Data Collection","role":"collect and normalize only supplied Angel One, NSE MCP and official NSE evidence"},
    {"id":"layer-2","name":"Layer 2 • Market Structure","role":"analyze trend, price structure, support, resistance, PCR and option-chain context"},
    {"id":"layer-3","name":"Layer 3 • OI + Greeks","role":"cross-check OI buildup/unwinding, volume, IV and Greeks consistency"},
    {"id":"layer-4","name":"Layer 4 • Strategy Validation","role":"check the deterministic strategy candidate against supplied rules and evidence"},
    {"id":"layer-5","name":"Layer 5 • Risk + Contradiction","role":"find missing data, contradictions, liquidity/risk issues and downgrade conditions"},
    {"id":"layer-6","name":"Layer 6 • Final Risk Audit","role":"make the final AI-only recommendation; WAIT on uncertainty or conflicting evidence"},
]

# Compatibility alias: callers that previously iterated PROVIDERS now receive
# six layers, but every layer is OpenAI.
PROVIDERS = [
    {"id":x["id"],"name":x["name"],"role":x["role"],"env":"OPENAI_API_KEY","kind":"openai","model":OPENAI_MODEL}
    for x in LAYERS
]
ROLE_PROMPTS = {x["id"]:x["role"] for x in LAYERS}

SYSTEM = """You are one layer of a six-layer AI decision system inside an Indian index-options analysis terminal.
Use ONLY the supplied payload. Never invent prices, OI, Greeks, news, trades or guarantees.
The deterministic engine owns market data and trade levels. AI may only validate or downgrade.
Allowed final states: CALL BUY, PUT BUY, WAIT, NO QUALIFYING TRADE.
Missing or conflicting evidence must produce WAIT.
Paper/analysis only; never place an order.
Return concise evidence and risks."""

def _key() -> str:
    with _runtime_lock:
        runtime = _runtime_key
    return runtime or os.getenv("OPENAI_API_KEY", "").strip()

def configure_provider(provider_id: str, access_key: str):
    global _runtime_key
    if provider_id not in {x["id"] for x in LAYERS} and provider_id not in {"openai","openai-6-layer"}:
        raise ValueError("Only OpenAI 6-Layer AI is supported.")
    key = (access_key or "").strip()
    if len(key) < 8:
        raise ValueError("OpenAI Access Key is too short.")
    with _runtime_lock:
        _runtime_key = key
    with _ai_cache_lock:
        _ai_cache.clear()
    return {"ok":True,"provider":"openai-6-layer","layers":len(LAYERS),"runtime_key":True}

def clear_provider(provider_id: str = "openai-6-layer"):
    global _runtime_key
    with _runtime_lock:
        _runtime_key = ""
    with _ai_cache_lock:
        _ai_cache.clear()
    return {"ok":True,"provider":"openai-6-layer","cleared":True}

def provider_status():
    configured = bool(_key())
    return [{
        "id":x["id"], "name":x["name"], "model":OPENAI_MODEL,
        "role":x["role"], "configured":configured,
        "provider":"OpenAI", "shared_access_key":True
    } for x in LAYERS]

def _compact(payload):
    return json.dumps(payload, ensure_ascii=False, separators=(",",":"), default=str)[:30000]

def _nse_site_evidence(payload):
    symbol="NIFTY"
    if isinstance(payload,dict):
        terminal=payload.get("terminal") or {}
        market=terminal.get("market") if isinstance(terminal,dict) else {}
        symbol=str((market or {}).get("symbol") or payload.get("symbol") or "NIFTY").upper()
    try:
        r=requests.get(NSE_SITE_URL,headers={"User-Agent":"Mozilla/5.0","Accept":"text/html,application/xhtml+xml"},timeout=8)
        r.raise_for_status()
        html=r.text
        m=re.search(r"Underlying Index[^<]{0,120}?(NIFTY[^<]{0,80})",html,re.I)
        asof=re.search(r"As on[^<]{0,120}",html,re.I)
        return {"connected":True,"url":NSE_SITE_URL,"symbol":symbol,"http_status":r.status_code,
                "page_timestamp":asof.group(0).strip() if asof else "",
                "page_hint":m.group(1).strip() if m else ""}
    except Exception as e:
        return {"connected":False,"url":NSE_SITE_URL,"symbol":symbol,"error":str(e)[:200]}

def _prompt(layer, payload, previous=None):
    prior = ""
    if previous:
        prior = "\nPrevious layer evidence (do not blindly trust it):\n" + json.dumps(previous, ensure_ascii=False, separators=(",",":"), default=str)[:9000]
    return (SYSTEM + "\nYour layer: " + layer["name"] + "\nYour role: " + layer["role"] +
            "\nReturn exactly:\nSTATE: CALL BUY|PUT BUY|WAIT|NO QUALIFYING TRADE\n"
            "EVIDENCE: concise evidence\nRISKS: concise risks\nMISSING_DATA: missing/conflicting fields\nOVERRIDE: WAIT or NONE\n"
            + prior + "\nPayload:\n" + _compact(payload))

def _openai(p, text):
    key = _key()
    if not key:
        raise RuntimeError("OpenAI Access Key is not configured.")
    r=requests.post(OPENAI_URL,
        headers={"Authorization":"Bearer "+key,"Content-Type":"application/json"},
        json={"model":OPENAI_MODEL,
              "input":[{"role":"system","content":SYSTEM},{"role":"user","content":text}],
              "max_output_tokens":700},
        timeout=TIMEOUT)
    r.raise_for_status()
    d=r.json()
    if d.get("output_text"):
        return d["output_text"].strip()
    out=[]
    for item in d.get("output",[]):
        for c in item.get("content",[]) if isinstance(item,dict) else []:
            if isinstance(c,dict) and c.get("text"): out.append(c["text"])
    return "\n".join(out).strip()

# Compatibility wrappers for older modules. They all route to OpenAI only.
def _openai_compat(p, text): return _openai(p, text)
def _anthropic(p, text): return _openai(p, text)
def _gemini(p, text): return _openai(p, text)

def _state(text):
    m=re.search(r"(?im)^\s*STATE\s*:\s*(CALL BUY|PUT BUY|WAIT|NO QUALIFYING TRADE)\b", text or "")
    return m.group(1).upper() if m else ""

def _run_layer(layer, payload, previous=None):
    started=time.monotonic()
    base={"id":layer["id"],"name":layer["name"],"model":OPENAI_MODEL,"role":layer["role"],"provider":"OpenAI"}
    if not _key():
        return {**base,"status":"not_configured","state":"WAIT","text":"","error":"OpenAI Access Key is not configured.","elapsed_ms":0}
    try:
        answer=_openai(layer,_prompt(layer,payload,previous))
        return {**base,"status":"ok","state":_state(answer),"text":answer,
                "elapsed_ms":round((time.monotonic()-started)*1000)}
    except Exception as e:
        return {**base,"status":"error","state":"WAIT","text":"","error":str(e)[:300],
                "elapsed_ms":round((time.monotonic()-started)*1000)}

def validate_all(payload):
    payload=dict(payload or {})
    payload["nse_official_site"]=_nse_site_evidence(payload)
    if not _key():
        return {"final":"WAIT","providers":[], "layers":[], "configured":0,
                "successful":0,"parsed_states":0,"total":6,"cross_verified":False,
                "reason":"OpenAI Access Key is not configured. Connect it in AI Settings.",
                "mode":"openai_6_layer","cached":False}
    raw=json.dumps(payload,ensure_ascii=False,sort_keys=True,separators=(",",":"),default=str)
    cache_key=hashlib.sha256(raw.encode()).hexdigest()
    now=time.monotonic()
    with _ai_cache_lock:
        cached=_ai_cache.get(cache_key)
        if cached and now-cached["ts"] < AI_CACHE_SEC:
            return {**cached["result"],"cached":True,"cache_age_sec":round(now-cached["ts"],1)}
    results=[]
    previous=[]
    # Sequential layers make later risk/strategy layers aware of earlier evidence.
    for layer in LAYERS:
        result=_run_layer(layer,payload,previous[-2:] if previous else None)
        results.append(result)
        if result.get("status")=="ok":
            previous.append({"layer":layer["name"],"state":result.get("state"),"text":result.get("text","")[:5000]})
    ok=[r for r in results if r.get("status")=="ok"]
    states=[r.get("state") for r in ok if r.get("state")]
    final="WAIT"
    reason="Six-layer OpenAI validation did not produce a complete agreement; WAIT is the safe result."
    if len(ok)==6 and len(states)==6 and len(set(states))==1:
        final=states[-1]
        reason="All six OpenAI layers returned the same state."
    elif states and states[-1] == "WAIT":
        final="WAIT"
        reason="Final risk-audit layer returned WAIT."
    elif states and states.count(states[-1]) >= 5:
        final=states[-1]
        reason="Five or more OpenAI layers agree and the final layer confirms the state."
    result={"final":final,"providers":results,"layers":results,"configured":6 if _key() else 0,
            "successful":len(ok),"parsed_states":len(states),"total":6,
            "cross_verified":len(ok)==6 and len(states)==6 and len(set(states))==1,
            "reason":reason,"mode":"openai_6_layer","cached":False,
            "sources":{"ai_api":"OpenAI Responses API","nse_official_site":payload.get("nse_official_site"),
                       "nse_mcp":"server-side NSE MCP"}}
    with _ai_cache_lock:
        _ai_cache[cache_key]={"ts":time.monotonic(),"result":result}
    return result

def _local_fallback(payload):
    # Kept only as a compatibility symbol for old callers; it is NEVER used.
    return {"status":"disabled","final":"WAIT","text":"Legacy local AI fallback disabled. Use OpenAI 6-Layer AI."}

def _state_from_text(text):
    return _state(text)
