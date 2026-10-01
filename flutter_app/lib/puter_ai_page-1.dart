// lib/puter_ai_page.dart
//
// pubspec.yaml mein ye dependencies honi chahiye:
//   http: ^1.2.2
//   webview_flutter: ^4.9.0
//
// Backend ke routes neeche mcpPath / strategyPath mein apne routes se match karo.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class PuterAiPage extends StatefulWidget {
  // Widget class mein sirf final fields (const constructor ki wajah se)
  final String backendUrl;
  final String apiToken;
  final Map<String, dynamic>? initialSnapshot;

  const PuterAiPage({
    super.key,
    required this.backendUrl,
    required this.apiToken,
    this.initialSnapshot,
  });

  @override
  State<PuterAiPage> createState() => _PuterAiPageState();
}

class _PuterAiPageState extends State<PuterAiPage> {
  // ---- apne backend ke routes se match karo ----
  static const String mcpPath = '/api/mcp/context';
  static const String strategyPath = '/api/strategy';

  // Badalne wale fields State class mein rehte hain
  Map<String, dynamic> mcpContext = <String, dynamic>{};
  Map<String, dynamic> strategyContext = <String, dynamic>{};

  late final WebViewController _controller;
  bool _pageReady = false;
  String _status = 'Context load ho raha hai...';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _pageReady = true;
          _pushContext();
        },
      ))
      ..loadHtmlString(_html(), baseUrl: 'https://localhost/');
    _refresh();
  }

  Uri _uri(String path) {
    var b = widget.backendUrl.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'https://$b';
    }
    return Uri.parse('$b$path');
  }

  Future<void> _refresh() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (widget.apiToken.isNotEmpty)
        'Authorization': 'Bearer ${widget.apiToken}',
    };
    try {
      final res = await Future.wait([
        http.get(_uri(mcpPath), headers: headers).timeout(const Duration(seconds: 60)),
        http.get(_uri(strategyPath), headers: headers).timeout(const Duration(seconds: 60)),
      ]);
      final m = res[0];
      final s = res[1];
      if (m.statusCode == 200) {
        final x = jsonDecode(m.body);
        if (x is Map<String, dynamic>) mcpContext = x;
      }
      if (s.statusCode == 200) {
        final x = jsonDecode(s.body);
        if (x is Map<String, dynamic>) strategyContext = x;
      }
      _status = 'Context ready (MCP ${m.statusCode}, Strategy ${s.statusCode})';
    } catch (e) {
      _status = 'Context error: $e';
    }
    if (mounted) setState(() {});
    _pushContext();
  }

  void _pushContext() {
    if (!_pageReady) return;
    final payload = jsonEncode({
      'mcp': mcpContext,
      'strategy': strategyContext,
      'snapshot': widget.initialSnapshot ?? <String, dynamic>{},
    });
    // payload ko JS string literal bana kar bhejte hain
    _controller.runJavaScript('window.setContext && window.setContext(${jsonEncode(payload)});');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puter AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh context',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_status, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  // Raw string: andar ka HTML me kahin teen double-quotes (""" ) mat likhna.
  String _html() => r"""
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body{margin:0;font:14px system-ui,sans-serif;background:#0b1020;color:#e8ecf8;display:flex;flex-direction:column;height:100vh}
  #chat{flex:1;overflow:auto;padding:10px}
  .u{background:#2b3558;border-radius:10px;padding:8px 10px;margin:6px 0 6px 30px}
  .a{background:#141b30;border:1px solid #26304d;border-radius:10px;padding:8px 10px;margin:6px 30px 6px 0;white-space:pre-wrap}
  .bar{display:flex;gap:6px;padding:6px 10px;background:#0e1427;border-top:1px solid #26304d;align-items:center}
  input[type=text],select{flex:1;padding:10px;border-radius:8px;border:1px solid #26304d;background:#141b30;color:#e8ecf8;font-size:14px}
  button{padding:10px 14px;border:0;border-radius:8px;background:#7c6cf0;color:#fff;font-weight:600}
  label{font-size:12px;color:#8b96b8}
</style>
</head>
<body>
<div id="chat"><div class="a">NSE AI assistant ready. Market ya strategy ke baare mein poochho. (Paper trading / educational)</div></div>
<div class="bar">
  <select id="model">
    <option value="gpt-6.1-sol">gpt-6.1-sol</option>
    <option value="gpt-6-luna">gpt-6-luna</option>
    <option value="gpt-6-astra">gpt-6-astra</option>
  </select>
  <label><input type="checkbox" id="web" checked> Web</label>
</div>
<div class="bar">
  <input type="text" id="q" placeholder="NIFTY ka aaj ka view?">
  <button id="go">Send</button>
</div>
<script src="https://js.puter.com/v2/"></script>
<script>
  var ctx = {};
  window.setContext = function (s) { try { ctx = JSON.parse(s); } catch (e) {} };

  var chat = document.getElementById('chat');
  function add(cls, t) {
    var d = document.createElement('div');
    d.className = cls;
    d.textContent = t;
    chat.appendChild(d);
    d.scrollIntoView();
    return d;
  }
  function textOf(r) {
    if (r == null) return '';
    if (typeof r === 'string') return r;
    var c = r.message && r.message.content;
    if (typeof c === 'string') return c;
    if (Array.isArray(c)) return c.map(function (x) { return (x && x.text) || ''; }).join('');
    return r.text || JSON.stringify(r);
  }
  async function send() {
    var qEl = document.getElementById('q');
    var q = qEl.value.trim();
    if (!q) return;
    qEl.value = '';
    add('u', q);
    var wait = add('a', '...');
    var prompt = 'You are an NSE market assistant (paper trading, educational). ' +
      'Context JSON: ' + JSON.stringify(ctx).slice(0, 12000) +
      '\n\nQuestion: ' + q + '\nReply in short simple Hinglish.';
    var opts = { model: document.getElementById('model').value };
    if (document.getElementById('web').checked) opts.tools = [{ type: 'web_search' }];
    try {
      var r = await puter.ai.chat(prompt, opts);
      wait.textContent = textOf(r) || '(empty reply)';
    } catch (e) {
      wait.textContent = 'Error: ' + ((e && (e.message || (e.error && e.error.message))) || JSON.stringify(e));
    }
    wait.scrollIntoView();
  }
  document.getElementById('go').addEventListener('click', send);
  document.getElementById('q').addEventListener('keydown', function (e) { if (e.key === 'Enter') send(); });
</script>
</body>
</html>
""";
}
