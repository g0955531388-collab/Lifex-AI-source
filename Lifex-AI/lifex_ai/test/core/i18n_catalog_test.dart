import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('كل مفتاح في ar.json له نظير في en.json والعكس', () {
    final ar = jsonDecode(File('assets/i18n/ar.json').readAsStringSync()) as Map;
    final en = jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map;
    expect(ar.keys.toSet(), en.keys.toSet());
    expect(ar.keys, isNotEmpty);
  });
}
