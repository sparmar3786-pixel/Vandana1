import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  final ValueChanged<int>? onNavigate;

  const DashboardScreen({
    super.key,
    this.backendUrl = '',
    this.apiToken = '',
    this.onNavigate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> terminalData = <String, dynamic>{};
  List<dynamic> liveMarket = <dynamic>[];
  List<dynamic> liveOptionRows = <dynamic>[];
  String connection = 'Connecting...';
  bool busy = false;
  Timer? timer;

  Map<String, String> get headers => <String, String>{
        if (widget.apiToken.trim().isNotEmpty) 'x-token': widget.apiToken.trim(),
      };

  Uri backendUri(String path) => Uri.parse(
        widget.backendUrl.trim().replaceFirst(RegExp(r'/+$'), '') + path,
      );

  String value(dynamic value, [String fallback = '—']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> get signal {
    final raw = terminalData['signals'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  bool get nseConnected {
    final raw = terminalData['connection'];
    return raw is Map && raw['nse'] == true;
  }

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backendUrl != widget.backendUrl ||
        oldWidget.apiToken != widget.apiToken) {
      load();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (busy || widget.backendUrl.trim().isEmpty) return;
    busy = true;
    try {
      final responses = await Future.wait<http.Response>(<Future<http.Response>>[
        http.get(backendUri('/v1/terminal'), headers: headers)
            .timeout(const Duration(seconds: 6)),
        http.get(backendUri('/v1/angel/market'), headers: headers)
            .timeout(const Duration(seconds: 8)),
        http.get(
          backendUri('/v1/angel/option-chain?symbol=NIFTY&count=10'),
          headers: headers,
        ).timeout(const Duration(seconds: 10)),
      ]);

      if (!mounted) return;

      Map<String, dynamic> terminal = <String, dynamic>{};
      List<dynamic> market = <dynamic>[];
      List<dynamic> options = <dynamic>[];

      try {
        final decoded = jsonDecode(responses[0].body);
        if (decoded is Map) terminal = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      try {
        final decoded = jsonDecode(responses[1].body);
        if (decoded is Map && decoded['data'] is Map) {
          final fetched = decoded['data']['fetched'];
          if (fetched is List) market = List<dynamic>.from(fetched);
        } else if (decoded is Map && decoded['data'] is List) {
          market = List<dynamic>.from(decoded['data']);
        }
      } catch (_) {}

      try {
        final decoded = jsonDecode(responses[2].body);
        if (decoded is Map && decoded['rows'] is List) {
          options = List<dynamic>.from(decoded['rows']);
        }
      } catch (_) {}

      final conn = terminal['connection'];
      final angel = conn is Map && conn['angel'] == true;
      final server = conn is Map && conn['server'] == true;

      setState(() {
        terminalData = terminal;
        liveMarket = market;
        liveOptionRows = options;
        connection = responses[0].statusCode == 200 && server && angel
            ? 'Connected'
            : responses[0].statusCode == 200 && server
                ? 'Backend connected / Angel not connected'
                : 'HTTP ' + responses[0].statusCode.toString();
      });
    } catch (_) {
      if (mounted) setState(() => connection = 'Backend not connected');
    } finally {
      busy = false;
    }
  }

  Widget metricTile(String title, String text, IconData icon) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 520
          ? 180
          : (MediaQuery.of(context).size.width - 40) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoCard(String title, String text, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 13),
        title: Text(title),
        subtitle: Text(text),
      ),
    );
  }

  Widget row(String label, dynamic data) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label),
            Flexible(
              child: Text(
                (data ?? '—').toString(),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  void navigate(int page) => widget.onNavigate?.call(page);

  @override
  Widget build(BuildContext context) {
    final action = value(signal['action'], 'WAIT').replaceAll('_', ' ');
    final marketCount = liveMarket.length;
    final optionCount = liveOptionRows.length;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 22,
                    child: Icon(Icons.candlestick_chart),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'NSE Algo Signal',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Fast market workspace • 18 screens',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.blue.withOpacity(.12),
                    ),
                    child: Text(
                      connection,
                      style: TextStyle(
                        fontSize: 11,
                        color: connection == 'Connected'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              metricTile('Connection', connection, Icons.link),
              metricTile(
                'Indices',
                marketCount == 0 ? '—' : marketCount.toString(),
                Icons.show_chart,
              ),
              metricTile('Candles', '—', Icons.candlestick_chart),
              metricTile(
                'Option rows',
                optionCount == 0 ? '—' : optionCount.toString(),
                Icons.table_chart,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.bolt, size: 18),
                      const SizedBox(width: 7),
                      const Text(
                        'CURRENT SIGNAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: busy ? null : load,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh signal',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (signal.isNotEmpty) ...<Widget>[
                    row('Symbol', signal['symbol'] ?? signal['optionSymbol']),
                    row('Spot', signal['spot'] ?? signal['underlyingLtp']),
                    row('LTP', signal['ltp'] ?? signal['optionLtp']),
                    row('Strike', signal['strike']),
                    row('Entry', signal['entry']),
                    row('Stop Loss', signal['sl'] ?? signal['stopLoss']),
                    row('Target', signal['target']),
                  ] else
                    const Text(
                      'No live signal payload received.',
                      style: TextStyle(fontSize: 12),
                    ),
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
                  const Text(
                    'QUICK ACCESS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      ActionChip(
                        label: const Text('Indian Indices'),
                        avatar: const Icon(Icons.show_chart, size: 16),
                        onPressed: () => navigate(1),
                      ),
                      ActionChip(
                        label: const Text('Option Chain'),
                        avatar: const Icon(Icons.table_chart, size: 16),
                        onPressed: () => navigate(6),
                      ),
                      ActionChip(
                        label: const Text('Charts'),
                        avatar: const Icon(Icons.candlestick_chart, size: 16),
                        onPressed: () => navigate(5),
                      ),
                      ActionChip(
                        label: const Text('Strategies'),
                        avatar: const Icon(Icons.schema, size: 16),
                        onPressed: () => navigate(13),
                      ),
                      ActionChip(
                        label: const Text('NSE MCP'),
                        avatar: const Icon(Icons.hub, size: 16),
                        onPressed: () => navigate(11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                nseConnected
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color: nseConnected ? Colors.green : Colors.orange,
              ),
              title: const Text('NSE SIGNAL FEED'),
              subtitle: Text(
                signal['action']?.toString().replaceAll('_', ' ') ??
                    'WAIT • awaiting engine payload',
              ),
              trailing: IconButton(
                onPressed: busy ? null : load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          const SizedBox(height: 10),
          infoCard(
            'Data policy',
            'Real API/data only. No fabricated market values. Strategy engine remains evidence-gated.',
            Colors.blue,
          ),
        ],
      ),
    );
  }
}
