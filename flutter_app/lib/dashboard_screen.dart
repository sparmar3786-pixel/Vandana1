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
  String period = '1D';
  String connection = 'CONNECTING';
  bool busy = false;
  Timer? timer;
  static const indices = <String>['NIFTY','BANKNIFTY','FINNIFTY','MIDCPNIFTY','SENSEX','BANKEX'];

  @override void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds:5), (_) => load());
  }
  @override void didUpdateWidget(covariant DashboardScreen old) {
    super.didUpdateWidget(old);
    if (old.backendUrl != widget.backendUrl || old.apiToken != widget.apiToken) load();
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  Map<String,String> get headers => <String,String>{
    if (widget.apiToken.trim().isNotEmpty) 'x-token': widget.apiToken.trim(),
  };
  Uri uri(String p) => Uri.parse(widget.backendUrl.trim().replaceFirst(RegExp(r'/+$'), '') + p);
  String val(dynamic v, [String d='—']) => v == null || v.toString().trim().isEmpty ? d : v.toString();
  double numv(dynamic v) => double.tryParse((v ?? 0).toString().replaceAll(',', '')) ?? 0;

  Color tone(String s) {
    final x=s.toUpperCase();
    if (x.contains('UP') || x.contains('CALL') || x.contains('BULL')) return const Color(0xFF32D583);
    if (x.contains('DOWN') || x.contains('PUT') || x.contains('BEAR')) return const Color(0xFFFF6B6B);
    return const Color(0xFF70A3FF);
  }

  Future<void> load() async {
    if (busy || widget.backendUrl.trim().isEmpty) return;
    busy=true;
    try {
      final r=await Future.wait<dynamic>([
        http.get(uri('/v1/terminal'),headers:headers).timeout(const Duration(seconds:6)),
        http.get(uri('/v1/angel/option-chain?symbol=$index&count=12'),headers:headers).timeout(const Duration(seconds:10)),
      ]);
      if (!mounted) return;
      dynamic a,b;
      try { a=jsonDecode((r[0] as http.Response).body); } catch (_) {}
      try { b=jsonDecode((r[1] as http.Response).body); } catch (_) {}
      final t=a is Map ? Map<String,dynamic>.from(a) : <String,dynamic>{};
      final c=t['connection'];
      final angel=c is Map && c['angel']==true;
      setState(() {
        data=t;
        options=b is Map && b['rows'] is List ? List<dynamic>.from(b['rows']) : <dynamic>[];
        connection=(r[0] as http.Response).statusCode==200 && angel ? 'CONNECTED' :
          (r[0] as http.Response).statusCode==200 ? 'SERVER OK' : 'OFFLINE';
      });
    } catch (_) {
      if (mounted) setState(()=>connection='OFFLINE');
    } finally { busy=false; }
  }

  Widget pill(String s,{bool on=false,Color? color}) {
    final c=color??const Color(0xFF70A3FF);
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),
      decoration:BoxDecoration(
        color:on?c.withValues(alpha:.14):const Color(0xFF111827),
        borderRadius:BorderRadius.circular(20),
        border:Border.all(color:on?c:const Color(0xFF263247)),
      ),
      child:Text(s,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:on?c:const Color(0xFF98A2B3))),
    );
  }

  Widget card(Widget w,{EdgeInsets padding=const EdgeInsets.all(14)}) => Container(
    width:double.infinity,margin:const EdgeInsets.only(bottom:10),padding:padding,
    decoration:BoxDecoration(
      color:const Color(0xFF101827),borderRadius:BorderRadius.circular(20),
      border:Border.all(color:const Color(0xFF1D2939)),
      boxShadow:const [BoxShadow(color:Color(0x22000000),blurRadius:16,offset:Offset(0,7))],
    ),child:w,
  );

  Widget metric(String k,String v,{Color? c}) => Expanded(child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(k,style:const TextStyle(fontSize:9,color:Color(0xFF667085))),
      const SizedBox(height:3),
      Text(v,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:c??const Color(0xFFF2F4F7))),
    ],
  ));

  Widget sectionTitle(String a,String b) => Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(a,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),
      Text(b,style:const TextStyle(fontSize:9,color:Color(0xFF667085))),
    ],
  );

  Map<String,dynamic> get engine {
    final raw=data['engine_state'];
    return raw is Map ? Map<String,dynamic>.from(raw) : <String,dynamic>{};
  }

  Widget topHeader() => Row(children:[
    Container(width:42,height:42,decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[Color(0xFF1F6FEB),Color(0xFF7C3AED)]),
      borderRadius:BorderRadius.circular(13),
    ),child:const Icon(Icons.candlestick_chart_rounded,color:Colors.white)),
    const SizedBox(width:10),
    const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('VANDANA',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      Text('NSE ALGO TERMINAL',style:TextStyle(fontSize:9,color:Color(0xFF667085),fontWeight:FontWeight.w700,letterSpacing:1.2)),
    ])),
    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(
      color:const Color(0xFF32D583).withValues(alpha:.10),borderRadius:BorderRadius.circular(18),
      border:Border.all(color:const Color(0xFF32D583).withValues(alpha:.35)),
    ),child:Row(children:[
      Container(width:6,height:6,decoration:const BoxDecoration(color:Color(0xFF32D583),shape:BoxShape.circle)),
      const SizedBox(width:6),
      Text(connection,style:const TextStyle(fontSize:9,color:Color(0xFF32D583),fontWeight:FontWeight.w900)),
    ])),
  ]);

  Widget indexSelector() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const SizedBox(height:14),
    SizedBox(height:38,child:ListView.separated(
      scrollDirection:Axis.horizontal,itemCount:indices.length,
      separatorBuilder:(_,__)=>const SizedBox(width:6),
      itemBuilder:(_,i){
        final n=indices[i];
        return GestureDetector(onTap:(){setState(()=>index=n);load();},child:pill(n,on:index==n));
      },
    )),
  ]);

  Widget trendHero() {
    final tr=val(engine['trend'],'WAIT');
    final c=tone(tr);
    final live=connection=='CONNECTED' && data['market_open']==true;
    final market=data['market'];
    final ltp=val(engine['index_ltp'] ?? (market is Map ? market['spot'] : null));
    final change=val(engine['change'] ?? engine['percent_change'] ?? engine['percentChange'],'Awaiting live feed');
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:sectionTitle('MARKET TREND',index+' • '+period)),
        pill(live?'● LIVE':'● LAST STATE',on:true,color:live?const Color(0xFF32D583):const Color(0xFF70A3FF)),
      ]),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(index,style:const TextStyle(fontSize:10,color:Color(0xFF98A2B3))),
          const SizedBox(height:3),
          Text(ltp,style:const TextStyle(fontSize:31,fontWeight:FontWeight.w900)),
          const SizedBox(height:2),
          Text(change,style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w800)),
        ])),
        Container(width:78,height:78,decoration:BoxDecoration(
          color:c.withValues(alpha:.10),borderRadius:BorderRadius.circular(22),
          border:Border.all(color:c.withValues(alpha:.25)),
        ),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(tr.toUpperCase().contains('DOWN')?Icons.south_east:tr.toUpperCase().contains('UP')?Icons.north_east:Icons.remove,color:c,size:24),
          const SizedBox(height:4),Text(tr,style:TextStyle(color:c,fontWeight:FontWeight.w900,fontSize:10)),
        ])),
      ]),
      const SizedBox(height:13),
      Row(children:[
        for(final p in const ['1D','1W','1M']) Padding(
          padding:const EdgeInsets.only(right:6),
          child:GestureDetector(onTap:()=>setState(()=>period=p),child:pill(p,on:period==p)),
        ),
        const Spacer(),const Text('Change',style:TextStyle(fontSize:9,color:Color(0xFF667085))),
      ]),
    ]));
  }

  Widget signalCard() {
    final s=val(engine['signal_status'],'Signal unavailable');
    final cp=val(engine['ce_pe'],s);
    final c=tone(cp);
    final priority=val(engine['priority'],'—');
    final confidence=val(engine['confidence'],'Awaiting validation');
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:sectionTitle('CALL / PUT SIGNAL','Read-only paper signal')),
        pill('PRIORITY '+priority,color:c),
      ]),
      const SizedBox(height:12),
      Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(
        color:c.withValues(alpha:.10),borderRadius:BorderRadius.circular(15),
        border:Border.all(color:c.withValues(alpha:.28)),
      ),child:Row(children:[
        Icon(cp.toUpperCase().contains('PUT')?Icons.trending_down_rounded:Icons.trending_up_rounded,color:c),
        const SizedBox(width:8),
        Expanded(child:Text(s,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:c))),
      ])),
      const SizedBox(height:10),
      Row(children:[
        metric('ENTRY',val(engine['entry'])),metric('SL',val(engine['stop_loss'])),
        metric('TARGET',val(engine['target'])),metric('CONFIDENCE',confidence),
      ]),
      const SizedBox(height:9),
      Text(val(engine['reason'],'No live recommendation • awaiting validation'),style:const TextStyle(fontSize:10,color:Color(0xFF98A2B3))),
      const SizedBox(height:9),
      Row(children:[
        Expanded(child:pill('CALL',on:cp.toUpperCase().contains('CALL'),color:const Color(0xFF32D583))),
        const SizedBox(width:6),
        Expanded(child:pill('PUT',on:cp.toUpperCase().contains('PUT'),color:const Color(0xFFFF6B6B))),
      ]),
    ]));
  }

  Widget oiPressure() {
    double ce=0,pe=0;
    for(final r in options){
      if(r is! Map)continue;
      final x=numv(r['oi']); final type=(r['type']??'').toString().toUpperCase();
      if(type=='CE')ce+=x; if(type=='PE')pe+=x;
    }
    final total=ce+pe; final ceRatio=total>0?ce/total:.5; final peRatio=total>0?pe/total:.5;
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      sectionTitle('OPTION CHAIN / OI PRESSURE','Strike • Call OI • Put OI • '+index),
      const SizedBox(height:11),
      if(options.isEmpty) const Text('Market data unavailable',style:TextStyle(fontSize:10,color:Color(0xFF667085)))
      else Row(children:[
        metric('CALL OI',ce.toStringAsFixed(0),c:const Color(0xFF32D583)),
        metric('PUT OI',pe.toStringAsFixed(0),c:const Color(0xFFFF6B6B)),
        metric('STRIKES',options.length.toString()),
      ]),
      const SizedBox(height:10),
      Row(children:[
        Expanded(flex:((ceRatio*1000).round().clamp(1,999)).toInt(),child:Container(height:7,decoration:BoxDecoration(color:const Color(0xFF32D583),borderRadius:BorderRadius.circular(7)))),
        const SizedBox(width:3),
        Expanded(flex:((peRatio*1000).round().clamp(1,999)).toInt(),child:Container(height:7,decoration:BoxDecoration(color:const Color(0xFFFF6B6B),borderRadius:BorderRadius.circular(7)))),
      ]),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('CALL pressure',style:TextStyle(fontSize:9,color:Color(0xFF98A2B3))),
          const SizedBox(height:2),Text(ce>pe?'Detected':'Not available',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:ce>pe?const Color(0xFF32D583):const Color(0xFF667085))),
        ])),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('PUT pressure',style:TextStyle(fontSize:9,color:Color(0xFF98A2B3))),
          const SizedBox(height:2),Text(pe>ce?'Detected':'Not available',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:pe>ce?const Color(0xFFFF6B6B):const Color(0xFF667085))),
        ])),
      ]),
    ]));
  }

  Widget sourceCards() => Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.account_balance_outlined,size:18,color:Color(0xFF70A3FF)),
      const SizedBox(height:7),const Text('NSE / BSE',style:TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
      const SizedBox(height:4),Text(connection,style:const TextStyle(fontSize:9,color:Color(0xFF98A2B3))),
    ]))),
    const SizedBox(width:8),
    Expanded(child:card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.waterfall_chart_rounded,size:18,color:Color(0xFF70A3FF)),
      const SizedBox(height:7),const Text('COMMODITIES',style:TextStyle(fontWeight:FontWeight.w800,fontSize:12)),
      const SizedBox(height:4),Text(data['commodity'] is Map?'Connected':'Awaiting feed',style:const TextStyle(fontSize:9,color:Color(0xFF98A2B3))),
    ]))),
  ]);

  Widget priceAction() => card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    sectionTitle('PRICE ACTION','Technical confirmation'),
    const SizedBox(height:10),
    Row(children:[
      for(final x in const ['EMA','VWAP','RSI']) Padding(padding:const EdgeInsets.only(right:6),child:pill(x,on:true)),
    ]),
    const SizedBox(height:10),
    Container(height:76,width:double.infinity,decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(14),
      gradient:const LinearGradient(begin:Alignment.bottomLeft,end:Alignment.topRight,colors:[Color(0xFF0B1220),Color(0xFF141E30)]),
      border:Border.all(color:const Color(0xFF1D2939)),
    ),child:const Row(children:[
      SizedBox(width:13),Icon(Icons.show_chart_rounded,color:Color(0xFF70A3FF),size:25),SizedBox(width:9),
      Expanded(child:Text('Chart data is available in Charts',style:TextStyle(fontSize:10,color:Color(0xFF98A2B3)))),
      Icon(Icons.chevron_right_rounded,color:Color(0xFF667085)),SizedBox(width:10),
    ])),
  ]));

  Widget aiValidation() {
    const names=<String>['Trend AI','Options AI','Pattern AI','Consensus AI','Risk AI','News AI'];
    final x=data['ai'];
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      sectionTitle('AI VALIDATION','Six-layer server-side validation'),const SizedBox(height:8),
      for(final n in names) Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[
        Container(width:25,height:25,decoration:BoxDecoration(color:const Color(0xFF70A3FF).withValues(alpha:.10),borderRadius:BorderRadius.circular(8)),child:const Icon(Icons.psychology_alt_rounded,size:14,color:Color(0xFF70A3FF))),
        const SizedBox(width:9),Expanded(child:Text(n,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700))),
        Text(x is Map&&x[n]!=null?val(x[n]):'Pending',style:const TextStyle(fontSize:9,color:Color(0xFF98A2B3))),
      ])),
      const Divider(color:Color(0xFF1D2939)),
      Row(children:[
        const Icon(Icons.verified_outlined,size:16,color:Color(0xFF70A3FF)),const SizedBox(width:7),
        Expanded(child:Text('Final: '+val(engine['signal_status'],'WAIT'),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900))),
      ]),
    ]));
  }

  @override Widget build(BuildContext context) {
    return Container(color:const Color(0xFF070B14),child:RefreshIndicator(
      onRefresh:load,color:const Color(0xFF70A3FF),backgroundColor:const Color(0xFF101827),
      child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(14,14,14,30),children:[
        topHeader(),indexSelector(),const SizedBox(height:10),
        trendHero(),signalCard(),oiPressure(),sourceCards(),priceAction(),aiValidation(),
        card(const Row(children:[
          Icon(Icons.shield_outlined,color:Color(0xFF70A3FF),size:18),SizedBox(width:8),
          Expanded(child:Text('READ ONLY • PAPER SIGNALS • NO ORDER PLACEMENT',style:TextStyle(fontSize:9,fontWeight:FontWeight.w800))),
        ])),
      ]),
    ));
  }
}  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 150, child: Text(label, style: TextStyle(color: Colors.grey.shade400))),
        Expanded(child: Text(_value(value), style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _infoCard(String title, String value, Color color) => Card(
    color: color.withOpacity(.10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: color.withOpacity(.45)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(children: <Widget>[
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final marketOpen = _terminal?['market_open'] == true;
    final raw = _terminal?['engine_state'];
    final engine = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    final trend = _value(engine['trend']);
    final action = _value(engine['signal_status']);
    final up = trend.toUpperCase().contains('UP');
    final down = trend.toUpperCase().contains('DOWN');
    final accent = !marketOpen
        ? Colors.blue
        : up
            ? Colors.green
            : down
                ? Colors.red
                : Colors.blue;

    return Container(
      color: const Color(0xFF0A0F16),
      child: RefreshIndicator(
        onRefresh: _fetchTerminal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          children: <Widget>[
            Card(
              color: accent.withOpacity(.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: accent, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      const Icon(Icons.bolt, size: 30),
                      const SizedBox(width: 10),
                      const Expanded(child: Text(
                        'NSE Algo Signal',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                      )),
                      Chip(
                        backgroundColor: accent,
                        label: Text(
                          marketOpen ? trend : 'MARKET CLOSED',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Engine status: ' + _value(engine['status']),
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const Text('Live snapshot • no fabricated values'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('CURRENT ENGINE STATE',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    _row('Symbol', engine['symbol']),
                    _row('Index / Underlying LTP', engine['index_ltp']),
                    _row('CE / PE', engine['ce_pe']),
                    _row('Strike Price', engine['strike']),
                    _row('Option LTP', engine['option_ltp']),
                    _row('OI', engine['oi']),
                    _row('OI Change', engine['oi_change']),
                    _row('Volume', engine['volume']),
                    _row('ATM', engine['atm']),
                    _row('Trend', trend),
                    _row('Signal Status', action),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('SIGNAL DETAILS',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    _row('Option Symbol', engine['option_symbol']),
                    _row('Entry', engine['entry']),
                    _row('Stop Loss', engine['stop_loss']),
                    _row('Target', engine['target']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _infoCard('Connection', _connection,
                _connection == 'Connected' ? Colors.green : Colors.orange),
            _infoCard('Mode', 'Paper signals only • No order placement.', Colors.blue),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _busy ? null : _fetchTerminal,
              icon: Icon(_busy ? Icons.sync : Icons.refresh),
              label: const Text('REFRESH LIVE ENGINE'),
            ),
          ],
        ),
      ),
    );
  }
