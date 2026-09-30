import 'package:flutter_test/flutter_test.dart';
import '../lib/market_features.dart';

void main() {
  test('matches Indian index symbols without confusing BANK NIFTY with NIFTY 50', () {
    expect(indexMatches('NIFTY 50', 'NIFTY-EQ'), isTrue);
    expect(indexMatches('NIFTY 50', 'BANKNIFTY'), isFalse);
    expect(indexMatches('BANK NIFTY', 'BANKNIFTY'), isTrue);
    expect(indexMatches('BANK NIFTY', 'NIFTY'), isFalse);
  });

  test('liquidityMetric uses real volume or buy/sell quantities', () {
    expect(liquidityMetric({'volume': 1250}), 1250.0);
    expect(liquidityMetric({'buyQty': 400, 'sellQty': 600}), 400.0);
    expect(liquidityMetric({'foo': 1}), isNull);
  });

  test('optionChainCount is production-sized', () {
    expect(optionChainCount, greaterThanOrEqualTo(100));
  });
}
