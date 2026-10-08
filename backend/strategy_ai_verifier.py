"""Six-layer OpenAI strategy verifier. One OpenAI Access Key, six analytical lenses."""
from __future__ import annotations
import concurrent.futures, json, os, time
from ai_orchestrator import PROVIDERS, _openai

SYSTEM="""You are an evidence auditor inside a paper-trading strategy engine.
Never invent market data. Never create or modify a trade candidate.
You may only PASS or FAIL the supplied candidate and flag risks.
Return ONLY JSON: {"verdict":"PASS|FAIL","overfit_risk":"LOW|MEDIUM|HIGH","weak_points":[],"fix":[],"opposite_side_block":false}"""

def _evidence(payload):
    return {k:payload.get(k) for k in ("engine_decision","candidate","data_quality","train_metrics","test_metrics","strategy_id","strategy_version")}

def _call(layer,payload):
    base={"id":layer["id"],"name":layer["name"],"model":layer["model"],"lens":layer["role"]}
    if not os.getenv("OPENAI_API_KEY") and not __import__("ai_orchestrator")._key():
        return {**base,"status":"not_configured","verdict":"FAIL","overfit_risk":"HIGH"}
    prompt=SYSTEM+"\nLayer: "+layer["name"]+"\nRole: "+layer["role"]+"\nEvidence:\n"+json.dumps(_evidence(payload),ensure_ascii=False,separators=(",",":"),default=str)[:18000]
    started=time.monotonic()
    try:
        raw=_openai(layer,prompt)
        data=json.loads(raw.strip())
        verdict=str(data.get("verdict","FAIL")).upper()
        risk=str(data.get("overfit_risk","HIGH")).upper()
        return {**base,"status":"ok","verdict":verdict if verdict in {"PASS","FAIL"} else "FAIL",
                "overfit_risk":risk if risk in {"LOW","MEDIUM","HIGH"} else "HIGH",
                "weak_points":list(data.get("weak_points",[]))[:5],"fix":list(data.get("fix",[]))[:5],
                "opposite_side_block":bool(data.get("opposite_side_block",False)),
                "elapsed_ms":round((time.monotonic()-started)*1000)}
    except Exception as e:
        return {**base,"status":"error","verdict":"FAIL","overfit_risk":"HIGH","error":str(e)[:300]}

def verify_engine_result(payload):
    engine=str(payload.get("engine_decision","WAIT")).upper()
    if engine not in {"CALL BUY","PUT BUY","WAIT","NO QUALIFYING TRADE"}: engine="WAIT"
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(PROVIDERS)) as ex:
        results=list(ex.map(lambda layer:_call(layer,payload),PROVIDERS))
    ok=[r for r in results if r.get("status")=="ok"]
    passes=sum(r.get("verdict")=="PASS" for r in ok)
    blocked=any(r.get("opposite_side_block") for r in ok)
    high=any(r.get("overfit_risk")=="HIGH" for r in ok)
    consensus=len(ok)==6 and passes==6 and not blocked and not high
    final=engine if engine in {"WAIT","NO QUALIFYING TRADE"} or consensus else "WAIT"
    return {"engine_decision":engine,"final":final,"ai_can_only_downgrade":True,
            "consensus":consensus,"passes":passes,"successful":len(ok),"total":6,
            "opposite_side_block":blocked,"high_overfit_risk":high,"providers":results,
            "mode":"openai_6_layer"}
