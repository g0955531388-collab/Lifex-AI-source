import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('قاموس القياسات يسمي القياس ولا يعتمد جدولاً رقمياً ملصوقاً', () {
    final json = jsonDecode(
      File('lib/data/medical/Lifex_AI_Human_Biometric_Measurements_v1.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final rows = (json['measurements'] as List).cast<Map>();
    expect(json['record_count'], rows.length);
    expect(json['data_governance']['no_automatic_diagnosis'], isTrue);

    final byKey = {for (final row in rows) row['key']: row};
    expect(byKey['head_circumference'], isNotNull);
    expect(byKey['alt'], isNotNull);
    expect(byKey['urine_color'], isNotNull);
    expect(byKey['semen_volume'], isNotNull);
    expect(byKey.containsKey('0-1 month'), isFalse);

    final urine = byKey['urine_color']!;
    expect('${urine['interpretation_note_ar']}', contains('ليس تشخيصاً'));
    expect(urine.containsKey('normal_range'), isFalse);
    expect('${urine}'.contains('Yellow'), isFalse);

    final encoded = jsonEncode(json);
    expect(encoded.contains('120/80'), isFalse);
    expect(encoded.contains('7-55'), isFalse);
    expect(encoded.contains('0-1 month'), isFalse);
  });
}
