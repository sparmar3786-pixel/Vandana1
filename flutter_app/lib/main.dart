import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Terminal());
}

class Terminal extends StatefulWidget {
  const Terminal({super.key});
  @override
  State<Terminal> createState() => _S();
}

class _S extends State<Terminal> {
  String url = 'http://192.168.1.10:8000', token = 'change-me';
  Map<String, dynamic>? d;
  String? err;
  Timer? t;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      url = p.getString('url') ?? url;
      token = p.getString('token') ?? token;
      t = Timer.periodic(const Duration(seconds: 3), (_) => fetch());
      fetch();
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> fetch() async {
    try {
      final r = await http.get(Uri.parse('$url/signal'), headers: {'x-token': token})
          .timeout(const Duration(seconds: 5));
      setState(() {
        d = jsonDecode(r.body);
        err = null;
      });
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  Color col(String a) => a == 'BUY_CE' ? Colors.greenAccent : a == 'BUY_PE' ? Colors.redAccent
      : a == 'EXIT' ? Colors.orangeAccent : Colors.grey;

  Future<void> settings() async {
    final u = TextEditingController(text: url), k = TextEditingController(text: token);
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Server'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: u, decoration: const InputDecoration(labelText: 'Backend URL')),
        TextField(controller: k, decoration: const InputDecoration(labelText: 'API token')),
      ]),
      actions: [TextButton(onPressed: () async {
        final p = await SharedPreferences.getInstance();
        url = u.text; token = k.text;
        await p.setString('url', url); await p.setString('token', token);
        if (mounted) Navigator.pop(context);
        fetch();
      }, child: const Text('Save'))],
    ));
  }

  Widget row(String k, dynamic v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(k, style: const TextStyle(color: Colors.white60)),
            Text('$v', style: const TextStyle(fontWeight: FontWeight.bold))]));

  @override
  Widget build(BuildContext c) {
    final a = (d?['action'] ?? 'WAIT') as String;
    return Scaffold(
      appBar: AppBar(title: Text('${d?['symbol'] ?? 'ALGO'} Terminal'),
          actions: [IconButton(icon: const Icon(Icons.settings), onPressed: settings)]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (err != null) Text('Connection error: $err', style: const TextStyle(color: Colors.red)),
        if (d?['error'] != null) Text('Server: ${d!['error']}', style: const TextStyle(color: Colors.orange)),
        if (d != null && d!['market_open'] == false)
          const Text('Market closed', style: TextStyle(color: Colors.amber)),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text(a.replaceAll('_', ' '), style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: col(a))),
          const SizedBox(height: 8),
          if (d?['spot'] != null) row('Spot', d!['spot']),
          if (d?['strike'] != null) row('Strike', '${d!['strike']} ${d!['type'] ?? ''}'),
          if (d?['entry'] != null) row('Entry', d!['entry']),
          if (d?['ltp'] != null) row('LTP', d!['ltp']),
          if (d?['sl'] != null) row('Stoploss', d!['sl']),
          if (d?['target'] != null) row('Target', d!['target']),
          if (d?['pnl_pct'] != null) row('P&L %', d!['pnl_pct']),
          if (d?['score'] != null) row('Score', d!['score']),
          if (d?['ai_confidence'] != null) row('AI confidence', d!['ai_confidence']),
        ]))),
        if (d?['nse'] != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('NSE AI Trend', style: TextStyle(fontWeight: FontWeight.bold)),
          row('Trend', d!['nse']['trend']),
          row('P(up)', d!['nse']['p_up']),
          row('Source', d!['nse']['source']),
          row('PCR (OI)', d!['nse']['pcr']),
          row('Support (max PE OI)', d!['nse']['support']),
          row('Resistance (max CE OI)', d!['nse']['resistance']),
          row('Max pain', d!['nse']['max_pain']),
        ]))),
        if (d?['nse_error'] != null) Text('NSE: ${d!['nse_error']}', style: const TextStyle(color: Colors.orange)),
        const SizedBox(height: 8),
        const Text('Reasons', style: TextStyle(fontWeight: FontWeight.bold)),
        ...((d?['reasons'] as List?) ?? []).map((r) => Text('• $r')),
        const SizedBox(height: 16),
        const Text('Paper signals only. Yeh financial advice nahi hai.',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }
}
