String normalizeIndexName(String value) => value
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool indexMatches(String requested, String actual) {
  final r = normalizeIndexName(requested);
  final a = normalizeIndexName(actual);
  if (r == 'NIFTY50') return a == 'NIFTY' || a == 'NIFTY50' || a == 'NIFTYEQ' || a == 'NIFTY50EQ';
  if (r == 'BANKNIFTY') return a == 'BANKNIFTY' || a == 'NIFTYBANK';
  if (r == 'FINNIFTY') return a == 'FINNIFTY';
  if (r == 'MIDCAPSELECT') return a == 'MIDCAPSELECT' || a == 'MIDCPNIFTY';
  if (r == 'SENSEX') return a == 'SENSEX';
  if (r == 'BANKEX') return a == 'BANKEX';
  return a == r;
}

double? liquidityMetric(Map<String, dynamic> q) {
  for (final key in const ['volume', 'totalTradedVolume', 'buyQty', 'buyQuantity', 'sellQty', 'sellQuantity']) {
    final value = q[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  final buy = double.tryParse(q['buyQty']?.toString() ?? '');
  final sell = double.tryParse(q['sellQty']?.toString() ?? '');
  if (buy != null || sell != null) return (buy ?? 0) + (sell ?? 0);
  return null;
}

const int optionChainCount = 200;

String formatMarketPrice(dynamic value) {
  if (value == null) return '—';
  final n = double.tryParse(value.toString());
  return n == null ? value.toString() : n.toStringAsFixed(2);
}
