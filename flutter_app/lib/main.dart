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
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const pages = <String>['Dashboard','Market','Commodity','Signals','OI Lab','Watchlist','Search','Charts','Option Chain','News','Market Details','Angel API','NSE','NSE MCP','Data','Instruments','Settings','More'];
  int tab = 0;
  String url = 'http://192.168.1.10:8000';
  String token = 'change-me';
  Map<String,dynamic>? data;
  String? error;
  Timer? timer;

  @override void initState() { super.initState(); _load(); }
  void _load() { _fetch(); timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch()); }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse(url + '/signal'), headers: {'x-token': token}).timeout(const Duration(seconds: 5));
      final v = jsonDecode(r.body);
      if (!mounted) return;
      setState(() { data = v is Map<String,dynamic> ? v : null; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(pages[tab]), actions: [IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)), IconButton(onPressed: _settings, icon: const Icon(Icons.settings))]),
    drawer: Drawer(child: SafeArea(child: ListView(
      children: [
        const DrawerHeader(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.candlestick_chart, size: 42), SizedBox(height: 10), Text('NSE Algo Signal', style: TextStyle(fontSize: 22)), Text('18-screen paper terminal')]),
        for (var i = 0; i < pages.length; i++) ListTile(leading: Icon(_icon(i)), title: Text(pages[i]), selected: tab == i, onTap: () { Navigator.pop(context); setState(() => tab = i); }),
      ],
    ))),
    body: _body(),
  );

  IconData _icon(int i) => const [Icons.dashboard,Icons.show_chart,Icons.precision_manufacturing,Icons.notifications,Icons.analytics,Icons.star,Icons.search,Icons.candlestick_chart,Icons.table_chart,Icons.article,Icons.info,Icons.key,Icons.language,Icons.hub,Icons.storage,Icons.list_alt,Icons.tune,Icons.more_horiz][i];

  Widget _body() {
    if (tab == 0) return _dashboard();
    if (tab == 3) return _signals();
    if (tab == 11) return _angel();
    if (tab == 16) return _settingsPage();
    return Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(_icon(tab), size: 48), const SizedBox(height: 12), Text(pages[tab], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Live values will appear only after the corresponding real API/data source is connected.', textAlign: TextAlign.center)]))));
  }

  Widget _dashboard() {
    final a = data?['action']?.toString() ?? 'WAIT';
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card('Backend', error == null ? 'Checking / connected' : 'Not connected', error == null ? Colors.greenAccent : Colors.redAccent),
      if (error != null) _card(error!, 'URL: ' + url, Colors.redAccent),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        const Text('CURRENT SIGNAL'), const SizedBox(height: 10),
        Text(a.replaceAll('_',' '), style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: _color(a))),
        const SizedBox(height: 12),
        if (data != null) ...[
          _row('Symbol', data!['symbol']), _row('Spot', data!['spot']), _row('Strike', '${data!['strike'] ?? '-'} ${data!['type'] ?? ''}'),
          _row('Entry', data!['entry']), _row('LTP', data!['ltp']), _row('Stop Loss', data!['sl']), _row('Target', data!['target']), _row('Score', data!['score'])
        ] else const Text('No live signal payload received.'),
      ]))),
      _card('Data policy', 'No fabricated market values. Paper signals only.', Colors.blueAccent),
    ]);
  }

  Widget _signals() {
    final reasons = (data?['reasons'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Signals', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _card(data?['action']?.toString() ?? 'WAIT', reasons.isEmpty ? 'No live signal' : reasons.join('\n'), _color(data?['action']?.toString() ?? 'WAIT')),
    ]);
  }

  Widget _angel() => ListView(padding: const EdgeInsets.all(16), children: [const Text('Angel API', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 12), _card('SmartAPI', 'Use secure backend authentication. Never hard-code API key, MPIN or TOTP.', Colors.blueAccent), _card('Backend', url, error == null ? Colors.greenAccent : Colors.redAccent)]);

  Widget _settingsPage() => ListView(padding: const EdgeInsets.all(16), children: [const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 12), _card('Backend URL', url, Colors.blueAccent), _card('Mode', 'Paper signals only', Colors.orangeAccent), _card('Timeframes', '1m 2m 3m 5m 10m 15m 30m 1h 2h 4h 1D', Colors.blueAccent), _card('Indicators', '8 EMA / 13 EMA', Colors.blueAccent)]);

  Future<void> _settings() async {
    final u = TextEditingController(text: url);
    final k = TextEditingController(text: token);
    await showDialog(context: context, builder: (d) => AlertDialog(title: const Text('Server'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: u, decoration: const InputDecoration(labelText: 'Backend URL')), TextField(controller: k, decoration: const InputDecoration(labelText: 'API token'), obscureText: true)]), actions: [TextButton(onPressed: () { setState(() { url = u.text.trim(); token = k.text.trim(); }); Navigator.pop(d); _fetch(); }, child: const Text('Save'))]));
    u.dispose(); k.dispose();
  }

  Widget _card(String title, String value, Color color) => Card(child: ListTile(leading: Icon(Icons.circle, color: color, size: 13), title: Text(title), subtitle: Text(value)));
  Widget _row(String k, dynamic v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k), Flexible(child: Text('${v ?? '-'}', textAlign: TextAlign.right))]));
  Color _color(String a) => a == 'BUY_CE' ? Colors.greenAccent : a == 'BUY_PE' ? Colors.redAccent : a == 'EXIT' ? Colors.orangeAccent : Colors.grey;
}