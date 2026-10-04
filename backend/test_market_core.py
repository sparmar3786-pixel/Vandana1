import os,sys,time,unittest
sys.path.insert(0,"backend")
os.environ["MCP_AUTH_TOKEN"]="test-token"
from market_core import STORE,put,put_spot,snapshot,evidence

class MarketCoreTests(unittest.TestCase):
    def setUp(self):
        """Clear shared market data before each test."""
        STORE.clear()
    def test_newer_timestamp_wins(self):
        """Verify that an older NSE spot update cannot replace a newer Angel value."""
        put_spot("NIFTY",100,"angel_ws",200)
        self.assertFalse(put_spot("NIFTY",101,"nse",199))
        self.assertEqual(snapshot("NIFTY")["spot"],100.0)
    def test_freshness_and_evidence(self):
        """Verify that a fresh spot and four fresh legs enable data readiness and PCR."""
        put_spot("NIFTY",100,"angel_ws",time.time())
        for i,side in enumerate(["CE","PE","CE","PE"],1):
            put("NIFTY",100+i,side,"angel_ws",time.time(),ltp=i,oi=100*i)
        self.assertTrue(snapshot("NIFTY")["data_ok"])
        self.assertIsNotNone(evidence("NIFTY")["pcr"])
    def test_stale_blocks_data_ok(self):
        """Verify that stale spot and option data prevent data readiness."""
        put_spot("NIFTY",100,"angel_ws",time.time()-30)
        for i,side in enumerate(["CE","PE","CE","PE"],1):
            put("NIFTY",100+i,side,"angel_ws",time.time()-30,oi=100)
        self.assertFalse(snapshot("NIFTY")["data_ok"])

if __name__=="__main__":
    unittest.main()
