import 'dart:async';
import 'dart:io';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'market_features.dart';

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
    'Dashboard','Indian Indices','Commodity','Signals','OI Lab','Watchlist','Search',
    'Charts','Option Chain','News','Market Details','Angel API','NSE',
    'NSE MCP','Data','Instruments','Settings','More'
  ];
  static const icons = <IconData>[
    Icons.dashboard, Icons.show_chart, Icons.precision_manufacturing,
    Icons.notifications_active, Icons.analytics, Icons.star, Icons.search,
    Icons.candlestick_chart, Icons.table_chart, Icons.article, Icons.info_outline,
    Icons.key, Icons.language, Icons.hub, Icons.storage, Icons.list_alt,
    Icons.tune, Icons.more_horiz
  ];
  int selected = 0;
  String backendUrl = 'https://vandana1-angel-api.onrender.com';
  String apiToken = 'change-me';
  String connection = 'Connecting...';
  String nseMcpStatus = 'Not checked';
  String angelLoginStatus = '';
  String csvStatus = '';
  Map<String,dynamic>? signal;
  List<dynamic> liveMarket = <dynamic>[];
  List<dynamic> liveCandles = <dynamic>[];
  List<dynamic> liveOptionRows = <dynamic>[];
  List<dynamic> liveOIBuild = <dynamic>[];
  String selectedChartToken = '99926000';
  String selectedChartExchange = 'NSE';
  String selectedInterval = 'FIVE_MINUTE';
  static const Map<String,String> intervalMap = <String,String>{'1m':'ONE_MINUTE','2m':'TWO_MINUTE','3m':'THREE_MINUTE','5m':'FIVE_MINUTE','10m':'TEN_MINUTE','15m':'FIFTEEN_MINUTE','30m':'THIRTY_MINUTE','1H':'ONE_HOUR','1D':'ONE_DAY'};
  bool angelDataBusy = false;
  bool lightMode = false;
  String marketFilter = 'Indices';
  String optionFilter = 'NIFTY';
  String commodityQuery = '';
  final Set<String> selectedIndicators = <String>{};
  String selectedDrawingTool = '';
  final List<Offset> drawingPoints = <Offset>[];
  String selectedMarketDetail = 'NIFTY';
  String aiActiveTab = '';
  final List<String> aiMemory = <String>[];
  String aiActiveTab = '';
  final List<String> aiMemory = <String>[];
  Map<String,dynamic>? terminalData;
  Timer? timer;

  @override void initState() {
    super.initState();
    fetchTerminal();
    _loadAiMemory();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchTerminal());
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> fetchTerminal() async {
    try {
      final response = await http.get(
        Uri.parse(backendUrl + '/v1/terminal'),
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
    data: lightMode ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true),
    child: WillPopScope(
      onWillPop: () async { if (selected != 0) { setState(() => selected = 0); return false; } return true; },
      child: Scaffold(
    appBar: AppBar(
      leading: selected == 0 ? null : IconButton(onPressed: () => setState(() => selected = 0), icon: const Icon(Icons.arrow_back)),
      title: Text(screens[selected]),
      actions: <Widget>[
        IconButton(onPressed: fetchTerminal, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => setState(() => lightMode = !lightMode), icon: Icon(lightMode ? Icons.dark_mode : Icons.light_mode), tooltip: lightMode ? 'Dark mode' : 'Light mode'),
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
            Text('18-screen live market terminal'),
          ])),
          for (int i=0; i<screens.length; i++) if (i != 6) ListTile(
            leading: Icon(icons[i]),
            title: Text(screens[i]),
            selected: selected == i,
            onTap: () { Navigator.pop(context); setState(() => selected = i); },
          ),
        ],
      )),
    ),
    body: buildScreen(),
      )));

  Widget buildScreen() {
    if (selected == 0) return dashboard();
    if (selected == 1) return marketPage();
    if (selected == 2) return commodityPage();
    if (selected == 3) return signalsPage();
    if (selected == 4) return oiLabPage();
    if (selected == 5) return watchlistPage();
    if (selected == 6) return searchPage();
    if (selected == 7) return chartsPage();
    if (selected == 8) return optionChain();
    if (selected == 9) return newsPage();
    if (selected == 10) return marketDetailsPage();
    if (selected == 11) return angelApi();
    if (selected == 13) return nseMcpPage();
    if (selected == 16) return settingsPage();
    if (selected == 17) return morePage();
    return dataPage(screens[selected]);
  }

  DateTime get _nowIst => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  bool get _marketClosed => isIndianMarketClosed(_nowIst);
  Color _trendColor(String s) => s=='UP'?Colors.green:s=='DOWN'?Colors.red:s=='CLOSE'?Colors.blue:Colors.grey;
  String _trendLabel(Map<String,dynamic> q) {
    final s=trendState(q,marketClosed:_marketClosed);
    return s=='UP'?'UP TREND':s=='DOWN'?'DOWN TREND':s=='CLOSE'?'CLOSE':'WAIT';
  }
  Future<void> _loadAiMemory() async {
    try {
      final d=await getApplicationDocumentsDirectory();
      final f=File(d.path+'/ai_memory/market_memory.json');
      if(await f.exists()){final x=jsonDecode(await f.readAsString());if(x is List&&mounted)setState(()=>aiMemory.addAll(x.map((e)=>e.toString())));}
    } catch (_) {}
  }
  Future<void> _saveAiMemory(String item) async {
    if(item.trim().isEmpty)return;
    if(!aiMemory.contains(item))aiMemory.add(item);
    try{
      final d=await getApplicationDocumentsDirectory();
      final folder=Directory(d.path+'/ai_memory');
      if(!await folder.exists())await folder.create(recursive:true);
      await File(folder.path+'/market_memory.json').writeAsString(jsonEncode(aiMemory));
    }catch(_){}
    if(mounted)setState((){});
  }
  Future<void> _activateAi(String tab) async {
    await _saveAiMemory(DateTime.now().toIso8601String()+' • '+tab+' • market snapshot selected');
    if(mounted)setState(()=>aiActiveTab=tab);
  }

  DateTime get _nowIst=>DateTime.now().toUtc().add(const Duration(hours:5,minutes:30));
  bool get _marketClosed=>isIndianMarketClosed(_nowIst);
  Color _trendColor(String s)=>s=='UP'?Colors.green:s=='DOWN'?Colors.red:s=='CLOSE'?Colors.blue:Colors.grey;
  String _trendLabel(Map<String,dynamic> q){final s=trendState(q,marketClosed:_marketClosed);return s=='UP'?'UP TREND':s=='DOWN'?'DOWN TREND':s=='CLOSE'?'CLOSE':'WAIT';}
  Future<void> _loadAiMemory() async{try{final d=await getApplicationDocumentsDirectory();final f=File(d.path+'/ai_memory/market_memory.json');if(await f.exists()){final x=jsonDecode(await f.readAsString());if(x is List&&mounted)setState(()=>aiMemory.addAll(x.map((e)=>e.toString())));}}catch(_){}}
  Future<void> _saveAiMemory(String item) async{if(item.trim().isEmpty)return;if(!aiMemory.contains(item))aiMemory.add(item);try{final d=await getApplicationDocumentsDirectory();final folder=Directory(d.path+'/ai_memory');if(!await folder.exists())await folder.create(recursive:true);await File(folder.path+'/market_memory.json').writeAsString(jsonEncode(aiMemory));}catch(_){}if(mounted)setState((){});}
  Future<void> _activateAi(String tab) async{await _saveAiMemory(DateTime.now().toIso8601String()+' • '+tab+' • market snapshot selected');if(mounted)setState(()=>aiActiveTab=tab);}
  Widget _aiLayer(String title,String text,Color color)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:color.withOpacity(.16),child:Icon(Icons.smart_toy,color:color)),title:Text(title,style:TextStyle(color:color,fontWeight:FontWeight.bold)),subtitle:Text(text)));
  Widget dashboard() {
    final q=liveMarket.isNotEmpty&&liveMarket.first is Map?Map<String,dynamic>.from(liveMarket.first):<String,dynamic>{};
    final trend=q.isEmpty?'UNKNOWN':trendState(q,marketClosed:_marketClosed);
    final c=_trendColor(trend);
    final setups=terminalData?['equity_setups'] is List?terminalData!['equity_setups'] as List:<dynamic>[];
    return ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:[
      Card(child:Container(
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),border:Border.all(color:c.withOpacity(.7),width:2)),
        padding:const EdgeInsets.all(14),
        child:Row(children:[
          CircleAvatar(backgroundColor:c.withOpacity(.15),child:Icon(Icons.candlestick_chart,color:c)),
          const SizedBox(width:10),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('NSE Algo Signal',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
            Text('Live market trend dashboard',style:TextStyle(fontSize:12)),
          ])),
          Text(_trendLabel(q),style:TextStyle(color:c,fontWeight:FontWeight.bold)),
        ]),
      )),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        _metricTile('Connection',connection,Icons.link),
        _metricTile('Indices',liveMarket.isEmpty?'—':liveMarket.length.toString(),Icons.show_chart),
        _metricTile('Candles',liveCandles.isEmpty?'—':liveCandles.length.toString(),Icons.candlestick_chart),
        _metricTile('Option rows',liveOptionRows.isEmpty?'—':liveOptionRows.length.toString(),Icons.table_chart),
      ]),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('EQUITY INTRADAY • CE / PE • 3 SETUPS',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:4),const Text('Three minimum setup slots. Only live qualifying backend setups are displayed.',style:TextStyle(fontSize:11)),
        ...List<Widget>.generate(3,(i){
          final x=i<setups.length&&setups[i] is Map?Map<String,dynamic>.from(setups[i]):<String,dynamic>{};
          return Card(child:ListTile(
            leading:CircleAvatar(child:Text((i+1).toString())),
            title:Text(x.isEmpty?'SETUP '+(i+1).toString()+' • WAIT':(x['symbol']??'Equity').toString()),
            subtitle:Text(x.isEmpty?'No fabricated entry; waiting for live CE/PE qualification.':(x['side']??'CE/PE').toString()+' • Entry '+(x['entry']??'—').toString()+' • SL '+(x['sl']??'—').toString()+' • Target '+(x['target']??'—').toString()),
            trailing:Text(x.isEmpty?'—':'LIVE'),
          ));
        }),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('CURRENT SIGNAL',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:4),Text((signal?['action']??'WAIT').toString().replaceAll('_',' '),style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        if(signal!=null)...[row('Symbol',signal!['symbol']),row('Spot',signal!['spot']),row('LTP',signal!['ltp'])] else const Text('No live signal payload received.'),
      ]))),
      const SizedBox(height:10),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:7,runSpacing:7,children:[
        ActionChip(label:const Text('Indian Indices'),onPressed:()=>setState(()=>selected=1)),
        ActionChip(label:const Text('Option Chain'),onPressed:()=>setState(()=>selected=8)),
        ActionChip(label:const Text('Watchlist'),onPressed:()=>setState(()=>selected=5)),
        ActionChip(label:const Text('Market AI'),onPressed:()=>setState(()=>selected=10)),
      ]))),
    ]);
  }

  Widget _metricTile(String title,String value,IconData icon)=>SizedBox(width:MediaQuery.of(context).size.width>520?180:(MediaQuery.of(context).size.width-40)/2,child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Icon(icon,size:20),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:11)),const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold),overflow:TextOverflow.ellipsis)]))]))));



  Future<void> fetchAngelMarket() async {
    try {
      final r=await http.get(Uri.parse(backendUrl+'/v1/angel/market'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:8));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['data'] is Map ? (d['data']['fetched'] ?? <dynamic>[]) : <dynamic>[];
        if(mounted) setState(()=>liveMarket=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {}
  }

  Future<void> openNamedIndex(String name) async {
    dynamic hit;
    for(final q in liveMarket){
      final s=(q['tradingSymbol']??q['tradingsymbol']??q['symbol']??q['indexName']??'').toString();
      if(indexMatches(name,s)){hit=q;break;}
    }
    if(hit!=null){await openQuoteChart(hit);return;}
    await fetchAngelMarket();
    for(final q in liveMarket){
      final s=(q['tradingSymbol']??q['tradingsymbol']??q['symbol']??q['indexName']??'').toString();
      if(indexMatches(name,s)){await openQuoteChart(q);return;}
    }
  }

  Future<void> openQuoteChart(dynamic q) async {
    final token=(q['symbolToken']??q['symboltoken']??q['token']??'').toString();
    if(token.isEmpty)return;
    selectedChartToken=token;
    selectedChartExchange=(q['exchange']??'NSE').toString();
    setState(()=>selected=7);
    await fetchCandles();
  }

  Future<void> searchAndOpenCommodity(String query) async {
    try {
      final r=await http.get(Uri.parse(backendUrl+'/v1/angel/search?exchange=MCX&q='+Uri.encodeQueryComponent(query)),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:10));
      if(r.statusCode==200&&mounted){
        final d=jsonDecode(r.body);
        setState(()=>terminalData={'commoditySearch':d});
        final rows=d is Map&&d['data'] is List?d['data']:<dynamic>[];
        if(rows.isNotEmpty) await openSearchResult(rows.first,'MCX');
      }
    } catch (_) {}
  }

  Future<void> openSearchResult(dynamic x,String exchange) async {
    final token=(x['symboltoken']??x['symbolToken']??x['token']??'').toString();
    if(token.isEmpty)return;
    selectedChartToken=token; selectedChartExchange=exchange;
    setState(()=>selected=7);
    await fetchCandles();
  }

  Future<void> fetchCandles() async {
    setState(()=>angelDataBusy=true);
    try {
      final u=backendUrl+'/v1/angel/candles?exchange='+selectedChartExchange+'&token='+selectedChartToken+'&interval='+selectedInterval+'&days=1';
      final r=await http.get(Uri.parse(u),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:12));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['data'] is List ? d['data'] : <dynamic>[];
        if(mounted) setState(()=>liveCandles=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {} finally { if(mounted) setState(()=>angelDataBusy=false); }
  }

  Future<void> fetchOptionRows() async {
    setState(()=>angelDataBusy=true);
    try {
      final r=await http.get(Uri.parse(backendUrl+'/v1/angel/option-chain?symbol='+Uri.encodeQueryComponent(optionFilter)+'&count='+optionChainCount.toString()),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:15));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['rows'] is List ? d['rows'] : <dynamic>[];
        if(mounted) setState(()=>liveOptionRows=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {} finally { if(mounted) setState(()=>angelDataBusy=false); }
  }

  Future<void> fetchOIBuild() async {
    setState(()=>angelDataBusy=true);
    try {
      final r=await http.get(Uri.parse(backendUrl+'/v1/angel/oi-buildup?datatype=Long%20Built%20Up&expirytype=NEAR'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:12));
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

  Widget marketPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:<Widget>[
    const Text('Indian Indices',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:4),const Text('NSE / BSE • live price, liquidity and index chart access.',style:TextStyle(fontSize:12)),
    const SizedBox(height:10),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final f in const ['Indices','NSE','BSE'])Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(f),selected:marketFilter==f,onSelected:(_)=>setState(()=>marketFilter=f))),
    ])),
    const SizedBox(height:8),
    Card(child:Padding(padding:const EdgeInsets.all(10),child:Wrap(spacing:6,runSpacing:6,children:[
      for(final x in const ['NIFTY 50','BANK NIFTY','FINNIFTY','MIDCAP SELECT','SENSEX','BANKEX'])ActionChip(label:Text(x),onPressed:()=>openNamedIndex(x)),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('LIQUIDITY',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:4),const Text('Only real volume / buy+sell quantity from the live payload is plotted.',style:TextStyle(fontSize:11)),
      const SizedBox(height:8),SizedBox(height:170,child:CustomPaint(painter:LiquidityPainter(liveMarket))),
    ]))),
    ...liveMarket.where((q){
      final ex=(q['exchange']??q['exchangeType']??'').toString().toUpperCase();
      return marketFilter=='Indices'||ex==marketFilter;
    }).map((q)=>Card(child:ListTile(
      leading:const Icon(Icons.show_chart),
      title:Text((q['tradingSymbol']??q['tradingsymbol']??q['symbol']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('LTP '+formatMarketPrice(q['ltp'])+' • '+(q['exchange']??'').toString()),
      trailing:Text((q['percentChange']??q['netChange']??'—').toString()),
      onTap:()=>openQuoteChart(q),
    ))),
    if(liveMarket.isEmpty)infoCard('Live indices','Connect Angel One to load current prices and liquidity fields.',Colors.orange),
    FilledButton.icon(onPressed:fetchAngelMarket,icon:const Icon(Icons.refresh),label:const Text('REFRESH INDIAN INDICES')),
  ]);

  Widget commodityPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:[
    const Text('Commodity',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:4),const Text('MCX live contract search.',style:TextStyle(fontSize:12)),
    const SizedBox(height:10),
    TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Search commodity',hintText:'CRUDEOIL, CRUDEOILM, GOLD, SILVER, NATURALGAS',border:OutlineInputBorder()),onChanged:(v)=>setState(()=>commodityQuery=v)),
    const SizedBox(height:8),
    Wrap(spacing:6,runSpacing:6,children:[
      for(final x in const ['CRUDEOIL','CRUDEOILM','GOLD','SILVER','NATURALGAS'])
        if(commodityQuery.isEmpty||x.contains(commodityQuery.toUpperCase()))
          ActionChip(label:Text(x),onPressed:()=>searchAndOpenCommodity(x)),
    ]),
    const SizedBox(height:8),
    infoCard('Crude Oil Mini','CRUDEOILM added as a separate MCX contract search.',Colors.blue),
    infoCard('Auto-select','Select a contract → Angel search resolves the instrument → chart opens.',Colors.blue),
    if(terminalData?['commoditySearch'] is Map) ...[((terminalData!['commoditySearch']['data'] is List?terminalData!['commoditySearch']['data']:<dynamic>[]).map((x)=>Card(child:ListTile(title:Text((x['tradingsymbol']??'-').toString()),subtitle:Text('MCX • '+(x['symboltoken']??'-').toString()),onTap:()=>openSearchResult(x,'MCX')))))],
  ]);

  Widget oiLabPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('OI Lab',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Live source','Angel One SmartAPI OI Buildup',Colors.blue),
    ...liveOIBuild.map((x)=>Card(child:ListTile(
      title:Text((x['tradingSymbol']??'-').toString()),
      subtitle:Text('LTP '+(x['ltp']??'-').toString()+' • OI '+(x['opnInterest']??'-').toString()),
      trailing:Text((x['netChangeOpnInterest']??'-').toString()),
    ))),
    if(liveOIBuild.isEmpty) infoCard('OI buildup','Press refresh to fetch Long Built Up from Angel One.',Colors.orange),
    FilledButton.icon(onPressed:fetchOIBuild,icon:const Icon(Icons.refresh),label:const Text('REFRESH OI BUILDUP')),
  ]);

  Widget watchlistPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:[
    const Text('Watchlist',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),infoCard('Live source','Angel One SmartAPI • index/equity universe',Colors.blue),
    const Text('EQUITY / INDEX',style:TextStyle(fontWeight:FontWeight.bold)),
    ...liveMarket.map((q){
      final m=Map<String,dynamic>.from(q as Map);
      final st=trendState(m,marketClosed:_marketClosed),c=_trendColor(st);
      return GestureDetector(onDoubleTap:()=>_activateAi((m['tradingSymbol']??m['tradingsymbol']??m['symbol']??'Instrument').toString()),
        child:Card(child:ListTile(
          leading:CircleAvatar(backgroundColor:c.withOpacity(.14),child:Icon(Icons.show_chart,color:c)),
          title:Text((m['tradingSymbol']??m['tradingsymbol']??m['symbol']??'Instrument').toString()),
          subtitle:Text(_trendLabel(m)+' • LTP '+formatMarketPrice(m['ltp'])),
          trailing:Text((m['percentChange']??m['netChange']??'—').toString(),style:TextStyle(color:c,fontWeight:FontWeight.bold)),
        )));
    }),
    if(liveMarket.isEmpty)infoCard('Watchlist','Connect Angel One to populate live instruments.',Colors.orange),
    const SizedBox(height:12),const Text('PRIORITY STRIKE TABLE',style:TextStyle(fontWeight:FontWeight.bold)),
    if(liveOptionRows.isEmpty)infoCard('Strike table','Load Option Chain. Priority appears only when the live row supplies a score.',Colors.orange),
    if(liveOptionRows.isNotEmpty)Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      columns:const [DataColumn(label:Text('P')),DataColumn(label:Text('TYPE')),DataColumn(label:Text('STRIKE')),DataColumn(label:Text('LTP')),DataColumn(label:Text('OI')),DataColumn(label:Text('Δ Θ Γ ν POP'))],
      rows:[for(final r in liveOptionRows.take(25))DataRow(cells:[
        DataCell(Text(optionPriority(Map<String,dynamic>.from(r))?.toString()??'—')),
        DataCell(Text((r['type']??'—').toString())),
        DataCell(Text((r['strike']??'—').toString())),
        DataCell(Text((r['ltp']??'—').toString())),
        DataCell(Text((r['oi']??'—').toString())),
        DataCell(Text((r['delta']??'—').toString()+' '+(r['theta']??'—').toString()+' '+(r['gamma']??'—').toString()+' '+(r['vega']??'—').toString()+' '+(r['pop']??'—').toString())),
      ])],
    ))),
    const SizedBox(height:12),const Text('CE / PE • INDICES WITH LIVE QUALIFYING ENTRY',style:TextStyle(fontWeight:FontWeight.bold)),
    if(signal!=null&&(signal!['action']?.toString().toUpperCase().contains('CALL')==true||signal!['action']?.toString().toUpperCase().contains('PUT')==true))
      Card(child:ListTile(
        leading:const Icon(Icons.bolt,color:Colors.green),
        title:Text((signal!['symbol']??'Index').toString()),
        subtitle:Text((signal!['action']??'—').toString()+' • Entry '+(signal!['entry']??signal!['ltp']??'—').toString()+' • SL '+(signal!['sl']??signal!['stopLoss']??'—').toString()+' • Target '+(signal!['target']??'—').toString()),
        trailing:const Text('LIVE'),
      ))
    else infoCard('No qualifying entry','No live index CE/PE setup is currently supplied.',Colors.orange),
  ]);

  Widget searchPage() => const SizedBox.shrink();

  Widget chartsPage() => ListView(padding:const EdgeInsets.fromLTRB(8,8,8,20),children:<Widget>[
    Row(children:[const Expanded(child:Text('Chart',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold))),IconButton(onPressed:fetchCandles,icon:const Icon(Icons.refresh))]),
    const SizedBox(height:6),
    Row(children:[
      Expanded(child:OutlinedButton.icon(onPressed:()=>showModalBottomSheet<void>(context:context,builder:(_)=>_choiceSheet('TIME',intervalMap.keys.toList(),(x){setState(()=>selectedInterval=intervalMap[x]!);fetchCandles();})),icon:const Icon(Icons.schedule),label:const Text('TIME'))),
      const SizedBox(width:8),
      Expanded(child:OutlinedButton.icon(onPressed:()=>showModalBottomSheet<void>(context:context,builder:(_)=>_choiceSheet('INDICATORS',const ['EMA 8','EMA 13','SMA 20','SMA 50','VWAP','RSI 14','MACD','Bollinger','Volume','ATR 14'],(x){setState(()=>selectedIndicators.contains(x)?selectedIndicators.remove(x):selectedIndicators.add(x));})),icon:const Icon(Icons.tune),label:const Text('INDICATORS'))),
    ]),
    const SizedBox(height:6),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final x in const ['Fibonacci','Horizontal','Vertical','Long Position','Short Position'])Padding(padding:const EdgeInsets.only(right:5),child:FilterChip(label:Text(x),selected:selectedDrawingTool==x,onSelected:(_){setState(()=>selectedDrawingTool=selectedDrawingTool==x?'':x);})),
    ])),
    const SizedBox(height:6),
    Card(child:Padding(padding:const EdgeInsets.all(4),child:SizedBox(height:440,child:liveCandles.isEmpty?const Center(child:Text('No live candle payload yet.')):GestureDetector(
      onTapDown:(d){
        if(selectedDrawingTool.isEmpty)return;
        setState((){
          if(selectedDrawingTool=='Horizontal'||selectedDrawingTool=='Vertical'){drawingPoints..clear()..add(d.localPosition);}
          else if(drawingPoints.length>=2){drawingPoints..clear()..add(d.localPosition);}
          else{drawingPoints.add(d.localPosition);}
        });
      },
      child:Stack(children:[
        Positioned.fill(child:CustomPaint(painter:CandlePainter(liveCandles,Set<String>.from(selectedIndicators)))),
        Positioned.fill(child:CustomPaint(painter:DrawingPainter(selectedDrawingTool,drawingPoints))),
      ]),
    )))),
    const SizedBox(height:6),
    Text('TIME: '+(intervalMap.entries.firstWhere((e)=>e.value==selectedInterval,orElse:()=>const MapEntry('5m','FIVE_MINUTE')).key)+' • Indicators: '+selectedIndicators.length.toString(),style:const TextStyle(fontSize:11)),
    if(selectedDrawingTool.isNotEmpty)OutlinedButton.icon(onPressed:()=>setState(()=>drawingPoints.clear()),icon:const Icon(Icons.clear),label:const Text('CLEAR DRAWING')),
  ]);

  Widget _choiceSheet(String title,List<String> items,void Function(String) onTap) => SafeArea(child:Padding(
    padding:const EdgeInsets.all(16),child:Wrap(spacing:6,runSpacing:6,children:[
      for(final x in items) FilterChip(label:Text(x),selected:title=='INDICATORS'?selectedIndicators.contains(x):intervalMap[x]==selectedInterval,onSelected:(_){onTap(x);Navigator.pop(context);}),
    ]),
  ));

  Widget optionChain() => ListView(padding:const EdgeInsets.fromLTRB(8,8,8,20),children:[
    Row(children:[const Expanded(child:Text('Option Chain',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold))),IconButton(onPressed:fetchOptionRows,icon:const Icon(Icons.refresh)),IconButton(onPressed:connection=='Connected'?downloadNseCsv:null,icon:const Icon(Icons.download))]),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[for(final f in const ['NIFTY','BANKNIFTY','FINNIFTY','MIDCPNIFTY','SENSEX','BANKEX'])Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(f),selected:optionFilter==f,onSelected:(_){setState(()=>optionFilter=f);fetchOptionRows();}))])),
    const SizedBox(height:8),const Text('CALL • STRIKE • PUT • OI FLOW • GREEKS / POP',style:TextStyle(fontWeight:FontWeight.bold)),
    if(liveOptionRows.isEmpty)infoCard('Live option chain','Load '+optionFilter+'. No strike/OI/Greek value is fabricated.',Colors.orange),
    if(liveOptionRows.isNotEmpty)Card(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
      headingRowColor:WidgetStateProperty.all(Colors.black26),
      columns:const [DataColumn(label:Text('CALL LTP')),DataColumn(label:Text('CALL OI')),DataColumn(label:Text('STRIKE')),DataColumn(label:Text('PUT OI')),DataColumn(label:Text('PUT LTP')),DataColumn(label:Text('Δ')),DataColumn(label:Text('Θ')),DataColumn(label:Text('Γ')),DataColumn(label:Text('VEGA')),DataColumn(label:Text('POP')),DataColumn(label:Text('FLOW'))],
      rows:[for(final strike in <dynamic>{for(final r in liveOptionRows)r['strike']}.toList()..sort((a,b)=>(a as num).compareTo(b as num)))DataRow(cells:[
        DataCell(Text(_chainValue(strike,'CE','ltp'),style:const TextStyle(color:Colors.green))),
        DataCell(_coloredOiCell(strike,'CE')),
        DataCell(Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(borderRadius:BorderRadius.circular(6),color:Colors.blue.withOpacity(.16)),child:Text(strike.toString(),style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.blue)))),
        DataCell(_coloredOiCell(strike,'PE')),
        DataCell(Text(_chainValue(strike,'PE','ltp'),style:const TextStyle(color:Colors.red))),
        DataCell(Text(_chainGreek(strike,'delta'))),DataCell(Text(_chainGreek(strike,'theta'))),DataCell(Text(_chainGreek(strike,'gamma'))),DataCell(Text(_chainGreek(strike,'vega'))),DataCell(Text(_chainGreek(strike,'pop'))),DataCell(Text(_chainFlow(strike))),
      ])],
    ))),
    FilledButton.icon(onPressed:fetchOptionRows,icon:const Icon(Icons.table_view),label:Text('LOAD FULL '+optionFilter+' CHAIN')),
    OutlinedButton.icon(onPressed:connection=='Connected'?downloadNseCsv:null,icon:const Icon(Icons.download),label:const Text('DOWNLOAD NSE CSV')),
    infoCard('Color logic','CALL green • PUT red • strike blue. OI↑/price↑ green ↑↑; OI↑/price↓ red ↑↓; OI↓/price↓ red ↓↓. Missing live fields remain —.',Colors.blue),
  ]);

  Widget _coloredOiCell(dynamic strike,String type){
    final m=<String,dynamic>{};
    for(final r in liveOptionRows){if(r['strike']==strike&&r['type']==type){m.addAll(Map<String,dynamic>.from(r));break;}}
    final oi=numericField(m,const ['oiChange','netChangeOpnInterest']),price=numericField(m,const ['priceChange','netChange']);
    final color=oi!=null&&price!=null&&oi>0&&price>0?Colors.green:oi!=null&&price!=null&&oi>0&&price<0?Colors.red:oi!=null&&price!=null&&oi<0&&price<0?Colors.red:Colors.grey;
    final arrow=oi==null||price==null?'':oi>0&&price>0?' ↑↑':oi>0&&price<0?' ↑↓':oi<0&&price<0?' ↓↓':oi<0&&price>0?' ↓↑':'';
    return Text(_chainOi(strike,type)+arrow,style:TextStyle(color:color,fontWeight:FontWeight.bold));
  }
  String _chainGreek(dynamic strike,String key){
    for(final r in liveOptionRows){if(r['strike']==strike&&(r['type']=='CE'||r['type']=='PE'))return (r[key]??'—').toString();}
    return '—';
  }
  String _chainFlow(dynamic strike){
    for(final r in liveOptionRows){if(r['strike']==strike)return optionMoveState(Map<String,dynamic>.from(r));}
    return '—';
  }

  Widget newsPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:<Widget>[
    Row(children:[const Expanded(child:Text('News',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold))),IconButton(onPressed:fetchTerminal,icon:const Icon(Icons.refresh))]),
    const Text('Live/verified news feed • source and timestamp shown with each item.',style:TextStyle(fontSize:12)),
    const SizedBox(height:10),
    Row(children:[Expanded(child:ChoiceChip(label:const Text('Market'),selected:true,onSelected:(_){ })),const SizedBox(width:8),const Text('Latest first')]),
    const SizedBox(height:8),
    infoCard('News feed','No fabricated headlines. Live cards will appear when the verified server-side news adapter supplies them.',Colors.orange),
    Card(child:ListTile(leading:const Icon(Icons.article_outlined),title:const Text('Live news area'),subtitle:const Text('Headline • source • time • related index/stock'),trailing:const Icon(Icons.chevron_right))),
    Card(child:ListTile(leading:const Icon(Icons.notifications_none),title:const Text('Market alerts'),subtitle:const Text('News-driven alerts will be displayed here when available.'),trailing:const Icon(Icons.chevron_right))),
  ]);

  Widget marketDetailsPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:[
    const Text('Market Details',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:4),const Text('Double-tap a market tab/card to activate the three-layer AI cross-check.',style:TextStyle(fontSize:12)),
    const SizedBox(height:10),
    Wrap(spacing:6,children:[for(final x in const ['NIFTY','BANK NIFTY','SENSEX'])GestureDetector(onDoubleTap:()=>_activateAi(x),child:ChoiceChip(label:Text(x),selected:selectedMarketDetail==x,onSelected:(_){setState(()=>selectedMarketDetail=x);}))) ]),
    const SizedBox(height:8),
    ...liveMarket.where((q)=>indexMatches(selectedMarketDetail,(q['tradingSymbol']??q['tradingsymbol']??q['symbol']??'').toString())).map((q)=>GestureDetector(onDoubleTap:()=>_activateAi(selectedMarketDetail),child:Card(child:ListTile(
      title:Text((q['tradingSymbol']??selectedMarketDetail).toString()),subtitle:Text('LTP '+formatMarketPrice(q['ltp'])+' • '+(q['exchange']??'').toString()),trailing:Text((q['percentChange']??q['netChange']??'—').toString()),onTap:()=>openQuoteChart(q),
    )))),
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('THREE-LAYER AI',style:TextStyle(fontWeight:FontWeight.bold)),
      _aiLayer('1 • AI BOT','Collects market, option-chain, OI, Greeks, trend and watchlist data.',Colors.cyan),
      _aiLayer('2 • AI ADMIN','Verifies freshness, missing fields and contradictory signals.',Colors.amber),
      _aiLayer('3 • AI CHATGPT','Cross-validates the verified snapshot and produces the final explanation using stored market-memory context.',Colors.green),
      const SizedBox(height:6),
      Text(aiActiveTab.isEmpty?'Double-tap a tab/card to start.':'AI active for: '+aiActiveTab,style:const TextStyle(fontWeight:FontWeight.bold)),
      Text('Memory folder: app documents/ai_memory/market_memory.json • entries: '+aiMemory.length.toString(),style:const TextStyle(fontSize:11)),
      if(aiMemory.isNotEmpty)Text('Latest: '+aiMemory.last,style:const TextStyle(fontSize:10)),
    ]))),
    Card(child:ListTile(leading:const Icon(Icons.verified_user),title:const Text('Cross-verification'),subtitle:Text(aiActiveTab.isEmpty?'Not started':'Collection → verification → validation queued for '+aiActiveTab),trailing:Icon(aiActiveTab.isEmpty?Icons.radio_button_unchecked:Icons.check_circle,color:aiActiveTab.isEmpty?Colors.grey:Colors.green))),
    Card(child:Padding(padding:const EdgeInsets.all(12),child:SizedBox(height:150,child:CustomPaint(painter:LiquidityPainter(liveMarket.where((q)=>indexMatches(selectedMarketDetail,(q['tradingSymbol']??q['tradingsymbol']??q['symbol']??'').toString())).toList()))))),
    infoCard('BSE DISPLAY','SENSEX / BANKEX retain BSE identity whenever live payload supplies BSE exchange data.',Colors.blue),
  ]);
  Widget _aiLayer(String title,String text,Color color)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:color.withOpacity(.16),child:Icon(Icons.smart_toy,color:color)),title:Text(title,style:TextStyle(color:color,fontWeight:FontWeight.bold)),subtitle:Text(text)));

  Widget signalsPage(){
    final action=signal?['action']?.toString()??'WAIT';
    final raw=signal?['reasons'];
    final reasons=raw is List?raw.map((e)=>e.toString()).join('\n'):'No live signal reasons received.';
    final a=action.toUpperCase();
    final terminalSignals=terminalData?['signals'] is List?terminalData!['signals'] as List:<dynamic>[];
    return ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Signals • Priority Terminal',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:4),const Text('Five minimum priority slots. Only live qualifying signal payloads populate them.',style:TextStyle(fontSize:11)),
      ...List<Widget>.generate(5,(i){
        final x=i<terminalSignals.length&&terminalSignals[i] is Map?Map<String,dynamic>.from(terminalSignals[i]):<String,dynamic>{};
        final src=i==0&&signal!=null?signal!:x;
        final has=src.isNotEmpty;
        final act=src['action']?.toString().toUpperCase()??'WAIT';
        return Card(child:ListTile(
          leading:CircleAvatar(child:Text((i+1).toString())),
          title:Text('PRIORITY '+(i+1).toString()+' • '+(has?(act.contains('CALL')?'CALL BUY':act.contains('PUT')?'PUT BUY':'WAIT'):'WAIT')),
          subtitle:Text(has?(src['symbol']??'Index/Equity').toString()+' • Entry '+(src['entry']??src['ltp']??'—').toString()+' • SL '+(src['sl']??src['stopLoss']??'—').toString()+' • Target '+(src['target']??'—').toString():'No qualifying live setup'),
          trailing:Text(has?'LIVE':'—'),
        ));
      }),
      const SizedBox(height:8),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('ACTIVE TRADE SETUP',style:TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:6),Text(a.contains('CALL')?'CALL BUY':a.contains('PUT')?'PUT BUY':'WAIT / NO QUALIFYING TRADE',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        if(signal!=null)...[row('Symbol',signal!['symbol']),row('Entry / LTP',signal!['entry']??signal!['ltp']),row('Stop Loss',signal!['sl']??signal!['stopLoss']),row('Target',signal!['target'])],
        if(signal==null)const Text('Live signal payload required. No trade value is invented.'),
      ]))),
      infoCard('Why',reasons,Colors.blue),
      infoCard('Rule','Priority is an ordering field only. No signal is created when the backend does not provide a qualifying setup.',Colors.orange),
    ]);
  }

  Widget nseMcpPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:<Widget>[
    Row(children:[const Expanded(child:Text('NSE MCP',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold))),IconButton(onPressed:fetchTerminal,icon:const Icon(Icons.refresh))]),
    infoCard('Official MCP','mcp.nseindia.in/cmmkt/mcp',Colors.blue),
    infoCard('Connection',nseMcpStatus,nseMcpStatus=='Connected'?Colors.green:Colors.orange),
    Card(child:ListTile(leading:const Icon(Icons.hub),title:const Text('Live market tools'),subtitle:const Text('MCP tool list and supported live data will appear here.'),trailing:const Icon(Icons.chevron_right))),
    Card(child:ListTile(leading:const Icon(Icons.table_chart),title:const Text('Live option chain'),subtitle:const Text('NSE MCP → Render → APK. Data may be delayed when the source is delayed.'),trailing:const Icon(Icons.chevron_right))),
    FilledButton.icon(onPressed:connection=='Connected'?downloadNseCsv:null,icon:const Icon(Icons.download),label:const Text('DOWNLOAD NSE OPTION CHAIN CSV')),
    infoCard('Security','MCP access is server-side; APK does not store NSE/Angel credentials.',Colors.green),
  ]);

  Widget angelApi() => AngelApiForm(
    backendUrl: backendUrl,
    apiToken: apiToken,
    connection: connection,
    status: angelLoginStatus,
    onConnected: fetchTerminal,
    onStatus: (v) => setState(() => angelLoginStatus = v),
  );

  Widget settingsPage() => ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:<Widget>[
    const Text('Settings',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    Card(child:SwitchListTile(title:const Text('Light mode'),subtitle:const Text('Switch between dark and light workspace'),value:lightMode,onChanged:(v)=>setState(()=>lightMode=v))),
    infoCard('Backend URL',backendUrl,Colors.blue),
    infoCard('Mode','Design / data workspace • algorithm deferred',Colors.orange),
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('TIMEFRAMES',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:7),
      Wrap(spacing:5,children:const[Chip(label:Text('1m')),Chip(label:Text('3m')),Chip(label:Text('5m')),Chip(label:Text('10m')),Chip(label:Text('15m')),Chip(label:Text('30m')),Chip(label:Text('1H')),Chip(label:Text('1D'))]),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('INDICATORS — SELECT TO SHOW',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:7),
      Wrap(spacing:5,runSpacing:5,children:[for(final x in const ['EMA 8','EMA 13','VWAP','RSI 14','MACD','Bollinger','Volume','ATR 14'])FilterChip(label:Text(x),selected:selectedIndicators.contains(x),onSelected:(v)=>setState(()=>v?selectedIndicators.add(x):selectedIndicators.remove(x)))]),
    ]))),
    FilledButton.icon(onPressed:openSettings,icon:const Icon(Icons.dns),label:const Text('EDIT SERVER CONNECTION')),
  ]);

  Widget morePage() => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    const Text('More', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    infoCard('Order mode','No order placement. Paper signals only.',Colors.orange),
    infoCard('Security','Keep Angel credentials server-side and never commit secrets.',Colors.blue),
    infoCard('Navigation',screens.join(', '),Colors.blue),
  ]);

  Widget dataPage(String title) {
    if(title=='Data') return ListView(padding:const EdgeInsets.fromLTRB(12,10,12,20),children:[
      const Text('Data',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
      const SizedBox(height:4),const Text('Live OI, breadth and market payload workspace.',style:TextStyle(fontSize:12)),
      const SizedBox(height:10),
      Card(child:ListTile(leading:const Icon(Icons.bar_chart),title:const Text('NIFTY OI'),subtitle:const Text('Total / change / buildup — live payload pending'),trailing:const Text('—'))),
      Card(child:ListTile(leading:const Icon(Icons.bar_chart),title:const Text('BANK NIFTY OI'),subtitle:const Text('Total / change / buildup — live payload pending'),trailing:const Text('—'))),
      Card(child:ListTile(leading:const Icon(Icons.compare_arrows),title:const Text('OI Change'),subtitle:const Text('Increased / decreased contracts'),trailing:const Text('—'))),
      Card(child:ListTile(leading:const Icon(Icons.hub),title:const Text('NSE MCP Data'),subtitle:Text(nseMcpStatus),trailing:const Icon(Icons.chevron_right))),
      infoCard('Live data policy','No OI or market value is fabricated. The design is ready for the corresponding backend payload.',Colors.blue),
    ]);
    if(title=='Instruments') return ListView(padding:const EdgeInsets.all(16),children:[const Text('Instruments',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:8),infoCard('Instrument universe','NSE / BSE / NFO / MCX searchable instruments will be displayed here.',Colors.blue),const ListTile(leading:Icon(Icons.search),title:Text('Search instrument'),subtitle:Text('Symbol • exchange • token • segment'))]);
    return ListView(padding:const EdgeInsets.all(16),children:[Text(title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),const SizedBox(height:10),infoCard('Live data status',connection=='Connected'?'Backend connected.':'Backend not connected.',connection=='Connected'?Colors.green:Colors.orange),infoCard('Data source','Corresponding API/data adapter is handled by the backend.',Colors.blue)]);
  }

  Future<void> openSettings() async {
    final u = TextEditingController(text: backendUrl);
    final k = TextEditingController(text: apiToken);
    await showDialog<void>(context: context, builder: (d) => AlertDialog(
      title: const Text('Server Settings'),
      content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        TextField(controller:u, decoration: const InputDecoration(labelText:'Backend URL')),
        TextField(controller:k, obscureText:true, decoration: const InputDecoration(labelText:'API token')),
      ]),
      actions: <Widget>[TextButton(onPressed: () {
        setState(() { backendUrl = u.text.trim().replaceAll(RegExp(r'/$'), ''); apiToken = k.text.trim(); });
        Navigator.pop(d); fetchTerminal();
      }, child: const Text('Save'))],
    ));
    u.dispose(); k.dispose();
  }

  Widget _breadthBox(String title,String value,Color color)=>Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.35))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(fontSize:10,color:color,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:11))]));

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



class LiquidityPainter extends CustomPainter {
  final List<dynamic> rows;
  LiquidityPainter(this.rows);
  @override void paint(Canvas canvas,Size size){
    final values=<double>[]; final labels=<String>[];
    for(final q in rows){
      if(q is! Map)continue;
      final m=liquidityMetric(Map<String,dynamic>.from(q));
      if(m!=null){values.add(m);labels.add((q['tradingSymbol']??q['tradingsymbol']??q['symbol']??'').toString());}
    }
    if(values.isEmpty){
      final tp=TextPainter(text:const TextSpan(text:'Live liquidity payload pending',style:TextStyle(fontSize:12,color:Colors.grey)),textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(4,size.height/2-8));return;
    }
    final maxV=values.reduce(math.max);
    final bw=size.width/values.length;
    for(int i=0;i<values.length;i++){
      final double barHeight = maxV > 0 ? ((values[i] / maxV) * (size.height - 28)).toDouble() : 0.0;
      final p=Paint()..color=Colors.cyan;
      final double barWidth = math.max(4.0, bw - 8).toDouble();
      canvas.drawRect(Rect.fromLTWH((i * bw + 4).toDouble(), (size.height - 24 - barHeight).toDouble(), barWidth, barHeight), p);
      final tp=TextPainter(text:TextSpan(text:labels[i].replaceAll(' ','\n'),style:const TextStyle(fontSize:8,color:Colors.grey)),textDirection:TextDirection.ltr)..layout(maxWidth:bw);
      tp.paint(canvas,Offset(i*bw+2,size.height-22));
    }
  }
  @override bool shouldRepaint(covariant LiquidityPainter old)=>old.rows!=rows;
}

class DrawingPainter extends CustomPainter {
  final String tool;
  final List<Offset> points;
  DrawingPainter(this.tool,this.points);
  @override void paint(Canvas canvas,Size size){
    if(points.isEmpty||tool.isEmpty)return;
    final p=Paint()..color=Colors.amber..strokeWidth=1.6..style=PaintingStyle.stroke;
    final a=points.first;
    if(tool=='Horizontal')canvas.drawLine(Offset(0,a.dy),Offset(size.width,a.dy),p);
    if(tool=='Vertical')canvas.drawLine(Offset(a.dx,0),Offset(a.dx,size.height),p);
    if(points.length<2)return;
    final b=points[1];
    if(tool=='Fibonacci'){
      canvas.drawLine(a,b,p);
      final levels=[0.0,.236,.382,.5,.618,.786,1.0];
      for(final l in levels){final y=a.dy+(b.dy-a.dy)*l;canvas.drawLine(Offset(math.min(a.dx,b.dx),y),Offset(size.width,y),p);}
    }else if(tool=='Long Position'||tool=='Short Position'){
      final entry=b.dy;
      final distance=(a.dy-b.dy).abs().clamp(20.0,size.height/2).toDouble();
      final sign=tool=='Long Position'?-1:1;
      final target=entry+sign*distance, stop=entry-sign*distance*.6;
      canvas.drawLine(Offset(0,entry),Offset(size.width,entry),p);
      canvas.drawLine(Offset(0,target),Offset(size.width,target),p);
      canvas.drawLine(Offset(0,stop),Offset(size.width,stop),p);
    }
  }
  @override bool shouldRepaint(covariant DrawingPainter old)=>old.tool!=tool||old.points!=points;
}

class CandlePainter extends CustomPainter {
  final List<dynamic> rows;
  final Set<String> indicators;
  CandlePainter(this.rows,this.indicators);

  List<double?> ema(List<double> v,int n){
    final out=List<double?>.filled(v.length,null); if(v.isEmpty)return out;
    double prev=v.first; out[0]=prev; final k=2/(n+1);
    for(int i=1;i<v.length;i++){prev=v[i]*k+prev*(1-k);out[i]=prev;} return out;
  }
  List<double?> rsi(List<double> v,int n){
    final out=List<double?>.filled(v.length,null); if(v.length<=n)return out;
    double gain=0,loss=0;
    for(int i=1;i<=n;i++){final d=v[i]-v[i-1];gain+=math.max(d,0);loss+=math.max(-d,0);}
    for(int i=n;i<v.length;i++){
      if(i>n){final d=v[i]-v[i-1];gain=(gain*(n-1)+math.max(d,0))/n;loss=(loss*(n-1)+math.max(-d,0))/n;}
      out[i]=loss==0?100:100-(100/(1+gain/loss));
    }
    return out;
  }

  @override void paint(Canvas canvas,Size size){
    final vals=rows.where((r)=>r is List&&r.length>=5).toList();
    if(vals.isEmpty)return;
    final close=vals.map<double>((r)=>(r[4]as num).toDouble()).toList();
    final overlays=<List<double?>>[];
    if(indicators.contains('EMA 8'))overlays.add(ema(close,8));
    if(indicators.contains('EMA 13'))overlays.add(ema(close,13));
    if(indicators.contains('SMA 20')){
      final a=List<double?>.filled(close.length,null);
      for(int i=19;i<close.length;i++)a[i]=close.sublist(i-19,i+1).reduce((x,y)=>x+y)/20;
      overlays.add(a);
    }
    if(indicators.contains('VWAP')){
      final a=List<double?>.filled(close.length,null);double pv=0,vol=0;
      for(int i=0;i<vals.length;i++){final r=vals[i];final h=(r[2]as num).toDouble(),l=(r[3]as num).toDouble(),cl=close[i];final v=r.length>5&&r[5] is num?(r[5]as num).toDouble():0;pv+=((h+l+cl)/3)*v;vol+=v;a[i]=vol>0?pv/vol:cl;} overlays.add(a);
    }
    double minV=double.infinity,maxV=-double.infinity;
    for(final r in vals){minV=math.min(minV,(r[3]as num).toDouble());maxV=math.max(maxV,(r[2]as num).toDouble());}
    for(final a in overlays)for(final x in a)if(x!=null){minV=math.min(minV,x);maxV=math.max(maxV,x);}
    final hasRsi=indicators.contains('RSI 14');
    final chartH=hasRsi?size.height*.75:size.height;
    final range=math.max(maxV-minV,.01),width=size.width/vals.length;
    double y(double v)=>chartH-(v-minV)/range*chartH;
    final grid=Paint()..color=Colors.white10..strokeWidth=.6;
    for(int i=0;i<5;i++){final yy=chartH*i/4;canvas.drawLine(Offset(0,yy),Offset(size.width,yy),grid);}
    for(int i=0;i<5;i++){
      final v=maxV-(maxV-minV)*i/4;
      final tp=TextPainter(text:TextSpan(text:formatMarketPrice(v),style:const TextStyle(fontSize:9,color:Colors.grey)),textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(size.width-tp.width-2,chartH*i/4-6));
    }
    final wick=Paint()..strokeWidth=1.2,body=Paint()..strokeWidth=math.max(2,width*.55);
    for(int i=0;i<vals.length;i++){
      final r=vals[i];final o=(r[1]as num).toDouble(),h=(r[2]as num).toDouble(),l=(r[3]as num).toDouble(),cl=close[i];final x=i*width+width/2,up=cl>=o;
      wick.color=up?Colors.green:Colors.red;body.color=wick.color;
      canvas.drawLine(Offset(x,y(h)),Offset(x,y(l)),wick);canvas.drawLine(Offset(x,y(o)),Offset(x,y(cl)),body);
    }
    final colors=[Colors.cyan,Colors.amber,Colors.purple,Colors.orange];
    for(int k=0;k<overlays.length;k++){final p=Paint()..color=colors[k%colors.length]..strokeWidth=1.5;final a=overlays[k];for(int i=1;i<a.length;i++)if(a[i-1]!=null&&a[i]!=null)canvas.drawLine(Offset((i-1)*width+width/2,y(a[i-1]!)),Offset(i*width+width/2,y(a[i]!)),p);}
    if(hasRsi){
      final rv=rsi(close,14),top=chartH+4,panelH=size.height-top-4,paint=Paint()..color=Colors.orange..strokeWidth=1.3;
      for(int i=1;i<rv.length;i++)if(rv[i-1]!=null&&rv[i]!=null){double ry(double z)=>top+panelH-(z/100)*panelH;canvas.drawLine(Offset((i-1)*width+width/2,ry(rv[i-1]!)),Offset(i*width+width/2,ry(rv[i]!)),paint);}
      final tp=TextPainter(text:const TextSpan(text:'RSI 14',style:TextStyle(fontSize:10,color:Colors.grey)),textDirection:TextDirection.ltr)..layout();tp.paint(canvas,Offset(4,top));
    }
  }
  @override bool shouldRepaint(covariant CandlePainter old)=>old.rows!=rows||old.indicators!=indicators;
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
    widget.onStatus('Connecting to Angel One through Render backend...');

    try {
      final response = await http.post(
        Uri.parse(widget.backendUrl + '/v1/angel/login'),
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
      ).timeout(const Duration(seconds: 25));

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
                'Frontend → Render backend → Angel One SmartAPI',
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
