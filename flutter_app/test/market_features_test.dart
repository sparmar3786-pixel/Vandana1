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

  test('trend and option movement are derived from live values', () {
    expect(trendState({'percentChange': 1.2}, marketClosed: false), 'UP');
    expect(trendState({'percentChange': -1.2}, marketClosed: false), 'DOWN');
    expect(trendState({'percentChange': 1.2}, marketClosed: true), 'CLOSE');
    expect(optionMoveState({'oiChange': 10, 'priceChange': -2}), 'OI↑ PRICE↓');
    expect(optionMoveState({'oiChange': 10, 'priceChange': 2}), 'OI↑ PRICE↑');
    expect(optionMoveState({'oiChange': -10, 'priceChange': -2}), 'OI↓ PRICE↓');
  });

  test('priority only exists when a real score is supplied', () {
    expect(optionPriority({'signalScore': 91}), 1);
    expect(optionPriority({'signalScore': 68}), 4);
    expect(optionPriority({'oiChange': 10}), isNull);
  });

  test('optionChainCount is production-sized', () {
    expect(optionChainCount, greaterThanOrEqualTo(100));
  });
}
