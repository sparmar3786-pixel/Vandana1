import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class PuterAiPage extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  final Map<String, dynamic>? initialSnapshot;
  const PuterAiPage({super.key, required this.backendUrl, required this.apiToken, this.initialSnapshot});
  @override State<PuterAiPage> createState() => _PuterAiPageState();
}

class _PuterAiPageState extends State<PuterAiPage> {
  late final WebViewController controller;
  Timer? snapshotTimer;
  bool ready = false;
  String bridgeStatus = 'Starting Puter AI bridge...';
  @override void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8F5FA))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() => bridgeStatus = 'Loading Puter.js...'); },
        onPageFinished: (_) async {
          ready = true;
          if (mounted) setState(() => bridgeStatus = 'Puter AI ready');
          await _pushSnapshot(widget.initialSnapshot);
          snapshotTimer?.cancel();
          snapshotTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshSnapshot());
        },
        onWebResourceError: (e) { if (mounted) setState(() => bridgeStatus = 'Puter network error: ' + e.description); },
      ))
      ..loadHtmlString(_html());
  }
  @override void dispose() { snapshotTimer?.cancel(); super.dispose(); }
  Future<void> _refreshSnapshot() async {
    try {
      final base = widget.backendUrl.replaceFirst(RegExp(r'/+$'), '');
      final r = await http.get(Uri.parse(base + '/v1/terminal'), headers: <String,String>{'x-token': widget.apiToken}).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) { final d = jsonDecode(r.body); if (d is Map<String,dynamic>) await _pushSnapshot(d); }
    } catch (_) {}
  }
  Future<void> _pushSnapshot(Map<String,dynamic>? snapshot) async {
    if (!ready || snapshot == null) return;
    final b64 = base64Encode(utf8.encode(jsonEncode(snapshot)));
    try { await controller.runJavaScript("window.updateMarketSnapshot('" + b64 + "');"); } catch (_) {}
  }
  String _html() => r'''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<script src="https://js.puter.com/v2/"></script>
<style>*{box-sizing:border-box}body{margin:0;background:#f8f5fa;color:#17131d;font-family:Arial,sans-serif}.wrap{padding:14px}.hero{background:#eee7ff;border:1px solid #d7c7ff;border-radius:18px;padding:16px}h1{font-size:23px;margin:0 0 5px}.sub{font-size:13px;color:#665f70}.row{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}button{border:0;border-radius:24px;padding:12px 17px;font-weight:700;font-size:14px;background:#6946b9;color:#fff}button.secondary{background:#e4dff0;color:#322c3a}.status{margin:12px 0;font-size:13px}.ok{color:#198754}.warn{color:#d98200}.err{color:#c0392b}.card{background:#fff;border-radius:16px;margin:10px 0;padding:14px;box-shadow:0 2px 7px #00000018}.head{display:flex;justify-content:space-between;gap:8px}.name{font-size:17px;font-weight:800}.badge{font-size:11px;padding:5px 9px;border-radius:15px;background:#eee}pre{white-space:pre-wrap;font:13px/1.45 Arial;margin:10px 0}.meta{font-size:11px;color:#777;margin-top:5px}.small{font-size:12px;color:#625b6a}.live{color:#16834d;font-weight:700}</style>
</head><body><div class="wrap"><div class="hero"><h1>6-AI • LIVE WORKING MODE</h1><div class="sub">Puter.js • Angel/NSE snapshot • official NSE • Internet evidence</div><div class="row"><button id="run">RUN 6-AI VALIDATION</button><button class="secondary" id="auth">PUTER SIGN IN</button><button class="secondary" id="auto">AUTO: ON</button></div><div id="status" class="status warn">Preparing...</div><div class="small">API keys are not stored in the APK. Puter user authentication handles AI access.</div></div><div id="cards"></div></div>
<script>
const AI=[
{label:'GPT-5.6 Luna',candidates:['openai/gpt-5.6-luna','gpt-5.6-luna'],match:['gpt-5.6-luna'],openai:true},
{label:'Claude Sonnet 4.6',candidates:['claude-sonnet-4-6','anthropic/claude-sonnet-4-6'],match:['claude-sonnet-4-6','sonnet-4.6'],openai:false},
{label:'GPT-5.6 Sol',candidates:['openai/gpt-5.6-sol','gpt-5.6-sol'],match:['gpt-5.6-sol'],openai:true},
{label:'DeepSeek Chat',candidates:['deepseek-chat','deepseek/deepseek-chat'],match:['deepseek-chat'],openai:false},
{label:'Gemini 2.5 Flash',candidates:['gemini-2.5-flash','google/gemini-2.5-flash'],match:['gemini-2.5-flash'],openai:false},
{label:'Grok 4',candidates:['grok-4','xai/grok-4'],match:['grok-4'],openai:false}];
let snapshot={};let running=false;let auto=true;let autoTimer=null;let modelCatalog=[];
function esc(s){return String(s??'').replace(/[&<>\"]/g,function(m){return {'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[m]})}
function b64json(b){try{return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b),function(c){return c.charCodeAt(0)})))}catch(e){return {}}}
window.updateMarketSnapshot=function(b64){snapshot=b64json(b64);document.getElementById('status').innerHTML='<span class="live">● LIVE</span> Market snapshot updated from Railway/Angel/NSE';};
function renderCards(){document.getElementById('cards').innerHTML=AI.map(function(a,i){return '<div class="card" id="c'+i+'"><div class="head"><div class="name">'+(i+1)+' • '+esc(a.label)+'</div><div class="badge" id="b'+i+'">READY</div></div><div class="meta" id="m'+i+'">'+esc(a.candidates[0])+'</div><pre id="r'+i+'">Waiting for validation...</pre></div>'}).join('')}
renderCards();
async function ensureAuth(){if(puter.auth.isSignedIn())return true;try{if(puter.ui&&puter.ui.authenticateWithPuter){await puter.ui.authenticateWithPuter()}else{await puter.auth.signIn({attempt_temp_user_creation:true})}return puter.auth.isSignedIn()}catch(e){throw new Error('Puter sign-in required: '+(e?.msg||e?.message||e))}}
async function loadModels(){try{modelCatalog=await puter.ai.listModels()}catch(e){modelCatalog=[]}}
function resolveModel(a){const ids=(modelCatalog||[]).map(function(x){return String(x.id||'')});for(const c of a.candidates){const exact=ids.find(function(x){return x===c});if(exact)return exact}for(const term of a.match){const hit=ids.find(function(x){return x.toLowerCase().includes(term.toLowerCase())});if(hit)return hit}return a.candidates[0]}
async function internetEvidence(){const out={};try{const n=await puter.net.fetch('https://www.nseindia.com/option-chain',{headers:{'User-Agent':'Mozilla/5.0','Accept':'text/html'}});const t=await n.text();out.nse=t.replace(/<script[\s\S]*?<\/script>/gi,' ').replace(/<style[\s\S]*?<\/style>/gi,' ').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').slice(0,9000)}catch(e){out.nse='Official NSE page fetch unavailable in this run.'}try{const n=await puter.net.fetch('https://news.google.com/rss/search?q=NIFTY%20BANKNIFTY%20India%20stock%20market&hl=en-IN&gl=IN&ceid=IN:en');const t=await n.text();out.news=t.replace(/<item>/g,'\n').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').slice(0,6000)}catch(e){out.news='Current news feed unavailable in this run.'}return out}
function promptFor(a,web){return 'You are '+a.label+', an independent market-analysis engine for an Indian paper-trading terminal.\nUse ONLY the supplied Angel/NSE market snapshot plus the supplied Internet evidence. Do not invent prices, OI, news, or API results.\nEvaluate NIFTY/Indian index option context. Return concise JSON with keys: state (CALL BUY, PUT BUY, WAIT, or NO QUALIFYING TRADE), confidence (0-100), summary, positives, negatives, risks, watch.\nA trade is valid only when the supplied evidence actually supports it; otherwise WAIT/NO QUALIFYING TRADE.\nNo order placement, no profit guarantee, no fabricated win rate.\nMARKET SNAPSHOT:\n'+JSON.stringify(snapshot).slice(0,24000)+'\nOFFICIAL NSE / INTERNET EVIDENCE:\n'+JSON.stringify(web).slice(0,15000)}
async function one(a,i,web){const badge=document.getElementById('b'+i),out=document.getElementById('r'+i),meta=document.getElementById('m'+i);badge.textContent='RUNNING';badge.style.background='#fff0cf';out.textContent='Analyzing live snapshot + Internet...';try{const model=resolveModel(a);meta.textContent=model;const opts={model:model,temperature:0.15,max_tokens:700};if(a.openai)opts.tools=[{type:'web_search'}];const res=await puter.ai.chat(promptFor(a,web),opts);const text=typeof res==='string'?res:(res?.message?.content??res?.text??JSON.stringify(res));badge.textContent='CONNECTED';badge.style.background='#dff5e8';out.textContent=text;return {ok:true,text:text}}catch(e){badge.textContent='ERROR';badge.style.background='#ffe0e0';out.textContent=String(e?.message||e);return {ok:false,error:String(e?.message||e)}}}
async function runSix(){if(running)return;running=true;document.getElementById('run').disabled=true;document.getElementById('status').innerHTML='<span class="live">● RUNNING</span> 6 independent AI analyses...';try{await ensureAuth();await loadModels();const web=await internetEvidence();const results=await Promise.all(AI.map(function(a,i){return one(a,i,web)}));const ok=results.filter(function(x){return x.ok}).length;document.getElementById('status').innerHTML='<span class="live">● LIVE</span> '+ok+'/6 AI responses completed • NSE + Internet evidence included • '+new Date().toLocaleTimeString()}catch(e){document.getElementById('status').innerHTML='<span class="err">'+esc(e?.message||e)+'</span>'}finally{running=false;document.getElementById('run').disabled=false}}
document.getElementById('run').onclick=runSix;document.getElementById('auth').onclick=async function(){try{await ensureAuth();document.getElementById('status').innerHTML='<span class="live">● Puter authenticated</span>'}catch(e){document.getElementById('status').textContent=e.message||e}};
document.getElementById('auto').onclick=function(){auto=!auto;document.getElementById('auto').textContent='AUTO: '+(auto?'ON':'OFF');if(auto){runSix();autoTimer=setInterval(runSix,60000)}else{clearInterval(autoTimer);autoTimer=null}};
window.addEventListener('load',function(){setTimeout(function(){runSix()},1200);autoTimer=setInterval(runSix,60000)});
</script></body></html>