String normalizeIndexName(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool indexMatches(String indexName, String symbol) {
  final s = normalizeIndexName(symbol);
  switch (indexName) {
    case 'NIFTY 50':
      return s == 'NIFTY' || s.contains('NIFTY50');
    case 'BANK NIFTY':
      return s.contains('BANKNIFTY') || s.contains('NIFTYBANK');
    case 'FINNIFTY':
      return s.contains('FINNIFTY');
    case 'MIDCAP SELECT':
      return s.contains('MIDCP') || s.contains('MIDCAP');
    case 'SENSEX':
      return s.contains('SENSEX');
    case 'BANKEX':
      return s.contains('BANKEX');
  }
  return false;
}

double? liquidityMetric(Map<String, dynamic> row) {
  final volume = row['volume'] ?? row['tradeVolume'];
  if (volume is num && volume > 0) return volume.toDouble();

  final buy = row['buyQty'] ?? row['totalBuyQuantity'];
  final sell = row['sellQty'] ?? row['totalSellQuantity'];
  if (buy is num || sell is num) {
    final value = (buy is num ? buy.toDouble() : 0.0) +
        (sell is num ? sell.toDouble() : 0.0);
    if (value > 0) return value;
  }
  return null;
}

const int optionChainCount = 200;

String formatMarketPrice(dynamic value) {
  if (value is num) {
    final n = value.toDouble();
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }
  return (value ?? '—').toString();
}
