import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  Map<String,dynamic>? signal;
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
      setState(() {
        terminalData = decoded is Map<String,dynamic> ? decoded : null;
        final c = terminalData?['connection'];
        final s = terminalData?['signals'];
        signal = s is Map<String,dynamic> ? s : null;
        connection = response.statusCode == 200 && c is Map && c['server'] == true ? 'Connected' : 'HTTP ' + response.statusCode.toString();
      });
    } catch (_) {
      if (mounted) setState(() => connection = 'Backend not connected');
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
    if (selected == 3) return signals();
    if (selected == 11) return angelApi();
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

  Widget signals() {
    final action = signal?['action']?.toString() ?? 'WAIT';
    final raw = signal?['reasons'];
    final reasons = raw is List ? raw.map((e) => e.toString()).join('\\n') : 'No live signal reasons received.';
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      const Text('Signals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      infoCard(action.replaceAll('_',' '), reasons, Colors.blue),
      const SizedBox(height: 12),
      infoCard('Engine','Paper-signal engine. Live values appear only when the backend supplies them.',Colors.orange),
    ]);
  }

  Widget angelApi() => ListView(padding: const EdgeInsets.all(16), children: <Widget>[
    const Text('Angel API', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    infoCard('SmartAPI','Authentication is handled by the backend. Do not hard-code API key, PIN or TOTP in the APK.',Colors.blue),
    infoCard('Backend URL',backendUrl,Colors.blue),
    infoCard('Connection',connection,connection == 'Connected' ? Colors.green : Colors.red),
  ]);

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