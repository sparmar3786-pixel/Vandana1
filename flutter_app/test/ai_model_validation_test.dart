import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('six-AI Puter validation source keeps all six labels and reject-safe resolution', () {
    final source = File('lib/main.dart').readAsStringSync();
    for (final label in [
      'GPT-5.6 Luna',
      'Claude Sonnet 4.6',
      'GPT-5.6 Sol',
      'DeepSeek Chat',
      'Gemini 2.5 Flash',
      'Grok 4',
    ]) {
      expect(source, contains(label));
    }
    expect(source, contains('puter.ai.listModels()'));
    expect(source, contains("return null;"));
    expect(source, contains('MODEL UNAVAILABLE IN PUTER CATALOG'));
    expect(source, contains('MODEL REQUEST REJECTED'));
    expect(source, isNot(contains('three-layer')));
    expect(source, isNot(contains('THREE-LAYER')));
  });
}
