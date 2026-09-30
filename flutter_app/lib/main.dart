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

  int selected = 0;
  String backendUrl = 'http://192.168.1.10:8000';
  String apiToken = 'change-me';
  Map<String,dynamic>? signal;
  String connection = 'Connecting...';
  Timer? timer;

  @override void initState() {
    super.initState();
    fetchSignal();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchSignal());
  }

  @override void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> fetchSignal() async {
    try {
      final r = await http.get(
        Uri.parse(backendUrl + '/signal'),
        headers: <String,String>{'x-token': apiToken},
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      final v = jsonDecode(r.body);
      setState(() {
        signal = v is Map<String,dynamic> ? v : null;
        connection = r.statusCode == 200 ? 'Connected' : 'HTTP \${r.statusCode}';
      });
    } catch (_) {
      if (mounted) setState(() => connection = 'Backend not connected');
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(screens[selected]),
      actions: <Widget>[
        IconButton(onPressed: fetchSignal, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: openSettings, icon: const Icon(Icons.settings)),
      ],
    ),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.candlestick_chart, size: 42),
                  SizedBox(height: 10),
                  Text('NSE Algo Signal', style: TextStyle(fontSize: 22)),
                  Text('18-screen paper terminal'),
                ],
              ),
            ),
            for (int i=0; i<screens.length; i++)
              ListTile(
                leading: Icon(screenIcon(i)),
                title: Text(screens[i]),
                selected: selected == i,
                onTap: () { Navigator.pop(context); setState(() => selected = i); },
              ),
          ],
        ),
      ),
    ),
    body: buildScreen(),
  );

  static IconData screenIcon(int i) => const <IconData>[
    Icons.dashboard, Icons.show_chart, Icons.precision_manufacturing,
    Icons.notifications, Icons.analytics, Icons.star, Icons.search,
    Icons.candlestick_chart, Icons.table_chart, Icons.article, Icons.info,
    Icons.key, Icons.language, Icons.hub, Icons.storage, Icons.list_alt,
    Icons.tune, Icons.more_horiz
  ][i];

  Widget buildScreen() {
    if (selected == 0) return dashboard();
    if (selected == 3) return signals();
    if (selected == 11) return angelApi();
    if (selected == 16) return settingsPage();
    return placeholder(screens[selected]);
  }

  Widget dashboard() {
    final action = signal?['action']?.toString() ?? 'WAIT';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        infoCard('Backend', connection, connection == 'Connected' ? Colors.green : Colors.red),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                const Text('CURRENT SIGNAL'),
                const SizedBox(height: 10),
                Text(action.replaceAll('_',' '),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (signal != null) ...<Widget>[
                  row('Symbol', signal!['symbol']),
                  row('Spot', signal!['spot']),
                  row('Strike', '\${signal!['strike'] ?? '-'} \${signal!['type'] ?? ''}'),
                  row('Entry', signal!['entry']),
                  row('LTP', signal!['ltp']),
                  row('Stop Loss', signal!['sl']),
                  row('Target', signal!['target']),
                  row('Score', signal!['score']),
                ] else const Text('No live signal payload received.'),
              ],
            ),
          ),
        ),
        infoCard('Data policy','No fabricated market values. Paper signals only.',Colors.blue),
      ],
    );
  }

  Widget signals() {
    final action = signal?['action']?.toString() ?? 'WAIT';
    final raw = signal?['reasons'];
    final reasons = raw is List ? raw.map((e) => e.toString()).join('\n') : 'No live signal';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('Signals', style: TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        infoCard(action.replaceAll('_',' '),reasons,Colors.blue),
      ],
    );
  }

  Widget angelApi() => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      const Text('Angel API',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      infoCard('SmartAPI','Authentication is handled by the backend. Do not hard-code API key, PIN or TOTP.',Colors.blue),
      infoCard('Backend URL',backendUrl,Colors.blue),
    ],
  );

  Widget settingsPage() => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      const Text('Settings',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      infoCard('Backend URL',backendUrl,Colors.blue),
      infoCard('Mode','Paper signals only',Colors.orange),
      infoCard('Timeframes','1m 2m 3m 5m 10m 15m 30m 1h 2h 4h 1D',Colors.blue),
      infoCard('Indicators','8 EMA / 13 EMA',Colors.blue),
    ],
  );

  Widget placeholder(String title) => Center(
    child: Card(
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(screenIcon(selected),size:48),
            const SizedBox(height:12),
            Text(title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),
            const Text('Live values appear only after the corresponding real API/data source is connected.',textAlign:TextAlign.center),
          ],
        ),
      ),
    ),
  );

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
            TextField(controller:u,decoration:const InputDecoration(labelText:'Backend URL')),
            TextField(controller:k,obscureText:true,decoration:const InputDecoration(labelText:'API token')),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              setState(() { backendUrl=u.text.trim(); apiToken=k.text.trim(); });
              Navigator.pop(d);
              fetchSignal();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    u.dispose();
    k.dispose();
  }

  Widget infoCard(String title,String value,Color color) => Card(
    child: ListTile(
      leading: Icon(Icons.circle,color:color,size:13),
      title: Text(title),
      subtitle: Text(value),
    ),
  );

  Widget row(String label,dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical:4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label),
        Flexible(child:Text('\${value ?? '-'}',textAlign:TextAlign.right)),
      ],
    ),
  );
}
