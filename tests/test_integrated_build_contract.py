from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

class IntegratedBuildContractTests(unittest.TestCase):
    """Source-level guard: the integrated APK must retain the verified feature chain."""

    def test_signal_qualification_contract(self):
        src = read("signal_engine.py")
        self.assertIn('S368 CALL Qualification', src)
        self.assertIn('S369 PUT Qualification', src)
        self.assertIn('CALL BUY', src)
        self.assertIn('PUT BUY', src)
        self.assertIn('NO QUALIFYING TRADE', src)

    def test_six_layer_ai_validation_contract(self):
        src = read("signal_engine.py")
        self.assertIn('LAYERS=[', src)
        self.assertIn('Data collection', src)
        self.assertIn('Final risk audit', src)
        self.assertEqual(src.count('("Data collection",1)'), 1)
        self.assertEqual(src.count('("Final risk audit",6)'), 1)
        self.assertIn('validate(x)', src)
        self.assertIn('AI final WAIT override', src)

    def test_all_angel_data_endpoints_use_server_side_auto_login(self):
        src = read("backend/server.py")
        self.assertIn("def _ensure_angel():", src)
        self.assertRegex(src, r"def angel_required\(\):[\s\S]*?_ensure_angel\(\)")
        for endpoint in (
            '@app.get("/v1/angel/commodities")',
            '@app.get("/v1/angel/indices")',
            '@app.get("/v1/angel/market")',
            '@app.get("/v1/angel/candles")',
            '@app.get("/v1/angel/option-chain")',
            '@app.get("/v1/angel/oi")',
            '@app.get("/v1/angel/search")',
            '@app.get("/v1/angel/gainers-losers")',
            '@app.get("/v1/angel/oi-buildup")',
            '@app.get("/v1/angel/greeks")',
        ):
            self.assertIn(endpoint, src)
        for marker in ("ANGEL_API_KEY", "ANGEL_CLIENT_CODE", "ANGEL_PIN", "ANGEL_TOTP_SECRET"):
            self.assertIn(marker, read("backend/config.py"))

    def test_backend_terminal_contract(self):
        src = read("backend/server.py")
        for endpoint in (
            '@app.get("/health")',
            '@app.get("/v1/terminal")',
            '@app.get("/v1/angel/indices")',
            '@app.websocket("/v1/ws")',
        ):
            self.assertIn(endpoint, src)
        self.assertRegex(src, r'"orders_enabled"\s*:\s*False')
        self.assertRegex(src, r'"paper_only"\s*:\s*True')

    def test_live_pages_refresh_from_shared_backend_without_manual_page_action(self):
        src = read("flutter_app/lib/main.dart")
        start = src.find("marketTimer = Timer.periodic")
        timer_block = src[start:start + 420]
        self.assertIn("fetchIndices()", timer_block)
        self.assertIn("fetchCommodities()", timer_block)
        self.assertTrue(("if (selected == 3) fetchOptionRows()" in timer_block and "if (selected == 6) fetchOptionRows()" in timer_block) or "if (selected == 3 || selected == 6) fetchOptionRows()" in timer_block)
        self.assertIn("fetchAngelMarket()", src)
        self.assertIn("backendUri('/v1/angel/option-chain", src)
        self.assertIn("backendUri('/v1/angel/oi-buildup", src)

    def test_legacy_build_156_dashboard_contract(self):
        src = read("flutter_app/lib/dashboard_screen.dart")
        for marker in (
            "NSE Algo Signal",
            "Fast market workspace",
            "CURRENT SIGNAL",
            "QUICK ACCESS",
            "NSE SIGNAL FEED",
            "Data policy",
            "/v1/terminal",
            "/v1/angel/market",
        ):
            self.assertIn(marker, src)
        self.assertNotIn("webview_flutter", src)
        self.assertNotIn("PrototypE", src)

    def test_signal_tab_is_not_in_primary_navigation(self):
        src = read("flutter_app/lib/main.dart")
        start = src.find("static const screens = <String>[")
        end = src.find("];", start)
        nav = src[start:end]
        self.assertNotIn("'Signals'", nav)
        self.assertIn("'Market Terminal'", nav)
        self.assertIn("'Signal Flow'", nav)

    def test_market_terminal_is_first_screen(self):
        src = read("flutter_app/lib/main.dart")
        self.assertIn("'Market Terminal'", src)
        self.assertIn("if (selected == 0) return DashboardScreen(", src)
        self.assertNotIn("if (selected == 0) return dashboard();", src)

    def test_legacy_puter_signin_path_is_removed(self):
        src = read("flutter_app/lib/main.dart")
        self.assertNotIn("puter_ai_page.dart", src)
        self.assertNotIn("PuterAiPage", src)
        self.assertFalse((ROOT / "flutter_app/lib/puter_ai_page.dart").exists())

    def test_workflow_builds_and_verifies_apk(self):
        src = read(".github/workflows/build-apk.yml")
        for marker in (
            "flutter analyze",
            "Validate backend Python source",
            "Build installable APK",
            "test -f flutter_app/build/app/outputs/flutter-apk/app-debug.apk",
            "name: Parmar-Trading-APK",
        ):
            self.assertIn(marker, src)

    def test_native_android_build_does_not_depend_on_dart(self):
        workflow = read(".github/workflows/build-apk.yml")
        self.assertNotIn("subosito/flutter-action", workflow)
        self.assertNotIn("flutter create", workflow)
        self.assertIn("gradle", workflow)
        self.assertIn("assembleDebug", workflow)
        main = read("native_android/app/src/main/kotlin/com/parmar/trading/MainActivity.kt")
        self.assertIn("WebView", main)
        self.assertIn("android_asset/index.html", main)
        self.assertIn('com.parmar.trading', main)

if __name__ == "__main__":
    unittest.main()
