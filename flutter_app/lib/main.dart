import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';

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
    'Dashboard','Market','Commodity','Signals','OI Lab','Watchlist','Search',
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
  List<dynamic> liveIndices = <dynamic>[];
  int selectedChartDays = 30;
  String selectedChartToken = '99926000';
  String selectedChartExchange = 'NSE';
  String selectedInterval = 'FIVE_MINUTE';
  bool angelDataBusy = false;
  Map<String,dynamic>? terminalData;
  Timer? timer;

  @override void initState() {
    super.initState();
    fetchTerminal();
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
      if (angel) { await fetchAngelMarket(); await fetchAngelIndices(); }
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

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(screens[selected]),
      actions: <Widget>[
        IconButton(onPressed: fetchTerminal, icon: const Icon(Icons.refresh)),
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
            Text('18-screen paper terminal'),
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
    body: buildScreen(),
  );

  Widget buildScreen() {
    if (selected == 0) return dashboard();
    if (selected == 1) return marketPage();
    if (selected == 2) return commodityPage();
    if (selected == 3) return signals();
    if (selected == 4) return oiLabPage();
    if (selected == 5) return watchlistPage();
    if (selected == 6) return searchPage();
    if (selected == 7) return chartsPage();
    if (selected == 8) return optionChain();
    if (selected == 9) return newsPage();
    if (selected == 10) return marketDetailsPage();
    if (selected == 11) return angelApi();
    if (selected == 13) return nseMcp();
    if (selected == 16) return settingsPage();
    if (selected == 17) return morePage();
    return dataPage(screens[selected]);
  }

  Widget dashboard() {
    final action = signal?['action']?.toString() ?? 'WAIT';
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: <Widget>[
        const Icon(Icons.bolt, size: 34), const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('NSE Algo Signal', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          Text('18 screens • Live-data architecture'),
        ])),
        Chip(label: Text(connection)),
      ]))),
      const SizedBox(height: 12),
      infoCard('Backend', connection, connection == 'Connected' ? Colors.green : Colors.red),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('CURRENT SIGNAL', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(action.replaceAll('_',' '), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (signal != null) ...<Widget>[
          row('Symbol', signal!['symbol']), row('Spot', signal!['spot']),
          row('Strike', (signal!['strike'] ?? '-').toString() + ' ' + (signal!['type'] ?? '').toString()),
          row('Entry', signal!['entry']), row('LTP', signal!['ltp']),
          row('Stop Loss', signal!['sl']), row('Target', signal!['target']), row('Score', signal!['score']),
        ] else const Text('No live signal payload received.'),
      ]))),
      const SizedBox(height: 12),
      infoCard('Data policy','Real API/data only. Paper signals only. No order placement.',Colors.blue),
    ]);
  }


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


  Future<void> fetchAngelIndices() async {
    try {
      final r=await http.get(Uri.parse(backendUrl+'/v1/angel/indices'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:12));
      if(r.statusCode==200){
        final d=jsonDecode(r.body);
        final rows=d is Map && d['data'] is List ? d['data'] : <dynamic>[];
        if(mounted) setState(()=>liveIndices=rows is List ? rows : <dynamic>[]);
      }
    } catch (_) {}
  }

  Future<void> selectIndex(dynamic item) async {
    final token=(item['token']??'').toString();
    final exchange=(item['exchange']??'NSE').toString();
    if(token.isEmpty)return;
    setState((){selectedChartToken=token;selectedChartExchange=exchange;selected=7;});
    await fetchCandles();
    if(!mounted)return;
    Navigator.of(context).push(MaterialPageRoute(builder:(_)=>AdvancedChartScreen(
      title:(item['name']??item['symbol']??'Index').toString(),
      exchange:exchange, token:token, candles:liveCandles,
      interval:selectedInterval, days:selectedChartDays,
      backendUrl:backendUrl, apiToken:apiToken,
    )));
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
      final r=await http.get(Uri.parse(backendUrl+'/v1/angel/option-chain?count=10'),headers:<String,String>{'x-token':apiToken}).timeout(const Duration(seconds:15));
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

  Widget marketPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Market',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Data source','Angel One SmartAPI • Indian Indices',Colors.blue),
    const Text('INDIAN INDICES',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
    const SizedBox(height:6),
    if(liveIndices.isEmpty) infoCard('Indices','Connect Angel One to load the complete index universe.',Colors.orange),
    ...liveIndices.map((x)=>Card(child:ListTile(
      title:Text((x['name']??x['symbol']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text((x['exchange']??'').toString()+' • Tap to open chart'),
      trailing:Text((x['ltp']??'-').toString(),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      onTap:()=>selectIndex(x),
    ))),
    FilledButton.icon(onPressed:fetchAngelIndices,icon:const Icon(Icons.refresh),label:const Text('REFRESH ALL INDIAN INDICES')),
    const SizedBox(height:14),
    const Text('COMMODITY',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
    infoCard('Separate segment','MCX commodities remain in the Commodity tab.',Colors.green),
  ]);

  Widget commodityPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Commodity',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Data source','Angel One SmartAPI • MCX Market Data',Colors.blue),
    infoCard('Segment','MCX',Colors.green),
    infoCard('Instruments','CRUDEOIL, NATURALGAS, GOLD, SILVER and other contracts are fetched after token search.',Colors.orange),
    FilledButton(onPressed:()=>setState(()=>selected=6),child:const Text('OPEN ANGEL SEARCH')),
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

  Widget watchlistPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Watchlist',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Live source','Angel One SmartAPI',Colors.blue),
    ...liveMarket.map((q)=>ListTile(title:Text((q['tradingSymbol']??'-').toString()),trailing:Text((q['ltp']??'-').toString()))),
    if(liveMarket.isEmpty) infoCard('Watchlist','Connect Angel One to populate live instruments.',Colors.orange),
  ]);

  Widget searchPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Search',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    const Text('Search Scrip • Angel One SmartAPI'),
    const SizedBox(height:10),
    TextField(
      decoration:const InputDecoration(labelText:'NSE / BSE / MCX symbol',border:OutlineInputBorder()),
      onSubmitted:(q) async {
        if(q.trim().isEmpty)return;
        try{
          final r=await http.get(Uri.parse(backendUrl+'/v1/angel/search?exchange=NSE&q='+Uri.encodeQueryComponent(q.trim())),headers:<String,String>{'x-token':apiToken});
          if(r.statusCode==200 && mounted) setState(()=>terminalData={'search':jsonDecode(r.body)});
        }catch(_){}
      },
    ),
    const SizedBox(height:12),
    if(terminalData?['search'] is Map)
      ...((terminalData!['search']['data'] is List ? terminalData!['search']['data'] : <dynamic>[]).map((x)=>Card(child:ListTile(title:Text((x['tradingsymbol']??'-').toString()),subtitle:Text((x['exchange']??'').toString()+' • Token '+(x['symboltoken']??'-').toString()))))),
  ]);

  Widget chartsPage() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Charts',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Angel One Chart Engine','Historical candles from SmartAPI • interactive full-screen chart',Colors.blue),
    DropdownButtonFormField<String>(
      value:selectedInterval,
      decoration:const InputDecoration(labelText:'Timeframe',border:OutlineInputBorder()),
      items:const[
        DropdownMenuItem(value:'ONE_MINUTE',child:Text('1 Minute')),
        DropdownMenuItem(value:'THREE_MINUTE',child:Text('3 Minute')),
        DropdownMenuItem(value:'FIVE_MINUTE',child:Text('5 Minute')),
        DropdownMenuItem(value:'TEN_MINUTE',child:Text('10 Minute')),
        DropdownMenuItem(value:'FIFTEEN_MINUTE',child:Text('15 Minute')),
        DropdownMenuItem(value:'THIRTY_MINUTE',child:Text('30 Minute')),
        DropdownMenuItem(value:'ONE_HOUR',child:Text('1 Hour')),
        DropdownMenuItem(value:'ONE_DAY',child:Text('1 Day')),
      ],
      onChanged:(v){if(v!=null){setState(()=>selectedInterval=v);fetchCandles();}}
    ),
    const SizedBox(height:8),
    DropdownButtonFormField<int>(
      value:selectedChartDays,
      decoration:const InputDecoration(labelText:'Historical range (days)',border:OutlineInputBorder()),
      items:const[1,7,30,100,200,400,1000,2000].map((d)=>DropdownMenuItem(value:d,child:Text('$d days'))).toList(),
      onChanged:(v){if(v!=null){setState(()=>selectedChartDays=v);fetchCandles();}}
    ),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:fetchAngelIndices,icon:const Icon(Icons.refresh),label:const Text('REFRESH INDIAN INDICES')),
    const SizedBox(height:8),
    if(liveIndices.isEmpty) infoCard('Indian Indices','No index payload received yet. Connect Angel One and refresh.',Colors.orange),
    ...liveIndices.map((x)=>Card(
      child:ListTile(
        leading:const Icon(Icons.show_chart),
        title:Text((x['name']??x['symbol']??'-').toString()),
        subtitle:Text((x['exchange']??'').toString()+' • '+(x['token']??'').toString()),
        trailing:Text((x['ltp']??'-').toString()),
        onTap:()=>selectIndex(x),
      )
    )),
    const SizedBox(height:8),
    infoCard('Chart interaction','Tap any index → full-screen landscape chart. Pinch to zoom, drag to pan, choose indicators and timeframe.',Colors.green),
    FilledButton.icon(
      onPressed:liveIndices.isNotEmpty?()=>selectIndex(liveIndices.first):null,
      icon:const Icon(Icons.fullscreen),
      label:const Text('OPEN FULL ANGEL-STYLE CHART')
    ),
  ]);

  Widget optionChain() => ListView(padding:const EdgeInsets.all(16),children:<Widget>[
    const Text('Option Chain',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    infoCard('Live source','Angel One SmartAPI NFO FULL market data • OI/LTP/volume',Colors.blue),
    if(liveOptionRows.isEmpty) infoCard('Option chain','Press refresh to fetch live CE/PE rows around ATM.',Colors.orange),
    ...liveOptionRows.map((r)=>Card(child:ListTile(
      title:Text((r['strike']??'-').toString()+' '+(r['type']??'').toString()),
      subtitle:Text('LTP '+(r['ltp']??'-').toString()+' • OI '+(r['oi']??'-').toString()+' • Vol '+(r['volume']??'-').toString()),
      trailing:Text((r['buyQty']??'-').toString()+' / '+(r['sellQty']??'-').toString()),
    ))),
    FilledButton.icon(onPressed:fetchOptionRows,icon:const Icon(Icons.refresh),label:Text(angelDataBusy?'LOADING...':'REFRESH ANGEL OPTION CHAIN')),
    const SizedBox(height:8),
    FilledButton.icon(onPressed:connection=='Connected'?downloadNseCsv:null,icon:const Icon(Icons.download),label:const Text('DOWNLOAD NSE OPTION CHAIN CSV')),
  ]);

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

  Widget nseMcp() => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    const Text('NSE MCP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    infoCard('Official endpoint','https://mcp.nseindia.in/cmmkt/mcp',Colors.blue),
    infoCard('Connection',nseMcpStatus,nseMcpStatus == 'Connected' ? Colors.green : Colors.orange),
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
    infoCard('Backend URL',backendUrl,Colors.blue),
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




class AdvancedChartScreen extends StatefulWidget {
  final String title, exchange, token, interval, backendUrl, apiToken;
  final int days;
  final List<dynamic> candles;
  const AdvancedChartScreen({super.key,required this.title,required this.exchange,required this.token,required this.candles,required this.interval,required this.days,required this.backendUrl,required this.apiToken});
  @override State<AdvancedChartScreen> createState()=>_AdvancedChartScreenState();
}
class _AdvancedChartScreenState extends State<AdvancedChartScreen> {
  late String interval; late int days; List<dynamic> rows=[]; bool loading=false;
  final Set<String> indicators={'EMA 8','EMA 13','SMA 20','VWAP','Bollinger','Volume','RSI 14'};
  @override void initState(){super.initState();interval=widget.interval;days=widget.days;rows=widget.candles;SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);if(rows.isEmpty)load();}
  @override void dispose(){SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp,DeviceOrientation.portraitDown]);super.dispose();}
  Future<void> load() async {setState(()=>loading=true);try{final u=widget.backendUrl+'/v1/angel/candles?exchange='+widget.exchange+'&token='+widget.token+'&interval='+interval+'&days='+days.toString();final r=await http.get(Uri.parse(u),headers:<String,String>{'x-token':widget.apiToken}).timeout(const Duration(seconds:20));if(r.statusCode==200){final d=jsonDecode(r.body);final x=d is Map&&d['data'] is List?d['data']:<dynamic>[];if(mounted)setState(()=>rows=x is List?x:[]);}}catch(_){}if(mounted)setState(()=>loading=false);}
  void toggle(String n){setState(()=>indicators.contains(n)?indicators.remove(n):indicators.add(n));}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xff080b10),appBar:AppBar(title:Text(widget.title+' • '+widget.exchange),backgroundColor:const Color(0xff0d1117),actions:[
    DropdownButton<String>(value:interval,dropdownColor:const Color(0xff151a21),items:const[
      DropdownMenuItem(value:'ONE_MINUTE',child:Text('1m')),DropdownMenuItem(value:'THREE_MINUTE',child:Text('3m')),DropdownMenuItem(value:'FIVE_MINUTE',child:Text('5m')),DropdownMenuItem(value:'TEN_MINUTE',child:Text('10m')),DropdownMenuItem(value:'FIFTEEN_MINUTE',child:Text('15m')),DropdownMenuItem(value:'THIRTY_MINUTE',child:Text('30m')),DropdownMenuItem(value:'ONE_HOUR',child:Text('1H')),DropdownMenuItem(value:'ONE_DAY',child:Text('1D'))],onChanged:(v){if(v!=null){setState(()=>interval=v);load();}}),
    const SizedBox(width:8),IconButton(onPressed:load,icon:const Icon(Icons.refresh)),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))
  ]),body:Column(children:[
    SizedBox(height:46,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8),children:[
      for(final n in const ['EMA 8','EMA 13','SMA 20','SMA 50','SMA 200','VWAP','Bollinger','Volume','RSI 14','MACD','Stochastic 14','ATR 14'])Padding(padding:const EdgeInsets.symmetric(horizontal:3,vertical:5),child:FilterChip(label:Text(n),selected:indicators.contains(n),onSelected:(_)=>toggle(n)))
    ])),
    Expanded(child:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('No Angel One candle data returned.')):LayoutBuilder(builder:(context,box){final width=math.max(box.maxWidth,rows.length*7.0);return InteractiveViewer(minScale:.6,maxScale:4,panEnabled:true,scaleEnabled:true,boundaryMargin:const EdgeInsets.all(500),child:SizedBox(width:width,height:box.maxHeight,child:CustomPaint(painter:AdvancedCandlePainter(rows,indicators))));})),
    Container(height:26,alignment:Alignment.centerLeft,padding:const EdgeInsets.symmetric(horizontal:10),child:Text(loading?'Loading…':rows.isEmpty?'No data':'1 candles • Angel One historical API • Pinch/drag to explore • Indicators calculated from returned candles',style:const TextStyle(fontSize:11,color:Colors.white70)))
  ]));
}
List<double?> _series(List<dynamic> rows,int field)=>rows.map<double?>((r)=>r is List&&r.length>field&&r[field] is num?(r[field]as num).toDouble():null).toList();
List<double?> _sma(List<double?> v,int n){final o=List<double?>.filled(v.length,null);double sum=0;int count=0;for(int i=0;i<v.length;i++){final x=v[i];if(x!=null){sum+=x;count++;}if(i>=n){final z=v[i-n];if(z!=null){sum-=z;count--;}}if(i>=n-1&&count==n)o[i]=sum/n;}return o;}
List<double?> _ema(List<double?> v,int n){final o=List<double?>.filled(v.length,null);double? p;final k=2/(n+1);for(int i=0;i<v.length;i++){final x=v[i];if(x==null)continue;p=p==null?x:x*k+p!*(1-k);o[i]=p;}return o;}
List<double?> _vwap(List<dynamic> rows){final o=List<double?>.filled(rows.length,null);double pv=0,vol=0;for(int i=0;i<rows.length;i++){final r=rows[i];if(r is List&&r.length>=6){final h=(r[2]as num).toDouble(),l=(r[3]as num).toDouble(),c=(r[4]as num).toDouble(),v=(r[5]as num).toDouble();pv+=((h+l+c)/3)*v;vol+=v;o[i]=vol==0?c:pv/vol;}}return o;}
List<double?> _rsi(List<double?> c,int n){final o=List<double?>.filled(c.length,null);double gain=0,loss=0;for(int i=1;i<c.length;i++){if(c[i]==null||c[i-1]==null)continue;final d=c[i]!-c[i-1]!;gain+=math.max(d,0);loss+=math.max(-d,0);if(i>=n){final p=c[i-n],q=c[i-n-1];if(p!=null&&q!=null){final z=p-q;gain-=math.max(z,0);loss-=math.max(-z,0);}}if(i>=n){final rs=loss==0?100:gain/loss;o[i]=100-(100/(1+rs));}}return o;}
class AdvancedCandlePainter extends CustomPainter {
  final List<dynamic> rows;final Set<String> ind;AdvancedCandlePainter(this.rows,this.ind);
  @override void paint(Canvas canvas,Size size){
    final valid=rows.where((r)=>r is List&&r.length>=5).toList();if(valid.isEmpty)return;
    final close=_series(valid,4),high=_series(valid,2),low=_series(valid,3);final overlays=<List<double?>>[];
    if(ind.contains('EMA 8'))overlays.add(_ema(close,8));if(ind.contains('EMA 13'))overlays.add(_ema(close,13));if(ind.contains('SMA 20'))overlays.add(_sma(close,20));if(ind.contains('SMA 50'))overlays.add(_sma(close,50));if(ind.contains('SMA 200'))overlays.add(_sma(close,200));if(ind.contains('VWAP'))overlays.add(_vwap(valid));
    if(ind.contains('Bollinger')){final m=_sma(close,20);final sd=List<double?>.filled(close.length,null);for(int i=19;i<close.length;i++){final a=close.sublist(i-19,i+1).whereType<double>().toList();if(a.length==20){final av=a.reduce((x,z)=>x+z)/20;sd[i]=math.sqrt(a.map((x)=>(x-av)*(x-av)).reduce((x,z)=>x+z)/20);}}overlays.add(List<double?>.generate(close.length,(i)=>m[i]==null||sd[i]==null?null:m[i]!+2*sd[i]!));overlays.add(List<double?>.generate(close.length,(i)=>m[i]==null||sd[i]==null?null:m[i]!-2*sd[i]!));}
    double minV=double.infinity,maxV=-double.infinity;for(final x in low)if(x!=null)minV=math.min(minV,x);for(final x in high)if(x!=null)maxV=math.max(maxV,x);for(final a in overlays)for(final x in a)if(x!=null){minV=math.min(minV,x);maxV=math.max(maxV,x);}
    final osc=ind.contains('RSI 14')||ind.contains('MACD')||ind.contains('Stochastic 14')||ind.contains('ATR 14');final chartH=osc?size.height*.76:size.height*.88;final range=math.max(maxV-minV,.01);final w=math.max(4.0,size.width/valid.length);
    final grid=Paint()..color=Colors.white12..strokeWidth=.6;for(int i=0;i<6;i++){final yy=chartH*i/5;canvas.drawLine(Offset(0,yy),Offset(size.width,yy),grid);}double y(double v)=>chartH-(v-minV)/range*chartH;
    final wick=Paint()..strokeWidth=1,body=Paint()..strokeWidth=math.max(2,w*.55);
    double maxVol=1;for(final r in valid)if(r is List&&r.length>=6&&r[5] is num)maxVol=math.max(maxVol,(r[5]as num).toDouble());
    for(int i=0;i<valid.length;i++){final r=valid[i];final o=(r[1]as num).toDouble(),h=(r[2]as num).toDouble(),l=(r[3]as num).toDouble(),cl=(r[4]as num).toDouble();final x=i*w+w/2,up=cl>=o;wick.color=up?Colors.greenAccent:Colors.redAccent;body.color=wick.color;canvas.drawLine(Offset(x,y(h)),Offset(x,y(l)),wick);canvas.drawLine(Offset(x,y(o)),Offset(x,y(cl)),body);if(ind.contains('Volume')&&r is List&&r.length>=6&&r[5] is num){final vh=chartH+(r[5]as num).toDouble()/maxVol*(size.height-chartH-5);final vp=Paint()..color=(up?Colors.green:Colors.red).withOpacity(.35);canvas.drawRect(Rect.fromLTRB(x-w*.35,chartH,x+w*.35,vh),vp);}}
    final colors=[Colors.cyanAccent,Colors.amberAccent,Colors.purpleAccent,Colors.orangeAccent,Colors.pinkAccent,Colors.lightBlueAccent,Colors.white70,Colors.blueGrey];for(int k=0;k<overlays.length;k++){final p=Paint()..color=colors[k%colors.length]..strokeWidth=1.2;final a=overlays[k];for(int i=1;i<a.length;i++)if(a[i-1]!=null&&a[i]!=null)canvas.drawLine(Offset((i-1)*w+w/2,y(a[i-1]!)),Offset(i*w+w/2,y(a[i]!)),p);}
    if(osc&&ind.contains('RSI 14')){final top=chartH+5,ph=size.height-top-5,r=_rsi(close,14),p=Paint()..color=Colors.orangeAccent..strokeWidth=1.2;for(int i=1;i<r.length;i++)if(r[i-1]!=null&&r[i]!=null){double yy(double z)=>top+ph-(z/100)*ph;canvas.drawLine(Offset((i-1)*w+w/2,yy(r[i-1]!)),Offset(i*w+w/2,yy(r[i]!)),p);}}
  }
  @override bool shouldRepaint(covariant AdvancedCandlePainter old)=>old.rows!=rows||old.ind!=ind;
}
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
