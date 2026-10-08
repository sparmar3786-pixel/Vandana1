import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Server-side 6-AI validation.
/// Provider Access Keys are submitted over HTTPS and retained only in backend memory.
const Map<String, String> _kEnv = <String, String>{
  'gpt56-luna': 'OPENAI_API_KEY',
  'gpt56-sol': 'OPENAI_API_KEY',
  'claude-sonnet': 'ANTHROPIC_API_KEY',
  'deepseek': 'DEEPSEEK_API_KEY',
  'gemini-flash': 'GEMINI_API_KEY',
  'grok-4': 'XAI_API_KEY',
};

class AiValidatePage extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  final String symbol;
  const AiValidatePage({
    super.key,
    required this.backendUrl,
    required this.apiToken,
    this.symbol = 'NIFTY',
  });

  @override
  State<AiValidatePage> createState() => _AiValidatePageState();
}

class _AiValidatePageState extends State<AiValidatePage> {
  bool running = false;
  bool auto = false;
  String status = 'Tap RUN 6-AI VALIDATION. API keys stay on the Railway server.';
  Map<String, dynamic> ctx = <String, dynamic>{};
  Map<String, dynamic> result = <String, dynamic>{};
  final Set<String> expanded = <String>{};
  final accessKey = TextEditingController();
  String selectedProvider = 'gpt56-luna';
  List<dynamic> providerConfig = <dynamic>[];
  bool keyBusy = false;
  Timer? timer;

  String get _base => widget.backendUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        if (widget.apiToken.trim().isNotEmpty) 'x-token': widget.apiToken.trim(),
      };

  Map<String, dynamic> _m(dynamic x) =>
      x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
  List<dynamic> _l(dynamic x) => x is List ? x : <dynamic>[];

  String _err(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map) {
        final x = d['detail'] ?? d['message'];
        if (x is Map) {
          return (x['message'] ?? x['code'] ?? 'HTTP ${r.statusCode}').toString();
        }
        if (x != null) return x.toString();
      }
    } catch (_) {}
    return 'HTTP ${r.statusCode}';
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void initState() {
    super.initState();
    loadProviders();
    loadContext();
  }

  @override
  void dispose() {
    timer?.cancel();
    accessKey.dispose();
    super.dispose();
  }

  Future<void> loadProviders() async {
    if (_base.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('$_base/v1/ai/providers'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 && mounted) {
        final d = _m(jsonDecode(r.body));
        setState(() => providerConfig = _l(d['providers']));
      }
    } catch (_) {}
  }

  Future<void> saveAccessKey() async {
    final key = accessKey.text.trim();
    if (key.length < 8) {
      setState(() => status = 'Enter a valid AI Access Key.');
      return;
    }
    setState(() {
      keyBusy = true;
      status = 'Securing AI Access Key on backend...';
    });
    try {
      final r = await http.post(
        Uri.parse('$_base/v1/ai/access-key'),
        headers: _headers,
        body: jsonEncode(<String, String>{
          'providerId': selectedProvider,
          'accessKey': key,
        }),
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception(_err(r));
      accessKey.clear();
      await loadProviders();
      if (mounted) setState(() => status = 'AI Access Key connected • stored in backend memory only.');
    } catch (e) {
      if (mounted) setState(() => status = 'AI Access Key error: ' + _clean(e));
    } finally {
      if (mounted) setState(() => keyBusy = false);
    }
  }

  Future<Map<String, dynamic>?> loadContext() async {
    if (_base.isEmpty) {
      if (mounted) setState(() => status = 'Backend URL is not configured (Settings).');
      return null;
    }
    try {
      final sym = Uri.encodeQueryComponent(widget.symbol.toUpperCase());
      final r = await http
          .get(Uri.parse('$_base/v1/ai/context?index=$sym'), headers: _headers)
          .timeout(const Duration(seconds: 40));
      if (r.statusCode != 200) throw Exception(_err(r));
      final c = _m(jsonDecode(r.body));
      if (mounted) setState(() => ctx = c);
      return c;
    } catch (e) {
      if (mounted) setState(() => status = 'Context error: ${_clean(e)}');
      return null;
    }
  }

  Future<void> run() async {
    if (running) return;
    setState(() {
      running = true;
      status = 'Collecting Angel API + NSE MCP + official NSE evidence...';
    });
    try {
      final c = await loadContext();
      if (c == null) return;
      if (mounted) setState(() => status = 'Six AI models are analysing on the server...');
      final r = await http
          .post(
            Uri.parse('$_base/v1/ai/validate'),
            headers: _headers,
            body: jsonEncode(<String, dynamic>{'payload': c}),
          )
          .timeout(const Duration(seconds: 90));
      if (r.statusCode != 200) throw Exception(_err(r));
      final v = _m(jsonDecode(r.body));
      if (!mounted) return;
      final t = DateTime.now();
      setState(() {
        result = v;
        status = 'Done at ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
            ' • ${v['successful'] ?? 0}/${v['total'] ?? 6} AI responded';
      });
    } catch (e) {
      if (mounted) setState(() => status = 'Error: ${_clean(e)}');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  Color _stateColor(String s) {
    final u = s.toUpperCase();
    if (u.contains('CALL')) return Colors.green;
    if (u.contains('PUT')) return Colors.red;
    if (u.contains('WAIT') || u.contains('NO QUALIFYING')) return Colors.orange;
    return Colors.blue;
  }

  Widget _src(String title, bool? ok) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  ok == null ? 'checking' : (ok ? 'CONNECTED' : 'NOT CONNECTED'),
                  style: TextStyle(fontSize: 12, color: ok == true ? Colors.green : Colors.orange),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _provider(dynamic raw) {
    final p = _m(raw);
    final id = (p['id'] ?? '').toString();
    final st = (p['status'] ?? '').toString();
    final ok = st == 'ok';
    final open = expanded.contains(id);
    final text = (p['text'] ?? '').toString().replaceAll(r'\n', '\n');
    final err = (p['error'] ?? '').toString();
    final body = ok
        ? text
        : (st == 'not_configured'
            ? 'Add ${_kEnv[id] ?? 'the provider API key'} in the Railway variables.'
            : (err.isEmpty ? 'No response.' : err));
    final color = ok ? Colors.green : (st == 'not_configured' ? Colors.orange : Colors.red);
    return Card(
      child: InkWell(
        onTap: () => setState(() {
          if (open) {
            expanded.remove(id);
          } else {
            expanded.add(id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      (p['name'] ?? id).toString(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    st.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${p['model'] ?? ''} • ${p['role'] ?? ''} • ${p['elapsed_ms'] ?? 0} ms',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                maxLines: open ? null : 4,
                overflow: open ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(open ? 'tap to collapse' : 'tap to expand', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provs = _l(result['providers']);
    final fin = (result['final'] ?? '').toString();
    final me = _m(ctx['market_evidence']);
    final src = _m(ctx['three_sources']);
    bool? flag(String k) => ctx.isEmpty ? null : _m(src[k])['connected'] == true;
    final local = _m(result['local_fallback']);
    final localText = (local['text'] ?? '').toString().replaceAll(r'\n', '\n');

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        const Text(
          'AI Models • 6-AI Validation',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('Server-side • Angel API + NSE MCP + official NSE evidence • paper only'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('AI ACCESS KEY', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Choose a provider and connect its Access Key. The key is not returned to the APK or written to Git.'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedProvider,
                  decoration: const InputDecoration(labelText: 'AI Provider', border: OutlineInputBorder()),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'gpt56-luna', child: Text('GPT-5.6 Luna / OpenAI')),
                    DropdownMenuItem(value: 'gpt56-sol', child: Text('GPT-5.6 Sol / OpenAI')),
                    DropdownMenuItem(value: 'claude-sonnet', child: Text('Claude Sonnet')),
                    DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek Chat')),
                    DropdownMenuItem(value: 'gemini-flash', child: Text('Gemini Flash')),
                    DropdownMenuItem(value: 'grok-4', child: Text('Grok 4')),
                  ],
                  onChanged: keyBusy ? null : (v) { if (v != null) setState(() => selectedProvider = v); },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accessKey,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'AI Access Key',
                    hintText: 'Paste provider API / Access Key',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: keyBusy ? null : saveAccessKey,
                    icon: const Icon(Icons.vpn_key),
                    label: Text(keyBusy ? 'CONNECTING...' : 'CONNECT AI ACCESS KEY'),
                  ),
                ),
                if (providerConfig.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    providerConfig.map((p) => _m(p)['name'].toString() + ': ' + ((_m(p)['configured'] == true) ? 'READY' : 'NOT SET')).join('  •  '),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: running ? null : run,
                icon: const Icon(Icons.play_arrow),
                label: Text(running ? 'RUNNING...' : 'RUN 6-AI VALIDATION'),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('AUTO 90s'),
              selected: auto,
              onSelected: (v) {
                setState(() => auto = v);
                timer?.cancel();
                if (v) {
                  timer = Timer.periodic(const Duration(seconds: 90), (_) => run());
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(status),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            _src('ANGEL API', flag('angel_api')),
            _src('NSE MCP', flag('nse_mcp')),
            _src('NSE SITE', flag('nse_internet')),
          ],
        ),
        Text(
          'Symbol ${me['index'] ?? widget.symbol} • Spot ${me['spot'] ?? '-'} • ATM ${me['atm'] ?? '-'}'
          ' • PCR ${me['pcr'] ?? '-'} • Support ${me['support'] ?? '-'} • Resistance ${me['resistance'] ?? '-'}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (fin.isNotEmpty)
          Card(
            color: _stateColor(fin).withValues(alpha: .12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'FINAL: $fin',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _stateColor(fin),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text((result['reason'] ?? '').toString()),
                  const SizedBox(height: 6),
                  Text(
                    '${result['successful'] ?? 0}/${result['total'] ?? 6} AI completed'
                    ' • cross-verified: ${result['cross_verified'] == true ? 'YES' : 'NO'}'
                    ' • mode: ${result['mode'] ?? '-'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ...provs.map(_provider),
        if (localText.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'LOCAL FALLBACK (not a 6-AI consensus)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(localText),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Missing or conflicting evidence forces WAIT. No orders are placed.',
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
