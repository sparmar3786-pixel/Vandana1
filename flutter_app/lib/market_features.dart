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

String trendState(Map<String, dynamic> q, {required bool marketClosed}) {
  if (marketClosed) return 'CLOSE';
  final raw = q['percentChange'] ?? q['netChange'] ?? q['change'];
  final n = double.tryParse(raw?.toString().replaceAll('%', '') ?? '');
  if (n != null) return n > 0 ? 'UP' : n < 0 ? 'DOWN' : 'FLAT';
  return 'UNKNOWN';
}

double? numericField(Map<String, dynamic> q, List<String> keys) {
  for (final key in keys) {
    final v = q[key];
    if (v is num) return v.toDouble();
    final n = double.tryParse(v?.toString().replaceAll('%', '') ?? '');
    if (n != null) return n;
  }
  return null;
}

String optionMoveState(Map<String, dynamic> q) {
  final oi = numericField(q, const ['oiChange', 'netChangeOpnInterest', 'oi_change']);
  final price = numericField(q, const ['priceChange', 'netChange', 'change']);
  if (oi == null || price == null) return 'WAIT';
  if (oi > 0 && price > 0) return 'OI↑ PRICE↑';
  if (oi > 0 && price < 0) return 'OI↑ PRICE↓';
  if (oi < 0 && price < 0) return 'OI↓ PRICE↓';
  if (oi < 0 && price > 0) return 'OI↓ PRICE↑';
  return 'FLAT';
}

int? optionPriority(Map<String, dynamic> q) {
  final score = numericField(q, const ['signalScore', 'score', 'priorityScore']);
  if (score == null) return null;
  if (score >= 90) return 1;
  if (score >= 80) return 2;
  if (score >= 70) return 3;
  if (score >= 60) return 4;
  if (score >= 50) return 5;
  return null;
}

bool isIndianMarketClosed(DateTime nowIst) {
  final weekday = nowIst.weekday;
  if (weekday == DateTime.saturday || weekday == DateTime.sunday) return true;
  final minutes = nowIst.hour * 60 + nowIst.minute;
  return minutes < 9 * 60 + 15 || minutes > 15 * 60 + 30;
}
