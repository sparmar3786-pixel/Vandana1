import 'package:flutter_test/flutter_test.dart';
import '../lib/market_features.dart';

void main() {
  test('matches Indian index symbols without confusing BANK NIFTY with NIFTY 50', () {
    expect(indexMatches('NIFTY 50', 'NIFTY-EQ'), isTrue);
    expect(indexMatches('BANK NIFTY', 'BANKNIFTY'), isTrue);
    expect(indexMatches('BANK NIFTY', 'NIFTY'), isFalse);
    expect(indexMatches('SENSEX', 'SENSEX'), isTrue);
  });

  test('uses real volume or buy/sell quantities for liquidity and never invents a value', () {
    expect(liquidityMetric({'tradeVolume': 1200}), 1200);
    expect(liquidityMetric({'totalBuyQuantity': 500, 'totalSellQuantity': 700}), 1200);
    expect(liquidityMetric({'ltp': 22600}), isNull);
  });

  test('requests a broad option-chain window instead of only 10 strikes', () {
    expect(optionChainCount, greaterThanOrEqualTo(100));
  });
}
