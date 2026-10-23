import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/vaccine_name_index.dart';

void main() {
  test('فهرس اللقاح يطابق الاسم ولا يحسب استحقاقاً', () {
    final json = jsonDecode(
      File('lib/data/reference/vaccine_name_index.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(json['due_calculation_allowed'], isFalse);
    expect(json['mandatory_flag_allowed'], isFalse);
    expect(json['dosing_advice_allowed'], isFalse);
    expect(json['early_dose_alert_allowed'], isFalse);
    expect(json.containsKey('country_code'), isFalse);

    final encoded = jsonEncode(json['vaccines']);
    expect(encoded.contains('doses_required'), isFalse);
    expect(encoded.contains('mandatory'), isFalse);
    expect(encoded.contains('age_in_months'), isFalse);

    final index = VaccineNameIndex.fromJson(json);
    expect(VaccineNameIndex.dueCalculationAllowed, isFalse);
    expect(index.find('BCG')?.vaccineId, 'BCG_01');
    expect(index.find('لقاح السل')?.vaccineId, 'BCG_01');
    expect(index.find('لقاح شلل الأطفال المعطل')?.vaccineId, 'POLIO_IPV_01');
    expect(index.find('OPV'), isNull);
    expect(VaccineNameIndex.earlyDoseAlertAllowed, isFalse);
    final matched = index.matchRecorded(['لقاح السل', 'ملاحظة شخصية']);
    expect(matched.map((item) => item.vaccineId), ['BCG_01']);
  });
}
