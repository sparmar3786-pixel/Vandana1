import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  final String backendUrl;
  final String apiToken;

  const DashboardScreen({
    super.key,
    this.backendUrl = '',
    this.apiToken = '',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _terminal;
  String _connection = 'Connecting...';
  bool _busy = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchTerminal();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchTerminal();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backendUrl != widget.backendUrl ||
        oldWidget.apiToken != widget.apiToken) {
      _fetchTerminal();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Uri _uri(String path) {
    final base = widget.backendUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse(base + path);
  }

  Future<void> _fetchTerminal() async {
    if (_busy || widget.backendUrl.trim().isEmpty) return;
    _busy = true;
    try {
      final response = await http.get(
        _uri('/v1/terminal'),
        headers: <String, String>{'x-token': widget.apiToken},
      ).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final connection = data['connection'];
      final angel = connection is Map && connection['angel'] == true;
      setState(() {
        _terminal = data;
        _connection = response.statusCode == 200 && angel
            ? 'Connected'
            : response.statusCode == 200
                ? 'Backend connected / Angel not connected'
                : 'HTTP ${response.statusCode}';
      });
    } catch (_) {
      if (mounted) setState(() => _connection = 'Backend not connected');
    } finally {
      _busy = false;
    }
  }

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'DATA UNAVAILABLE';
    }
    return value.toString();
  }

  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
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
      child: Row(
        children: <Widget>[
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
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
                    Row(
                      children: <Widget>[
                        const Icon(Icons.bolt, size: 30),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'NSE Algo Signal',
                            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          backgroundColor: accent,
                          label: Text(
                            marketOpen ? trend : 'MARKET CLOSED',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
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
                    const Text('CURRENT ENGINE STATE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    const Text('SIGNAL DETAILS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    _row('Option Symbol', engine['option_symbol']),
                    _row('Entry', engine['entry']),
                    _row('Stop Loss', engine['stop_loss']),
                    _row('Target', engine['target']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _infoCard(
              'Connection',
              _connection,
              _connection == 'Connected' ? Colors.green : Colors.orange,
            ),
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
