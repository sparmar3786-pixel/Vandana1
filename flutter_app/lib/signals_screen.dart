import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SignalsScreen extends StatefulWidget {
  final String backendUrl;
  final String apiToken;
  const SignalsScreen({super.key, this.backendUrl = '', this.apiToken = ''});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  late final WebViewController _controller;

  String _js(String value) => jsonEncode(value);

  String _bootstrap() =>
      'window.DASH_API_BASE=' + _js(widget.backendUrl) + ';'
      'window.DASH_TOKEN=' + _js(widget.apiToken) + ';'
      'try{localStorage.setItem("dash_api_base",' + _js(widget.backendUrl) + ');'
      'localStorage.setItem("dash_token",' + _js(widget.apiToken) + ');}catch(e){}';

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
            await _controller.runJavaScript(
              'if(window.bootstrapSignals){window.bootstrapSignals();}',
            );
          },
        ),
      )
      ..loadFlutterAsset('assets/signals_v2.html');
  }

  @override
  void didUpdateWidget(covariant SignalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backendUrl != widget.backendUrl ||
        oldWidget.apiToken != widget.apiToken) {
      _controller.runJavaScript(_bootstrap());
      _controller.runJavaScript(
        'if(window.bootstrapSignals){window.bootstrapSignals();}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
