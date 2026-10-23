import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/providers/laboratory_desk.dart';

void main() {
  test('بانر المختبر بلا مثال شخص ولا نتيجة جاهزة', () {
    final branch = UnitBranchCatalog.forUnit('labs')
        .firstWhere((item) => item.id == 'publicLab');
    expect(branch.subtitleAr, contains(LaboratoryDesk.bannerAr));
    expect(branch.extraFields.map((field) => field.key), contains('place'));
    expect(branch.extraFields.map((field) => field.key), contains('research'));
    expect(LaboratoryDesk.sampleProfileAllowed, isFalse);
    expect(LaboratoryDesk.resultIsDiagnosis, isFalse);
    expect(LaboratoryDesk.normalResultPresetAllowed, isFalse);
    expect(LaboratoryDesk.placeFollowsLocationSystem, isTrue);
    final footer = LaboratoryDesk.shareFooter();
    expect(footer, contains('الملكية والشراكة مناصفة'));
    expect(footer.contains('النور'), isFalse);
    expect(footer.contains('98765'), isFalse);
    expect(footer.contains('طبيعية'), isFalse);
    expect(footer.contains('المرشد'), isFalse);
    expect(footer.contains('33.8938'), isFalse);
  });
}
