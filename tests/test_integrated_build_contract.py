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

    def test_backend_terminal_contract(self):
        src = read("backend/server.py")
        for endpoint in (
            '@app.get("/health")',
            '@app.get("/v1/terminal")',
            '@app.get("/v1/angel/indices")',
            '@app.websocket("/v1/ws")',
        ):
            self.assertIn(endpoint, src)
        self.assertIn('"orders_enabled":False', src)
        self.assertIn('"paper_only":True', src)

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

    def test_signals_screen_is_wired_to_asset(self):
        src = read("flutter_app/lib/signals_screen.dart")
        self.assertIn("assets/signals_v2.html", src)
        self.assertIn("window.bootstrapSignals", src)

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
