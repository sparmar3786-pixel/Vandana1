import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _controller=WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setBackgroundColor(Colors.transparent)..loadFlutterAsset('assets/dashboard.html'); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if(state==AppLifecycleState.resumed){ _controller.runJavaScript('document.dispatchEvent(new Event("visibilitychange"));'); } }
  @override void dispose(){ WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override Widget build(BuildContext context)=>WebViewWidget(controller:_controller);
}
