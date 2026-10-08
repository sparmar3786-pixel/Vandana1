import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Six logical AI layers, all powered by the same OpenAI Access Key.
/// The key is sent to the backend over HTTPS and is never persisted in the APK.
class AiValidatePage extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  final String symbol;
  const AiValidatePage({super.key, required this.backendUrl, required this.apiToken, this.symbol='NIFTY'});
  @override State<AiValidatePage> createState()=>_AiValidatePageState();
}

class _AiValidatePageState extends State<AiValidatePage> {
  bool running=false, savingKey=false;
  String status='Connect your OpenAI Access Key, then run the 6-layer analysis.';
  final TextEditingController key=TextEditingController();
  Map<String,dynamic> result=<String,dynamic>{};
  List<dynamic> layers=<dynamic>[];
  Timer? timer;

  String get base=>widget.backendUrl.trim().replaceFirst(RegExp(r'/+$'),'');
  Map<String,String> get headers=>{'Content-Type':'application/json',if(widget.apiToken.trim().isNotEmpty)'x-token':widget.apiToken.trim()};
  Map<String,dynamic> m(dynamic x)=>x is Map?Map<String,dynamic>.from(x):<String,dynamic>{};
  List<dynamic> l(dynamic x)=>x is List?x:<dynamic>[];

  String err(http.Response r){
    try{final d=jsonDecode(r.body);if(d is Map){final x=d['detail']??d['message'];if(x!=null)return x is Map?(x['message']??x['code']??'HTTP ${r.statusCode}').toString():x.toString();}}catch(_){}
    return 'HTTP ${r.statusCode}';
  }

  Future<void> loadStatus() async {
    if(base.isEmpty)return;
    try{
      final r=await http.get(Uri.parse('$base/v1/ai/providers'),headers:headers).timeout(const Duration(seconds:15));
      if(r.statusCode!=200)throw Exception(err(r));
      final d=m(jsonDecode(r.body)); final ps=l(d['providers']);
      final configured=ps.any((x)=>m(x)['configured']==true);
      if(mounted)setState(()=>status=configured?'OpenAI 6-Layer AI is CONNECTED.':'OpenAI Access Key not connected.');
    }catch(e){if(mounted)setState(()=>status='AI status error: ${e.toString().replaceFirst('Exception: ','')}');}
  }

  Future<void> connectKey() async {
    final value=key.text.trim();
    if(value.length<8){setState(()=>status='Enter a valid OpenAI Access Key.');return;}
    setState(()=>savingKey=true);
    try{
      final r=await http.post(Uri.parse('$base/v1/ai/access-key'),headers:headers,
        body:jsonEncode({'providerId':'openai-6-layer','accessKey':value})).timeout(const Duration(seconds:20));
      if(r.statusCode!=200)throw Exception(err(r));
      key.clear();
      if(mounted)setState(()=>status='OpenAI Access Key connected • six layers ready • key kept in backend memory.');
    }catch(e){if(mounted)setState(()=>status='OpenAI connection error: ${e.toString().replaceFirst('Exception: ','')}');}
    finally{if(mounted)setState(()=>savingKey=false);}
  }

  Future<void> clearKey() async {
    try{
      final r=await http.delete(Uri.parse('$base/v1/ai/access-key/openai-6-layer'),headers:headers).timeout(const Duration(seconds:15));
      if(r.statusCode!=200)throw Exception(err(r));
      if(mounted)setState(()=>status='OpenAI Access Key cleared from backend memory.');
    }catch(e){if(mounted)setState(()=>status='Clear error: ${e.toString().replaceFirst('Exception: ','')}');}
  }

  Future<void> run() async {
    if(running)return;
    setState(()=>running=true);
    try{
      final c=await http.get(Uri.parse('$base/v1/ai/context?index=${Uri.encodeQueryComponent(widget.symbol.toUpperCase())}'),headers:headers).timeout(const Duration(seconds:40));
      if(c.statusCode!=200)throw Exception(err(c));
      setState(()=>status='Running OpenAI 6-Layer analysis...');
      final r=await http.post(Uri.parse('$base/v1/ai/validate'),headers:headers,
        body:jsonEncode({'payload':jsonDecode(c.body)})).timeout(const Duration(seconds:120));
      if(r.statusCode!=200)throw Exception(err(r));
      final d=m(jsonDecode(r.body));
      if(mounted)setState(()=>{result=d,layers=l(d['layers'].isNotEmpty?d['layers']:d['providers']),status='Done • ${d['successful']??0}/6 layers responded'});
    }catch(e){if(mounted)setState(()=>status='AI error: ${e.toString().replaceFirst('Exception: ','')}');}
    finally{if(mounted)setState(()=>running=false);}
  }

  @override void initState(){super.initState();loadStatus();}
  @override void dispose(){timer?.cancel();key.dispose();super.dispose();}

  Color stateColor(String s){final u=s.toUpperCase();if(u.contains('CALL'))return Colors.green;if(u.contains('PUT'))return Colors.red;if(u.contains('WAIT')||u.contains('NO QUALIFYING'))return Colors.orange;return Colors.blue;}

  Widget layerCard(dynamic raw){
    final p=m(raw); final st=(p['status']??'').toString(); final ok=st=='ok';
    return Card(child:ListTile(
      leading:CircleAvatar(child:Text((p['id']??'').toString().replaceAll('layer-',''))),
      title:Text((p['name']??'OpenAI Layer').toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('${p['role']??''}\n${p['state']??'WAIT'} • OpenAI • ${p['model']??''}'),
      isThreeLine:true,
      trailing:Icon(ok?Icons.check_circle:Icons.warning,color:ok?Colors.green:Colors.orange),
    ));
  }

  @override Widget build(BuildContext context){
    final fin=(result['final']??'').toString();
    return ListView(padding:const EdgeInsets.all(14),children:[
      const Text('6-LAYER OPENAI AI',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:4),
      Text('One OpenAI Access Key • six independent validation layers • ${widget.symbol.toUpperCase()}'),
      const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('OPENAI ACCESS KEY',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:6),
        const Text('Key is transmitted to the backend over HTTPS and kept in backend memory only.'),
        const SizedBox(height:10),
        TextField(controller:key,obscureText:true,decoration:const InputDecoration(labelText:'OpenAI Access Key',hintText:'sk-…',border:OutlineInputBorder())),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:FilledButton.icon(onPressed:savingKey?null:connectKey,icon:const Icon(Icons.key),label:Text(savingKey?'CONNECTING...':'CONNECT OPENAI'))),
          const SizedBox(width:8),
          OutlinedButton(onPressed:clearKey,child:const Text('CLEAR')),
        ]),
      ]))),
      const SizedBox(height:8),
      Text(status),
      const SizedBox(height:10),
      FilledButton.icon(onPressed:running?null:run,icon:const Icon(Icons.psychology),label:Text(running?'RUNNING 6 LAYERS...':'RUN 6-LAYER AI')),
      if(fin.isNotEmpty)Card(color:stateColor(fin).withValues(alpha:.12),child:Padding(padding:const EdgeInsets.all(14),child:Text('FINAL: $fin',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:stateColor(fin))))),
      const SizedBox(height:8),
      ...layers.map(layerCard),
      const SizedBox(height:8),
      const Text('Safety rule: missing/conflicting evidence forces WAIT. AI cannot change strike, entry, SL or target. No orders are placed.',style:TextStyle(fontSize:11)),
    ]);
  }
}
