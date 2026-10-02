import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DashboardScreen extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  const DashboardScreen({super.key, this.backendUrl = '', this.apiToken = ''});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  String _jsValue(String value) => jsonEncode(value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          await _controller.runJavaScript(
            'window.DASH_API_BASE=\${_jsValue(widget.backendUrl)};'
            'window.DASH_TOKEN=\${_jsValue(widget.apiToken)};'
            'try{localStorage.setItem("dash_api_base",\${_jsValue(widget.backendUrl)});'
            'localStorage.setItem("dash_token",\${_jsValue(widget.apiToken)});}catch(e){}',
          );
          await _controller.runJavaScript(
            'if(window.bootstrapDashboard){window.bootstrapDashboard();}',
          );
        },
      ))
      ..loadFlutterAsset('assets/market_terminal_v2.html');
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backendUrl != widget.backendUrl || oldWidget.apiToken != widget.apiToken) {
      _controller.runJavaScript(
        'window.DASH_API_BASE=\${_jsValue(widget.backendUrl)};'
        'window.DASH_TOKEN=\${_jsValue(widget.apiToken)};'
        'try{localStorage.setItem("dash_api_base",\${_jsValue(widget.backendUrl)});'
        'localStorage.setItem("dash_token",\${_jsValue(widget.apiToken)});}catch(e){}',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.runJavaScript('document.dispatchEvent(new Event("visibilitychange"));');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
