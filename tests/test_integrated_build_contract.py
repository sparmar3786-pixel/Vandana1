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
        self.assertIn("ANGEL_API_KEY", read("backend/config.py"))
        self.assertIn("ANGEL_CLIENT_CODE", read("backend/config.py"))
        self.assertIn("ANGEL_PIN", read("backend/config.py"))
        self.assertIn("ANGEL_TOTP_SECRET", read("backend/config.py"))

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
        self.assertTrue(("if (selected == 4) fetchOptionRows()" in timer_block and "if (selected == 7) fetchOptionRows()" in timer_block) or "if (selected == 4 || selected == 7) fetchOptionRows()" in timer_block)
        self.assertIn("fetchAngelMarket()", src)
        self.assertIn("backendUri('/v1/angel/option-chain", src)
        self.assertIn("backendUri('/v1/angel/oi-buildup", src)

    def test_market_terminal_is_first_screen(self):
        src = read("flutter_app/lib/main.dart")
        self.assertIn("'Market Terminal'", src)
        self.assertIn("if (selected == 0) return DashboardScreen(", src)
        self.assertNotIn("if (selected == 0) return dashboard();", src)

    def test_dashboard_uses_live_backend_and_no_demo_feed(self):
        src = read("flutter_app/assets/dashboard.html")
        for marker in (
            'Market Terminal',
            'data-ex="ALL"',
            'data-ex="NSE"',
            'data-ex="BSE"',
            '/health',
            '/v1/angel/indices',
            'window.bootstrapDashboard',
            'Fake prices are disabled',
            'no demo data',
        ):
            self.assertIn(marker.lower(), src.lower())
        self.assertNotIn('fake prices are enabled', src.lower())

    def test_dashboard_keeps_last_successful_fetch_when_live_is_unavailable(self):
        src = read("flutter_app/assets/dashboard.html").lower()
        self.assertIn("localstorage.setitem('market_last_rows'", src)
        self.assertIn("localstorage.getitem('market_last_rows'", src)
        self.assertIn("last fetched", src)
        self.assertIn("market_last_fetched", src)
        self.assertIn("using last fetched data", src)

    def test_signals_screen_uses_live_angel_nse_mcp_and_last_fetch_fallback(self):
        src = read("flutter_app/assets/signals_v2.html").lower()
        for marker in (
            "/v1/terminal",
            "/v1/ws",
            "/v1/angel/status",
            "/v1/nse/mcp/context",
            "angel one",
            "nse mcp",
            "localstorage.setitem('signals_last_frame'",
            "localstorage.getitem('signals_last_frame'",
            "market closed",
            "last fetched",
        ):
            self.assertIn(marker, src)
        self.assertNotIn("synthetic data", src)
        self.assertNotIn("demo stream", src)

    def test_signals_screen_is_wired_to_asset(self):
        src = read("flutter_app/lib/signals_screen.dart")
        self.assertIn("assets/signals_v2.html", src)
        self.assertIn("window.bootstrapSignals", src)

    def test_legacy_puter_signin_path_is_removed(self):
        src = read("flutter_app/lib/main.dart")
        self.assertNotIn("puter_ai_page.dart", src)
        self.assertNotIn("PuterAiPage", src)
        self.assertFalse((ROOT / "flutter_app/lib/puter_ai_page.dart").exists())

    def test_workflow_builds_and_verifies_apk(self):
        src = read(".github/workflows/build-apk.yml")
        for marker in (
            "flutter analyze",
            "Run backend data-layer regression tests",
            "Build installable APK",
            "test -f flutter_app/build/app/outputs/flutter-apk/app-debug.apk",
            "name: Parmar-Trading-APK",
        ):
            self.assertIn(marker, src)

if __name__ == "__main__":
    unittest.main()
