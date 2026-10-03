import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  const DashboardScreen({super.key, this.backendUrl = '', this.apiToken = ''});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String,dynamic> data = <String,dynamic>{};
  List<dynamic> options = <dynamic>[];
  String index = 'NIFTY';
  String connection = 'CONNECTING';
  bool busy = false;
  Timer? timer;
  static const indices = <String>['NIFTY','BANKNIFTY','FINNIFTY','MIDCPNIFTY','SENSEX','BANKEX'];

  @override void initState() { super.initState(); load(); timer=Timer.periodic(const Duration(seconds:5),(_)=>load()); }
  @override void didUpdateWidget(covariant DashboardScreen old) { super.didUpdateWidget(old); if(old.backendUrl!=widget.backendUrl||old.apiToken!=widget.apiToken) load(); }
  @override void dispose(){timer?.cancel();super.dispose();}

  Map<String,String> get headers => <String,String>{if(widget.apiToken.trim().isNotEmpty)'x-token':widget.apiToken.trim()};
  Uri uri(String p)=>Uri.parse(widget.backendUrl.trim().replaceFirst(RegExp(r'/+$'),'')+p);
  String val(dynamic v,[String d='—'])=>v==null||v.toString().trim().isEmpty?d:v.toString();
  Color tone(String s){final x=s.toUpperCase();if(x.contains('UP')||x.contains('CALL')||x.contains('BULL'))return const Color(0xFF32D583);if(x.contains('DOWN')||x.contains('PUT')||x.contains('BEAR'))return const Color(0xFFFF6B6B);return const Color(0xFF70A3FF);}
  double numv(dynamic v)=>double.tryParse((v??0).toString().replaceAll(',',''))??0;

  Future<void> load() async {
    if(busy||widget.backendUrl.trim().isEmpty)return; busy=true;
    try{
      final r=await Future.wait<dynamic>([
        http.get(uri('/v1/terminal'),headers:headers).timeout(const Duration(seconds:6)),
        http.get(uri('/v1/angel/option-chain?symbol='+index+'&count=8'),headers:headers).timeout(const Duration(seconds:10)),
      ]);
      if(!mounted)return;
      dynamic a,b;try{a=jsonDecode((r[0] as http.Response).body);}catch(_){}
      try{b=jsonDecode((r[1] as http.Response).body);}catch(_){}
      final t=a is Map?Map<String,dynamic>.from(a):<String,dynamic>{};
      final c=t['connection']; final angel=c is Map&&c['angel']==true;
      setState((){data=t;options=b is Map&&b['rows'] is List?List<dynamic>.from(b['rows']):<dynamic>[];connection=(r[0] as http.Response).statusCode==200&&angel?'LIVE':(r[0] as http.Response).statusCode==200?'BACKEND OK':'OFFLINE';});
    }catch(_){if(mounted)setState(()=>connection='OFFLINE');}finally{busy=false;}
  }

  Widget pill(String s,{bool on=false,Color? color}){final c=color??const Color(0xFF70A3FF);return Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:on?c.withValues(alpha:.15):const Color(0xFF101827),borderRadius:BorderRadius.circular(20),border:Border.all(color:on?c:const Color(0xFF263247))),child:Text(s,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:on?c:const Color(0xFF98A2B3))));}
  Widget card(Widget w)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF101827),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFF1D2939))),child:w);
  Widget metric(String k,String v,{Color? c})=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(k,style:const TextStyle(fontSize:9,color:Color(0xFF667085))),const SizedBox(height:3),Text(v,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:c))]));
  Widget title(String a,String b)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(b,style:const TextStyle(fontSize:9,color:Color(0xFF667085)))]));
  Widget sectionRow(String a,String b)=>Row(children:[Expanded(child:Text(a,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800))),Text(b,style:const TextStyle(fontSize:10,color:Color(0xFF98A2B3)))]);

  Widget hero(Map<String,dynamic> e){
    final tr=val(e['trend'],'WAIT');final c=tone(tr);final live=connection=='LIVE'&&data['market_open']==true;
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.bolt_rounded,size:21),const SizedBox(width:7),const Expanded(child:Text('VANDANA • NSE ALGO TERMINAL',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900))),pill(live?'● LIVE':'● LAST STATE',on:true,color:live?const Color(0xFF32D583):const Color(0xFF70A3FF))]),
      const SizedBox(height:15),
      Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(index,style:const TextStyle(fontSize:10,color:Color(0xFF98A2B3))),const SizedBox(height:3),Text(val(e['index_ltp']),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),Text(val(e['change']??e['percent_change']??e['percentChange']),style:TextStyle(color:c,fontWeight:FontWeight.w800))])),
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:c.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Column(children:[Icon(tr.toUpperCase().contains('DOWN')?Icons.south_east:tr.toUpperCase().contains('UP')?Icons.north_east:Icons.remove,color:c),Text(tr,style:TextStyle(color:c,fontWeight:FontWeight.w900,fontSize:10))]))
      ])
    ]));
  }

  Widget signal(Map<String,dynamic> e){
    final s=val(e['signal_status'],'WAIT');final c=tone(val(e['ce_pe'],s));
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('CALL / PUT SIGNAL',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900))),pill('PRIORITY '+val(e['priority']),color:c)]),
      const SizedBox(height:10),
      Row(children:[Expanded(child:Text(s,style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:c))),Text('Confidence '+val(e['confidence']),style:const TextStyle(fontSize:9,color:Color(0xFF98A2B3)))]),
      const SizedBox(height:11),
      Row(children:[metric('STRIKE',val(e['strike'])),metric('ENTRY',val(e['entry'])),metric('SL',val(e['stop_loss'])),metric('TARGET',val(e['target']))]),
      const SizedBox(height:8),Text(val(e['reason'],'Awaiting live validation'),style:const TextStyle(fontSize:10,color:Color(0xFF98A2B3)))
    ]));
  }

  Widget oi(){
    num ce=0,pe=0;for(final r in options){if(r is! Map)continue;final x=numv(r['oi']);if((r['type']??'').toString().toUpperCase()=='CE')ce+=x;if((r['type']??'').toString().toUpperCase()=='PE')pe+=x;}
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      title('OPTION CHAIN / OI PRESSURE','Live CE / PE snapshot • '+index),
      options.isEmpty?const Text('Market data unavailable',style:TextStyle(fontSize:10,color:Color(0xFF667085))):Row(children:[metric('CALL OI',ce.toStringAsFixed(0),c:const Color(0xFF32D583)),metric('PUT OI',pe.toStringAsFixed(0),c:const Color(0xFFFF6B6B)),metric('ROWS',options.length.toString())]),
      const SizedBox(height:9),
      Row(children:[Expanded(child:Container(height:5,decoration:BoxDecoration(color:const Color(0xFF32D583),borderRadius:BorderRadius.circular(6)))),const SizedBox(width:4),Expanded(child:Container(height:5,decoration:BoxDecoration(color:const Color(0xFFFF6B6B),borderRadius:BorderRadius.circular(6))))])
    ]));
  }

  Widget ai(Map<String,dynamic> e){
    const names=<String>['Trend AI','Options AI','Pattern AI','Consensus AI','Risk AI','News AI'];final x=data['ai'];
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      title('6-LAYER AI VALIDATION','Server-side • no Puter sign-in'),
      for(final n in names)Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[const Icon(Icons.psychology_alt,size:15,color:Color(0xFF70A3FF)),const SizedBox(width:8),Expanded(child:Text(n,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700))),Text(x is Map&&x[n]!=null?val(x[n]):'Pending',style:const TextStyle(fontSize:9,color:Color(0xFF98A2B3)))])),
      const Divider(color:Color(0xFF1D2939)),Text('Final: '+val(e['signal_status'],'WAIT'),style:const TextStyle(fontWeight:FontWeight.w900))
    ]));
  }

  @override Widget build(BuildContext context){
    final raw=data['engine_state'];final e=raw is Map<String,dynamic>?raw:raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};
    return Container(color:const Color(0xFF070B14),child:RefreshIndicator(onRefresh:load,color:const Color(0xFF70A3FF),backgroundColor:const Color(0xFF101827),child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(12,12,12,28),children:[
      Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Dashboard',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Professional market command center',style:TextStyle(fontSize:10,color:Color(0xFF667085)))])),IconButton(onPressed:busy?null:load,icon:Icon(busy?Icons.sync:Icons.refresh_rounded))]),
      const SizedBox(height:6),
      SizedBox(height:39,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:indices.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i){final n=indices[i];return GestureDetector(onTap:(){setState(()=>index=n);load();},child:pill(n,on:index==n));})),
      const SizedBox(height:10),hero(e),signal(e),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('NSE / BSE',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(connection,style:const TextStyle(fontSize:10,color:Color(0xFF98A2B3)))]))),const SizedBox(width:8),Expanded(child:card(const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('COMMODITIES',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:6),Text('MCX feed',style:TextStyle(fontSize:10,color:Color(0xFF98A2B3)))])))]),
      oi(),
      card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[title('PRICE ACTION','Live chart data remains in Charts'),Row(children:[pill('EMA'),const SizedBox(width:5),pill('VWAP'),const SizedBox(width:5),pill('RSI'),const SizedBox(width:5),pill('1D',on:true)]),const SizedBox(height:11),Container(height:64,alignment:Alignment.center,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF1D2939))),child:const Text('Open Charts for live candlestick data',style:TextStyle(fontSize:10,color:Color(0xFF667085))))])),
      ai(e),
      card(const Row(children:[Icon(Icons.shield_outlined,color:Color(0xFF70A3FF),size:18),SizedBox(width:8),Expanded(child:Text('READ ONLY • PAPER SIGNALS • NO ORDER PLACEMENT',style:TextStyle(fontSize:9,fontWeight:FontWeight.w800)))]))
    ])));
  }
}
