import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController _controller;

  String _jsString(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  String _bootstrap() {
    final base = _jsString(widget.backendUrl);
    final token = _jsString(widget.apiToken);
    return "window.DASH_API_BASE='$base';"
        "window.DASH_TOKEN='$token';"
        "try{localStorage.setItem('dash_api_base','$base');"
        "localStorage.setItem('dash_token','$token');}catch(e){}"
        "if(window.bootstrapDashboard){window.bootstrapDashboard();}";
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _controller.runJavaScript(_bootstrap());
          },
        ),
      )
      ..loadFlutterAsset('assets/dashboard.html');
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backendUrl != widget.backendUrl ||
        oldWidget.apiToken != widget.apiToken) {
      _controller.runJavaScript(_bootstrap());
    }
  }

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: _controller);
}
