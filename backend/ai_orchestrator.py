"""Server-side multi-provider AI validation for the trading terminal.
API keys stay on the backend; the APK never receives provider secrets.
"""
from __future__ import annotations
import concurrent.futures
import os
import requests

TIMEOUT = int(os.getenv("AI_TIMEOUT_SEC", "25"))

PROVIDERS = [
    {"id":"gpt56-luna","name":"GPT-5.6 Luna","env":"OPENAI_API_KEY","kind":"openai","model":os.getenv("OPENAI_LUNA_MODEL","gpt-5.6-luna")},
    {"id":"claude-sonnet","name":"Claude Sonnet 4.6","env":"ANTHROPIC_API_KEY","kind":"anthropic","model":os.getenv("ANTHROPIC_MODEL","claude-sonnet-4-6")},
    {"id":"gpt56-sol","name":"GPT-5.6 Sol","env":"OPENAI_API_KEY","kind":"openai","model":os.getenv("OPENAI_SOL_MODEL","gpt-5.6-sol")},
    {"id":"deepseek","name":"DeepSeek Chat","env":"DEEPSEEK_API_KEY","kind":"openai_compat","model":os.getenv("DEEPSEEK_MODEL","deepseek-chat"),"base":"https://api.deepseek.com/v1/chat/completions"},
    {"id":"gemini-flash","name":"Gemini 2.5 Flash","env":"GEMINI_API_KEY","kind":"gemini","model":os.getenv("GEMINI_MODEL","gemini-2.5-flash")},
    {"id":"grok-4","name":"Grok 4","env":"XAI_API_KEY","kind":"openai_compat","model":os.getenv("XAI_MODEL","grok-4"),"base":"https://api.x.ai/v1/chat/completions"},
]

ROLE_PROMPTS = {
    "gpt56-luna":"live data collection and candidate extraction",
    "claude-sonnet":"verification, contradiction and evidence audit",
    "gpt56-sol":"independent final validation of the supplied numbers",
    "deepseek":"quantitative/OI/Greeks mathematical cross-check",
    "gemini-flash":"market structure and chart-context cross-check",
    "grok-4":"risk audit, failure conditions and WAIT override",
}

SYSTEM = """You are a market-data validation component inside an Indian index options terminal.
Use ONLY the supplied market payload. Do not invent news, prices, OI, Greeks or trades.
Do not claim hidden institutional orders. Do not promise returns or a win rate.
The engine's final decision remains CALL BUY / PUT BUY / WAIT / NO QUALIFYING TRADE.
Return concise evidence, contradictions, missing-data warnings and a recommendation state."""

def _prompt(provider, payload):
    role = ROLE_PROMPTS[provider["id"]]
    return (SYSTEM + "\nYour role: " + role + ".\n"
            + "Return exactly these headings: STATE, EVIDENCE, RISKS, MISSING_DATA, OVERRIDE.\n"
            + "STATE must be CALL BUY, PUT BUY, WAIT, or NO QUALIFYING TRADE.\n"
            + "Payload:\n" + _compact(payload))

def _compact(payload):
    import json
    return json.dumps(payload, ensure_ascii=False, separators=(",",":"), default=str)[:30000]

def _openai(p, text):
    r=requests.post("https://api.openai.com/v1/responses",
        headers={"Authorization":"Bearer "+os.environ[p["env"]],"Content-Type":"application/json"},
        json={"model":p["model"],"input":[{"role":"system","content":SYSTEM},{"role":"user","content":text}],"max_output_tokens":700},
        timeout=TIMEOUT)
    r.raise_for_status(); d=r.json()
    if d.get("output_text"): return d["output_text"]
    out=[]
    for item in d.get("output",[]):
        for c in item.get("content",[]) if isinstance(item,dict) else []:
            if isinstance(c,dict) and c.get("text"): out.append(c["text"])
    return "\n".join(out).strip()

def _openai_compat(p, text):
    r=requests.post(p["base"],
        headers={"Authorization":"Bearer "+os.environ[p["env"]],"Content-Type":"application/json"},
        json={"model":p["model"],"messages":[{"role":"system","content":SYSTEM},{"role":"user","content":text}],"temperature":0.1,"max_tokens":700},
        timeout=TIMEOUT)
    r.raise_for_status(); return (((r.json().get("choices") or [{}])[0].get("message") or {}).get("content") or "").strip()

def _anthropic(p, text):
    r=requests.post("https://api.anthropic.com/v1/messages",
        headers={"x-api-key":os.environ[p["env"]],"anthropic-version":"2023-06-01","content-type":"application/json"},
        json={"model":p["model"],"max_tokens":700,"system":SYSTEM,"messages":[{"role":"user","content":text}]},
        timeout=TIMEOUT)
    r.raise_for_status()
    return "\n".join(x.get("text","") for x in r.json().get("content",[]) if isinstance(x,dict)).strip()

def _gemini(p, text):
    key=os.environ[p["env"]]
    url=f"https://generativelanguage.googleapis.com/v1beta/models/{p['model']}:generateContent?key={key}"
    r=requests.post(url,headers={"Content-Type":"application/json"},
        json={"systemInstruction":{"parts":[{"text":SYSTEM}]},"contents":[{"parts":[{"text":text}]}],"generationConfig":{"temperature":0.1,"maxOutputTokens":700}},
        timeout=TIMEOUT)
    r.raise_for_status(); d=r.json()
    return "\n".join(x.get("text","") for x in (((d.get("candidates") or [{}])[0].get("content") or {}).get("parts") or []) if isinstance(x,dict)).strip()

def _run_one(p, payload):
    if not os.getenv(p["env"]):
        return {"id":p["id"],"name":p["name"],"model":p["model"],"status":"not_configured","text":"","error":"Provider API key is not configured on the server."}
    try:
        text=_prompt(p,payload)
        if p["kind"]=="openai": answer=_openai(p,text)
        elif p["kind"]=="anthropic": answer=_anthropic(p,text)
        elif p["kind"]=="gemini": answer=_gemini(p,text)
        else: answer=_openai_compat(p,text)
        return {"id":p["id"],"name":p["name"],"model":p["model"],"status":"ok","text":answer}
    except Exception as e:
        return {"id":p["id"],"name":p["name"],"model":p["model"],"status":"error","text":"","error":str(e)[:300]}

def provider_status():
    return [{"id":p["id"],"name":p["name"],"model":p["model"],"configured":bool(os.getenv(p["env"]))} for p in PROVIDERS]

def validate_all(payload):
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(PROVIDERS)) as ex:
        results=list(ex.map(lambda p:_run_one(p,payload),PROVIDERS))
    ok=[r for r in results if r["status"]=="ok"]
    states=[r["text"].split("\n",1)[0].replace("STATE:","").strip().upper() for r in ok]
    non_wait=[s for s in states if s in {"CALL BUY","PUT BUY"}]
    final = non_wait[0] if len(non_wait)==1 and all(s==non_wait[0] for s in non_wait) else "WAIT"
    if not ok: final="NO QUALIFYING TRADE"
    return {"final":final,"providers":results,"configured":sum(1 for r in results if r["status"]=="ok"),"total":len(results)}
