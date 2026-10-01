import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'signal_alerts.dart';

const String railwayBackendUrl =
    String.fromEnvironment('RAILWAY_BACKEND_URL', defaultValue: '');
const String defaultBackendUrl = railwayBackendUrl;

void main() => runApp(const AlgoApp());

class AlgoApp extends StatelessWidget {
  const AlgoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'NSE Algo Signal',
    theme: ThemeData.dark(useMaterial3: true),
    home: const Terminal(),
  );
}

class Terminal extends StatefulWidget {
  const Terminal({super.key});
  @override State<Terminal> createState() => _TerminalState();
}

class _TerminalState extends State<Terminal> {
  static const screens = <String>[
    'Dashboard','Market','Commodity','Signals','OI Lab','Watchlist','Charts',
    'Option Chain','News','Market Details','Angel API','NSE','NSE MCP','Data',
    'AI Models','Settings','More'
  ];
  static const icons = <IconData>[
    Icons.dashboard, Icons.show_chart, Icons.precision_manufacturing,
    Icons.notifications_active, Icons.analytics, Icons.star, Icons.candlestick_chart,
    Icons.table_chart, Icons.article, Icons.info_outline, Icons.key, Icons.language,
    Icons.hub, Icons.storage, Icons.psychology, Icons.tune, Icons.more_horiz
  ];
  int selected = 0;
  String backendUrl = defaultBackendUrl;
  String apiToken = '';
  String connection = 'Connecting...';
  bool darkMode = true;
  List<dynamic> liveIndices = <dynamic>[];
  List<dynamic> liveCommodities = <dynamic>[];
  String selectedOptionSymbol = 'NIFTY';
  String chartFilterExchange = 'ALL';
  String selectedChartName = 'NIFTY 50';
  String nseMcpStatus = 'Not checked';
  String angelLoginStatus = '';
  String csvStatus = '';
  Map<String,dynamic>? signal;
  List<dynamic> liveMarket = <dynamic>[];
  List<dynamic> liveCandles = <dynamic>[];
  List<dynamic> liveOptionRows = <dynamic>[];
  dynamic optionSpot;
  List<dynamic> liveOIBuild = <dynamic>[];
  String selectedChartToken = '99926000';
  String selectedChartExchange = 'NSE';
  String selectedInterval = 'FIVE_MINUTE';
  bool angelDataBusy = false;
  Map<String,dynamic>? terminalData;
  Timer? timer;
  Timer? marketTimer;
  bool chartBusy = false;
  SignalAlertService? alertService;
  SignalAlert? latestAlert;

  @override void initState() {
    super.initState();
    fetchTerminal();
    fetchIndices();
    fetchCommodities();
    alertService = SignalAlertService(backendUrl, apiToken);
    alertService!.onAlert = (a) {
      if (!mounted) return;
      setState(() => latestAlert = a);
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && latestAlert?.seq == a.seq) setState(() => latestAlert = null);
      });
    };
    alertService!.start();
    timer = Timer.periodic(const Duration(seconds: 5), (_) { fetchTerminal(); if (selected == 6) fetchCandles(); });
    marketTimer = Timer.periodic(const Duration(seconds: 10), (_) { fetchIndices(); fetchCommodities(); });
  }
  @override void dispose() { timer?.cancel(); marketTimer?.cancel(); alertService?.stop(); super.dispose(); }

  Future<void> fetchTerminal() async {
    try {
      final response = await http.get(
        backendUri('/v1/terminal'),
        headers: <String,String>{'x-token': apiToken},
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      dynamic decoded;
      try { decoded = jsonDecode(response.body); } catch (_) { decoded = null; }
      final conn = decoded is Map<String,dynamic> ? decoded['connection'] : null;
      final angel = conn is Map && conn['angel'] == true;
      setState(() {
        terminalData = decoded is Map<String,dynamic> ? decoded : null;
        final s = terminalData?['signals'];
        final m = terminalData?['nse_mcp'];
        signal = s is Map<String,dynamic> ? s : null;
        connection = response.statusCode == 200 && conn is Map && conn['server'] == true && conn['angel'] == true ? 'Connected' : response.statusCode == 200 && conn is Map && conn['server'] == true ? 'Backend connected / Angel not connected' : 'HTTP ' + response.statusCode.toString();
        nseMcpStatus = m is Map && m['connected'] == true ? 'Connected' : 'Not connected';
      });
      if (angel) await fetchAngelMarket();
    } catch (_) {
      if (mounted) setState(() => connection = 'Backend not connected');
    }
  }

  Future<void> downloadNseCsv() async {
    setState(() => csvStatus = 'Fetching NSE option chain...');
    try {
      final response = await http.get(
        Uri.parse(backendUrl + '/v1/nse/option-chain.csv?symbol=NIFTY'),
        headers: <String,String>{'x-token': apiToken},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        setState(() => csvStatus = 'NSE CSV unavailable: HTTP ' + response.statusCode.toString());
        return;
      }
      await FileSaver.instance.saveFile(
        name: 'NIFTY_NSE_option_chain',
        bytes: response.bodyBytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      if (mounted) setState(() => csvStatus = 'NIFTY NSE option-chain CSV saved.');
    } catch (e) {
      if (mounted) setState(() => csvStatus = 'CSV download failed. ' + e.toString());
    }
  }

  @override Widget build(BuildContext context) => Theme(
    data: ThemeData(useMaterial3: true, brightness: darkMode ? Brightness.dark : Brightness.light),
    child: Scaffold(
    appBar: AppBar(
      title: Text(screens[selected]),
      actions: <Widget>[
        IconButton(onPressed: fetchTerminal, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => setState(() => darkMode = !darkMode), tooltip: 'Light / Dark mode', icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode)),
        IconButton(onPressed: openSettings, icon: const Icon(Icons.settings)),
      ],
    ),
    drawer: Drawer(
      child: SafeArea(child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(Icons.candlestick_chart, size: 42),
            SizedBox(height: 10),
            Text('NSE Algo Signal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('17-screen paper terminal'),
          ])),
          for (int i=0; i<screens.length; i++) ListTile(
            leading: Icon(icons[i]),
            title: Text(screens[i]),
            selected: selected == i,
            onTap: () { Navigator.pop(context); setState(() => selected = i); },
          ),
        ],
      )),
    ),
    body: Stack(
      children: <Widget>[
        buildScreen(),
        if (latestAlert != null)
          Positioned(
            top: 8, left: 8, right: 8,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: latestAlert!.kind == 'ENTRY' ? Colors.green.shade700 : Colors.red.shade700,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => latestAlert = null),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(latestAlert!.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(latestAlert!.body, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ),
      ],
    ),
  ),
  );

  Widget buildScreen() {
    if (selected == 0) return dashboard();
    if (selected == 1) return marketPage();
    if (selected == 2) return commodityPage();
    if (selected == 3) return signals();
    if (selected == 4) return oiLabPage();
    if (selected == 5) return watchlistPage();
    if (selected == 6) return chartsPage();
    if (selected == 7) return optionChain();
    if (selected == 8) return newsPage();
    if (selected == 9) return marketDetailsPage();
    if (selected == 10) return angelApi();
    if (selected == 12) return nseMcp();
    if (selected == 14) return aiModelsPage();
    if (selected == 15) return settingsPage();
    if (selected == 16) return morePage();
    return dataPage(screens[selected]);
  }

  Widget dashboard() {
    final marketOpen = terminalData?['market_open'] == true;
    final nifty = liveIndices.where((x)=>x is Map && ((x['name']??x['symbol']??'').toString().toUpperCase().contains('NIFTY 50'))).cast<dynamic>().toList();
    final nq = nifty.isNotEmpty ? nifty.first : <String,dynamic>{};
    final pct = num.tryParse((nq['percentChange']??nq['netChange']??'').toString());
    final action = signal?['action']?.toString().toUpperCase() ?? 'WAIT';
    final up = pct != null ? pct > 0 : action.contains('CALL');
    final down = pct != null ? pct < 0 : action.contains('PUT');
    final color = !marketOpen ? Colors.blue : up ? Colors.green : down ? Colors.red : Colors.blue;
    final trend = !marketOpen ? 'MARKET CLOSED' : up ? 'UP TREND' : down ? 'DOWN TREND' : 'NEUTRAL';
    final hot = (signal?['symbol'] ?? signal?['tradingSymbol'] ?? selectedOptionSymbol).toString();
    final spot = signal?['spot'] ?? nq['ltp'] ?? '-';
    return ListView(padding: const EdgeInsets.all(12), children: <Widget>[
      Card(color: color.withOpacity(.18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color, width: 1.5)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[const Icon(Icons.bolt, size: 30), const SizedBox(width: 10), const Expanded(child: Text('NSE Algo Signal', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))), Chip(backgroundColor: color, label: Text(trend, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 8), Text('Market trend: $trend', style: TextStyle(color: color, fontWeight: FontWeight.bold)), Text('Hot: $hot  •  Spot: $spot'),
      ]))),
      const SizedBox(height: 10),
      Card(child: ListTile(leading: Icon(Icons.local_fire_department, color: color), title: const Text('CURRENT SIGNAL • HOT SPOT'), subtitle: Text('$hot • Spot $spot'), trailing: Text(action, style: TextStyle(color: color, fontWeight: FontWeight.bold)))),
      if (signal != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('CURRENT SIGNAL'), const SizedBox(height: 8), row('Symbol', signal!['symbol']), row('Spot', signal!['spot']), row('Strike', (signal!['strike'] ?? '-').toString() + ' ' + (signal!['type'] ?? '').toString()), row('Entry', signal!['entry']), row('LTP', signal!['ltp']), row('Stop Loss', signal!['sl']), row('Target', signal!['target']),
      ]))),
      const SizedBox(height: 10), infoCard('Connection', connection, connection == 'Connected' ? Colors.green : Colors.orange),
      infoCard('Mode', 'Paper signals only • No order placement.', Colors.blue),
    ]);
  }

  Future<void> fetchIndices() async {
    try {
      final r=await http.get(backendUri('/v1/angel/indices'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:8));
      if(r.statusCode==200){final d=jsonDecode(r.body);final rows=d is Map&&d['data'] is List?d['data']:<dynamic>[];if(mounted)setState(()=>liveIndices=rows is List?rows:<dynamic>[]);}
    } catch (_) {}
  }

  Future<void> fetchCommodities() async {
    try {
      final r=await http.get(backendUri('/v1/angel/commodities'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:10));
      if(r.statusCode==200){final d=jsonDecode(r.body);final rows=d is Map&&d['data'] is Map&&d['data']['fetched'] is List?d['data']['fetched']:<dynamic>[];if(mounted)setState(()=>liveCommodities=rows is List?rows:<dynamic>[]);}
    } catch (_) {}
  }

  Future<void> fetchAngelMarket() async {
    try {
      final r=await http.get(backendUri('/v1/angel/market'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:8));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['data'] is Map ? (d['data']['fetched'] ?? <dynamic>[]) : <dynamic>[];
        if(mounted) setState(()=>liveMarket=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {}
  }

  Future<void> fetchCandles() async {
    if(chartBusy)return;
    chartBusy=true;
    if(mounted)setState(()=>angelDataBusy=true);
    try {
      final u=backendUrl+'/v1/angel/candles?exchange='+selectedChartExchange+'&token='+selectedChartToken+'&interval='+selectedInterval+'&days=1';
      final r=await http.get(Uri.parse(u),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:12));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['data'] is List ? d['data'] : <dynamic>[];
        if(mounted) setState(()=>liveCandles=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {} finally { chartBusy=false; if(mounted) setState(()=>angelDataBusy=false); }
  }

  Future<void> fetchOptionRows() async {
    setState(()=>angelDataBusy=true);
    try {
      final r=await http.get(backendUri('/v1/angel/option-chain?symbol='+selectedOptionSymbol+'&count=10'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:15));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['rows'] is List ? d['rows'] : <dynamic>[];
        if(mounted) setState(() { liveOptionRows=rows is List ? rows : <dynamic>[]; optionSpot=d is Map ? d['spot'] : null; });
      }
    } catch (_) {} finally { if(mounted) setState(()=>angelDataBusy=false); }
  }

  Future<void> fetchOIBuild() async {
    setState(()=>angelDataBusy=true);
    try {
      final r=await http.get(backendUri('/v1/angel/oi-buildup?datatype=Long%20Built%20Up&expirytype=NEAR'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:12));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['data'] is List ? d['data'] : <dynamic>[];
        if(mounted) setState(()=>liveOIBuild=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {} finally { if(mounted) setState(()=>angelDataBusy=false); }
  }

  Widget indexCard(dynamic q) {
    final name=(q['tradingSymbol']??q['tradingsymbol']??'-').toString();
    return Card(child:ListTile(
      title:Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('Open '+(q['open']??'-').toString()+'  High '+(q['high']??'-').toString()+'  Low '+(q['low']??'-').toString()),
      trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:<Widget>[
        Text((q['ltp']??'-').toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        Text((q['netChange']??'').toString()+' '+(q['percentChange']??'').toString())
      ]),
    ));
  }

  Widget marketPage() => ListView(padding:const EdgeInsets.all(12),children:<Widget>[
    const Text('Market • Indian Indices',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)), const SizedBox(height:8),
    infoCard('Live source','Angel One SmartAPI • NSE + BSE index universe',Colors.blue),
    ...liveIndices.map((q)=>_quoteCard(q)),
    if(liveIndices.isEmpty) infoCard('Indices','Waiting for Angel One index feed.',Colors.orange),
    FilledButton.icon(onPressed:fetchIndices,icon:const Icon(Icons.refresh),label:const Text('REFRESH ALL INDIAN INDICES')),
  ]);

  Widget _quoteCard(dynamic q) {
    final pct=num.tryParse((q['percentChange']??q['netChange']??'').toString())??0;
    final color=pct>0?Colors.green:pct<0?Colors.red:Colors.blue;
    return Card(child:ListTile(title:Text((q['name']??q['symbol']??'-').toString()),subtitle:Text((q['exchange']??'').toString()+' • '+(q['percentChange']??q['netChange']??'-').toString()),trailing:Text((q['ltp']??'-').toString(),style:TextStyle(color:color,fontSize:18,fontWeight:FontWeight.bold))));
  }

  Widget commodityPage() => ListView(padding:const EdgeInsets.all(12),children:<Widget>[
    const Text('Commodity • MCX',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)), const SizedBox(height:8),
    infoCard('Live source','Angel One SmartAPI • MCX current contracts',Colors.blue),
    ...liveCommodities.map((q)=>Card(child:ListTile(title:Text((q['tradingSymbol']??q['name']??'-').toString()),subtitle:Text('Expiry '+(q['expiry']??'-').toString()+' • OI '+(q['oi']??'-').toString()),trailing:Text((q['ltp']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))))),
    if(liveCommodities.isEmpty) infoCard('MCX','Waiting for commodity contracts/live quotes.',Colors.orange),
    FilledButton.icon(onPressed:fetchCommodities,icon:const Icon(Icons.refresh),label:const Text('REFRESH MCX')),
  ]);

  Widget oiLabPage() => ListView(padding:const EdgeInsets.all(12),children:<Widget>[
    const Text('OI Lab • Indian Index Options',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Scope','Only Indian index option OI. MCX/futures are excluded.',Colors.blue),
    Wrap(spacing:6,children:<Widget>[
      for(final sym in const['NIFTY','BANKNIFTY','FINNIFTY','MIDCPNIFTY','SENSEX','BANKEX'])
        FilterChip(label:Text(sym),selected:selectedOptionSymbol==sym,onSelected:(_){setState(()=>selectedOptionSymbol=sym);fetchOptionRows();})
    ]),
    const SizedBox(height:8),
    if(liveOptionRows.isNotEmpty) _oiSummaryCards(),
    if(liveOptionRows.isEmpty) infoCard('OI snapshot','Select an index to load its live CE/PE OI snapshot.',Colors.orange),
  ]);

  Widget _oiSummaryCards() {
    num ceOI=0,peOI=0,ceUp=0,peUp=0,ceDown=0,peDown=0;
    for(final r in liveOptionRows){
      final oi=num.tryParse((r['oi']??0).toString())??0;
      final ch=num.tryParse((r['oiChangePct']??0).toString())??0;
      if(r['type']=='CE'){ceOI+=oi;if(ch>0)ceUp++;if(ch<0)ceDown++;}
      if(r['type']=='PE'){peOI+=oi;if(ch>0)peUp++;if(ch<0)peDown++;}
    }
    return Column(children:<Widget>[
      Row(children:<Widget>[
        Expanded(child:infoCard('CALL OI',ceOI.toStringAsFixed(0)+' • ↑ '+ceUp.toString()+' ↓ '+ceDown.toString(),Colors.green)),
        const SizedBox(width:8),
        Expanded(child:infoCard('PUT OI',peOI.toStringAsFixed(0)+' • ↑ '+peUp.toString()+' ↓ '+peDown.toString(),Colors.red)),
      ]),
      infoCard('OI direction','↑ OI = addition • ↓ OI = reduction • selected index: '+selectedOptionSymbol,Colors.blue),
    ]);
  }

  Widget watchlistPage() => ListView(padding:const EdgeInsets.all(12),children:<Widget>[
    const Text('Watchlist • All Indian Indices',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)), const SizedBox(height:8),
    ...liveIndices.map((q)=>Card(child:ListTile(leading:const Icon(Icons.star_border),title:Text((q['name']??q['symbol']??'-').toString()),subtitle:Text((q['exchange']??'').toString()),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:<Widget>[Text((q['ltp']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.bold)),Text((q['percentChange']??q['netChange']??'-').toString())])))),
    if(liveIndices.isEmpty) infoCard('Watchlist','Waiting for index feed.',Colors.orange),
  ]);

  Widget chartsPage() => ListView(padding:const EdgeInsets.all(10),children:<Widget>[
    Row(children:<Widget>[const Expanded(child:Text('Charts • Indian Indices',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold))),IconButton(onPressed:openFullscreenChart,icon:const Icon(Icons.fullscreen))]),
    _exchangeTabs(), const SizedBox(height:8),
    SizedBox(height:46,child:ListView(scrollDirection:Axis.horizontal,children:liveIndices.where((q)=>chartFilterExchange=='ALL'||q['exchange']==chartFilterExchange).map((q)=>Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text((q['name']??q['symbol']??'-').toString()),selected:selectedChartToken==(q['token']??'').toString(),onSelected:(_){setState(()=>selectedChartToken=(q['token']??'').toString());selectedChartName=(q['name']??q['symbol']??'-').toString();selectedChartExchange=(q['exchange']??'NSE').toString();fetchCandles();}))).toList())),
    const SizedBox(height:8), infoCard('Selected',selectedChartName+' • '+selectedChartExchange+' • '+selectedChartToken,Colors.blue),
    DropdownButton<String>(value:selectedInterval,items:const[DropdownMenuItem(value:'ONE_MINUTE',child:Text('1 Minute')),DropdownMenuItem(value:'THREE_MINUTE',child:Text('3 Minute')),DropdownMenuItem(value:'FIVE_MINUTE',child:Text('5 Minute')),DropdownMenuItem(value:'TEN_MINUTE',child:Text('10 Minute')),DropdownMenuItem(value:'FIFTEEN_MINUTE',child:Text('15 Minute')),DropdownMenuItem(value:'THIRTY_MINUTE',child:Text('30 Minute')),DropdownMenuItem(value:'ONE_HOUR',child:Text('1 Hour')),DropdownMenuItem(value:'ONE_DAY',child:Text('1 Day'))],onChanged:(v){if(v!=null){setState(()=>selectedInterval=v);fetchCandles();}}),
    Card(child:SizedBox(height:MediaQuery.of(context).size.height>700?420:320,child:liveCandles.isEmpty?const Center(child:Text('Waiting for live candles…')):CustomPaint(painter:CandlePainter(liveCandles)))),
    FilledButton.icon(onPressed:fetchCandles,icon:const Icon(Icons.refresh),label:Text(angelDataBusy?'LOADING...':'REFRESH LIVE CHART')),
    const SizedBox(height:8),const Text('Indicators',style:TextStyle(fontWeight:FontWeight.bold)),
    Wrap(spacing:6,children:const[Chip(label:Text('EMA 8')),Chip(label:Text('EMA 13')),Chip(label:Text('VWAP')),Chip(label:Text('RSI')),Chip(label:Text('MACD')),Chip(label:Text('OI'))]),
  ]);

  Widget _exchangeTabs()=>SegmentedButton<String>(segments:const[ButtonSegment(value:'ALL',label:Text('ALL INDIA')),ButtonSegment(value:'NSE',label:Text('NSE')),ButtonSegment(value:'BSE',label:Text('BSE'))],selected:<String>{chartFilterExchange},onSelectionChanged:(v){setState(()=>chartFilterExchange=v.first);});

  Future<void> openFullscreenChart() async {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);
    if(!mounted)return;
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text(selectedChartName+' • '+selectedInterval),actions:<Widget>[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),body:Row(children:<Widget>[Expanded(child:Padding(padding:const EdgeInsets.all(8),child:liveCandles.isEmpty?const Center(child:Text('Waiting for live candles…')):CustomPaint(painter:CandlePainter(liveCandles)))),SizedBox(width:190,child:ListView(padding:const EdgeInsets.all(8),children:const[Text('INDICATORS',style:TextStyle(fontWeight:FontWeight.bold)),Chip(label:Text('EMA 8')),Chip(label:Text('EMA 13')),Chip(label:Text('VWAP')),Chip(label:Text('RSI')),Chip(label:Text('MACD')),Chip(label:Text('OI'))]))]))));
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp,DeviceOrientation.portraitDown]);
  }

  Widget optionChain() => ListView(padding:const EdgeInsets.all(8),children:<Widget>[
    const Text('Option Chain • Indian Indices',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)), const SizedBox(height:6),
    Wrap(spacing:6,children:<Widget>[for(final s in const['NIFTY','BANKNIFTY','FINNIFTY','MIDCPNIFTY','SENSEX','BANKEX'])FilterChip(label:Text(s),selected:selectedOptionSymbol==s,onSelected:(_){setState(()=>selectedOptionSymbol=s);fetchOptionRows();})]),
    const SizedBox(height:8), if(liveOptionRows.isEmpty) infoCard('Option chain','Select an index and refresh to load live CE/PE.',Colors.orange),
    ..._optionChainCards(), FilledButton.icon(onPressed:fetchOptionRows,icon:const Icon(Icons.refresh),label:Text(angelDataBusy?'LOADING...':'REFRESH LIVE OPTION CHAIN')),
  ]);

  List<Widget> _optionChainCards() {
    final byStrike=<String,Map<String,dynamic>>{};
    for(final r in liveOptionRows.where((x)=>x is Map)){
      final key=(r['strike']??'-').toString();
      byStrike.putIfAbsent(key,()=>{}); byStrike[key]![r['type'].toString()]=r;
    }
    final keys=byStrike.keys.toList()..sort((a,b)=>(double.tryParse(a)??0).compareTo(double.tryParse(b)??0));
    return keys.map((strike){
      final ce=byStrike[strike]!['CE']; final pe=byStrike[strike]!['PE'];
      final atm=optionSpot!=null && (double.tryParse(strike)??-1)==(double.tryParse(optionSpot.toString())??-2);
      return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:<Widget>[
        Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:5),color:Theme.of(context).brightness==Brightness.dark?Colors.white.withOpacity(.08):Colors.black.withOpacity(.04),child:Center(child:Text(atm?'SPOT  '+strike+'  SPOT':strike,style:const TextStyle(fontWeight:FontWeight.bold)))),
        const SizedBox(height:6), Row(crossAxisAlignment:CrossAxisAlignment.start,children:<Widget>[
          Expanded(child:_optionCell(ce,'CE')), const SizedBox(width:8), Expanded(child:_optionCell(pe,'PE')),
        ]),
      ])));
    }).toList();
  }

  Widget _optionCell(dynamic r,String side) {
    if(r==null)return Card(child:Padding(padding:const EdgeInsets.all(8),child:Text(side+' —')));
    final ch=double.tryParse(r['priceChange']?.toString() ?? r['netChange']?.toString() ?? '0')??0;
    final oiCh=double.tryParse(r['oiChangePct']?.toString() ?? '0')??0;
    final color=ch>0?Colors.green:ch<0?Colors.red:Colors.blue;
    final oiArrow=oiCh>0?'↑':oiCh<0?'↓':'—'; final priceArrow=ch>0?'↑':ch<0?'↓':'—';
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:<Widget>[
      Text(side,style:TextStyle(fontWeight:FontWeight.bold,color:side=='CE'?Colors.green:Colors.red)),
      Text('LTP '+(r['ltp']??'-').toString()+'  OI '+(r['oi']??'-').toString()),
      Text('OI $oiArrow  PRICE $priceArrow',style:TextStyle(color:color,fontWeight:FontWeight.bold)),
      Text('Δ '+(r['delta']??'-').toString()+'  Γ '+(r['gamma']??'-').toString()),
      Text('Θ '+(r['theta']??'-').toString()+'  V '+(r['vega']??'-').toString()),
      Text('POP '+(r['pop']??'-').toString()),
    ]);
  }

  Widget newsPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('News',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Source','Server-side verified news adapter. Angel SmartAPI is not a news-feed API.',Colors.blue),
    infoCard('Status','No fabricated headlines.',Colors.orange),
  ]);

  Widget marketDetailsPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Market Details',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Indices','Angel One live market payload',Colors.blue),
    ...liveMarket.map(indexCard),
    infoCard('OI / breadth','Angel OI APIs are available through the backend.',Colors.green),
  ]);

  Widget signals() {
    final action = signal?['action']?.toString() ?? 'WAIT';
    final raw = signal?['reasons'];
    final reasons = raw is List ? raw.map((e) => e.toString()).join('\n') : 'No live signal reasons received.';
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      const Text('Signals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      infoCard(action.replaceAll('_',' '), reasons, Colors.blue),
      const SizedBox(height: 12),
      infoCard('Engine','Paper-signal engine. Live values appear only when the backend supplies them.',Colors.orange),
    ]);
  }

  Widget aiModelsPage() => FutureBuilder<http.Response>(
    future:http.get(backendUri('/v1/ai/status'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:8)),
    builder:(context,snapshot){
      if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
      try{final d=jsonDecode(snapshot.data!.body);final ps=d is Map&&d['providers'] is List?d['providers']:<dynamic>[];
        return ListView(padding:const EdgeInsets.all(12),children:<Widget>[
          const Text('AI Models',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),
          infoCard('AI orchestration','Six-provider evidence verification. Engine remains the final decision owner.',Colors.blue),
          ...ps.map((p)=>Card(child:ListTile(leading:Icon(p['configured']==true?Icons.check_circle:Icons.cloud_off,color:p['configured']==true?Colors.green:Colors.orange),title:Text((p['provider']??p['name']??'-').toString()),subtitle:Text((p['status']??'server key required').toString())))),
          infoCard('Configured',(d['configured']??0).toString()+' / '+(d['total']??6).toString(),Colors.green),
          infoCard('API keys','Read from the secure backend environment only. Never stored in APK.',Colors.orange),
        ]);
      }catch(_){return infoCard('AI status','Unable to read /v1/ai/status from backend.',Colors.orange);}
    });  Widget nseMcp() => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    const Text('NSE MCP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    infoCard('Official endpoint','https://mcp.nseindia.in/cmmkt/mcp',Colors.blue),
    infoCard('Connection',nseMcpStatus,nseMcpStatus == 'Connected' ? Colors.green : Colors.orange),
    infoCard('Internal Market MCP',backendUrl + '/mcp',Colors.blue),
    infoCard('Strategy Evidence MCP',backendUrl + '/mcp-strategy',Colors.blue),
    infoCard('CSV route',backendUrl + '/v1/nse/option-chain.csv?symbol=NIFTY',Colors.blue),
    const Text('MCP access is server-side; APK never stores NSE/Angel credentials.', style: TextStyle(color: Colors.grey)),
  ]);

  Widget angelApi() => AngelApiForm(
    backendUrl: backendUrl,
    apiToken: apiToken,
    connection: connection,
    status: angelLoginStatus,
    onConnected: fetchTerminal,
    onStatus: (v) => setState(() => angelLoginStatus = v),
  );

  Widget settingsPage() => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    infoCard('Backend provider',backendProvider(),backendProvider() == 'Railway' ? Colors.green : Colors.blue),
    infoCard('Backend URL',backendUrl,Colors.blue),
    infoCard('MCP servers','Market MCP + Strategy Evidence MCP + official NSE MCP client',Colors.blue),
    infoCard('Mode','Paper signals only',Colors.orange),
    infoCard('Timeframes','1m 2m 3m 5m 10m 15m 30m 1h 2h 4h 1D',Colors.blue),
    infoCard('Indicators','8 EMA / 13 EMA',Colors.blue),
    FilledButton.icon(onPressed: openSettings, icon: const Icon(Icons.dns), label: const Text('Edit server connection')),
  ]);

  Widget morePage() => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    const Text('More', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    infoCard('Order mode','No order placement. Paper signals only.',Colors.orange),
    infoCard('Security','Keep Angel credentials server-side and never commit secrets.',Colors.blue),
    infoCard('Navigation',screens.join(', '),Colors.blue),
  ]);

  Widget dataPage(String title) => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    Row(children: <Widget>[Icon(icons[selected], size: 30), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]),
    const SizedBox(height: 14),
    infoCard('Live data status', connection == 'Connected' ? 'Backend connected. This screen will use its corresponding live payload when available.' : 'Backend not connected. No fabricated market values are shown.', connection == 'Connected' ? Colors.green : Colors.orange),
    const SizedBox(height: 10),
    infoCard('Data source', title == 'NSE MCP' ? 'NSE MCP integration is configured by the backend.' : 'Corresponding API/data adapter is handled by the backend.', Colors.blue),
  ]);

  String backendProvider() {
    final host = Uri.tryParse(cleanUrl(backendUrl))?.host.toLowerCase() ?? '';
    if (host == 'railway.app' || host.endsWith('.railway.app')) return 'Railway';
    if (host.isEmpty) return 'Railway URL not configured';
    return 'Invalid backend';
  }

  String cleanUrl(String s) {
    s = s.trim();
    if (s.isEmpty) return defaultBackendUrl;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://' + s;
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Uri backendUri(String path) {
    final base = cleanUrl(backendUrl);
    if (base.isEmpty) {
      throw const FormatException(
        'Railway backend URL is not configured. Build the APK with RAILWAY_BACKEND_URL.',
      );
    }
    final uri = Uri.tryParse(base + path);
    final host = uri?.host.toLowerCase() ?? '';
    final isRailwayHost = host == 'railway.app' || host.endsWith('.railway.app');
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https' || !isRailwayHost) {
      throw const FormatException('Only the configured HTTPS Railway backend is allowed.');
    }
    return uri;
  }

  Future<void> openSettings() async {
    final u = TextEditingController(text: backendUrl);
    final k = TextEditingController(text: apiToken);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: u,
              decoration: const InputDecoration(labelText: 'Backend URL'),
            ),
            TextField(
              controller: k,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API token'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              setState(() {
                backendUrl = cleanUrl(u.text);
                apiToken = k.text.trim();
              });
              alertService?.baseUrl = backendUrl;
              alertService?.apiToken = apiToken;
              Navigator.pop(d);
              fetchTerminal();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    u.dispose();
    k.dispose();
  }

  Widget infoCard(String title,String value,Color color) => Card(child: ListTile(
    leading: Icon(Icons.circle,color:color,size:13), title: Text(title), subtitle: Text(value),
  ));


  Widget row(String label,dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical:4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
      Text(label), Flexible(child:Text((value ?? '-').toString(), textAlign:TextAlign.right)),
    ]),
  );
}



// APK build fix: settings dialog and widget-scoped connection UI are syntactically closed.
class CandlePainter extends CustomPainter {
  final List<dynamic> rows;
  CandlePainter(this.rows);
  @override void paint(Canvas canvas,Size size){
    final vals=rows.where((r)=>r is List && r.length>=5).toList();
    if(vals.isEmpty)return;
    double minV=double.infinity,maxV=-double.infinity;
    for(final r in vals){minV=math.min(minV,(r[3] as num).toDouble());maxV=math.max(maxV,(r[2] as num).toDouble());}
    final range=math.max(maxV-minV,0.01); final width=size.width/vals.length;
    final wick=Paint()..strokeWidth=1.2; final body=Paint()..strokeWidth=5;
    for(int i=0;i<vals.length;i++){
      final r=vals[i]; final o=(r[1] as num).toDouble(),h=(r[2] as num).toDouble(),l=(r[3] as num).toDouble(),cl=(r[4] as num).toDouble();
      double y(double v)=>size.height-(v-minV)/range*size.height;
      final x=i*width+width/2; final up=cl>=o; wick.color=up?Colors.green:Colors.red; body.color=wick.color;
      canvas.drawLine(Offset(x,y(h)),Offset(x,y(l)),wick);
      canvas.drawLine(Offset(x,y(o)),Offset(x,y(cl)),body);
    }
  }
  @override bool shouldRepaint(covariant CandlePainter old)=>old.rows!=rows;
}
class AngelApiForm extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  final String connection;
  final String status;
  final VoidCallback onConnected;
  final ValueChanged<String> onStatus;

  const AngelApiForm({
    super.key,
    required this.backendUrl,
    required this.apiToken,
    required this.connection,
    required this.status,
    required this.onConnected,
    required this.onStatus,
  });

  @override
  State<AngelApiForm> createState() => _AngelApiFormState();
}

class _AngelApiFormState extends State<AngelApiForm> {
  final clientId = TextEditingController();
  final mpin = TextEditingController();
  final totp = TextEditingController();
  final apiKey = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    clientId.dispose();
    mpin.dispose();
    totp.dispose();
    apiKey.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final c = clientId.text.trim();
    final p = mpin.text.trim();
    final t = totp.text.trim();
    final k = apiKey.text.trim();

    if (c.isEmpty || p.isEmpty || k.isEmpty || !RegExp(r'^\d{6}$').hasMatch(t)) {
      widget.onStatus('Client ID, MPIN, API key and current 6-digit TOTP are required.');
      return;
    }

    setState(() => busy = true);
    widget.onStatus('Connecting to Angel One through secure backend...');

    try {
      final base = widget.backendUrl.trim();
      if (base.isEmpty) {
        widget.onStatus('Railway backend URL is not configured in this APK. Set GitHub variable RAILWAY_BACKEND_URL and rebuild.');
        return;
      }
      final normalized = base.startsWith('http://') || base.startsWith('https://')
          ? base
          : 'https://' + base;
      final normalizedUri = Uri.tryParse(normalized);
      final host = normalizedUri?.host.toLowerCase() ?? '';
      final isRailwayHost = host == 'railway.app' || host.endsWith('.railway.app');
      if (normalizedUri == null || normalizedUri.host.isEmpty || normalizedUri.scheme != 'https' || !isRailwayHost) {
        widget.onStatus('Invalid backend URL. This APK accepts only the configured HTTPS Railway backend.');
        return;
      }
      final loginUri = normalizedUri.replace(path: '/v1/angel/login');
      if (loginUri.host.isEmpty) {
        widget.onStatus('Invalid backend URL. Enter a valid HTTPS backend host in Settings.');
        return;
      }

      final response = await http.post(
        loginUri,
        headers: <String,String>{
          'Content-Type': 'application/json',
          'x-token': widget.apiToken,
        },
        body: jsonEncode(<String,String>{
          'clientId': c,
          'pin': p,
          'totp': t,
          'apiKey': k,
        }),
      ).timeout(const Duration(seconds: 60));

      dynamic decoded;
      try { decoded = jsonDecode(response.body); } catch (_) { decoded = null; }

      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['connected'] == true) {
        widget.onStatus('CONNECTED • Angel One SmartAPI');
        widget.onConnected();
      } else {
        final detail = decoded is Map ? decoded['detail']?.toString() : null;
        widget.onStatus(detail == null || detail.isEmpty
            ? 'Login failed. Check Client ID, MPIN, TOTP, API key and backend.'
            : detail);
      }
    } catch (e) {
      widget.onStatus('Backend connection failed: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration field(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Angel API', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Secure SmartAPI connection'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text('LIVE DATA ONLY'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const <Widget>[
                  Text('BROKER CONNECTION', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('API'),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: clientId,
                autocorrect: false,
                decoration: field('CLIENT ID', 'Enter Angel One Client ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mpin,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: field('MPIN', 'Enter 4-digit MPIN'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: field('CURRENT TOTP', 'Enter current 6-digit TOTP'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKey,
                obscureText: true,
                autocorrect: false,
                decoration: field('SMARTAPI API KEY', 'Enter SmartAPI API key'),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: const <Widget>[
                    Expanded(child: Text('API key is sent only to the configured HTTPS backend during secure login.')),
                    SizedBox(width: 10),
                    Text('MASKED', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : login,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(busy ? 'CONNECTING...' : 'SECURE LOGIN'),
                  ),
                ),
              ),
              if (widget.status.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(widget.status),
              ],
              const SizedBox(height: 8),
              Text(
                'Frontend → Secure backend → Angel One SmartAPI',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          title: const Text('BACKEND CONNECTION'),
          subtitle: Text(widget.backendUrl),
          trailing: Icon(
            widget.connection == 'Connected' ? Icons.check_circle : Icons.cloud_off,
            color: widget.connection == 'Connected' ? Colors.green : Colors.orange,
          ),
        ),
      ),
    ],
  );
}
