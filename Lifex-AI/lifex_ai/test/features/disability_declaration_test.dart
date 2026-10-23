import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/disability_declaration.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';

void main() {
  test('تصريح الإعاقة يُحفظ ولا يرتّب التبرع', () {
    final branch = UnitBranchCatalog.forUnit('chronicPlans')
        .firstWhere((item) => item.id == 'disability');
    expect(branch.storageKey, 'disabilitySelfRecords');
    for (final type in DisabilityDeclaration.types) {
      expect(branch.primaryLabelAr, contains(type));
    }

    final row = DisabilityDeclaration.tryParse('بصرية', '40');
    expect(row?.type, 'بصرية');
    expect(row?.declaredPercent, 40);
    expect(row?.donationRank(), isNull);
    expect(DisabilityDeclaration.percentIsCertificate, isFalse);
    expect(DisabilityDeclaration.donationRankAllowed, isFalse);
    expect(DisabilityDeclaration.tryParse('بصرية', '140'), isNull);
    expect(DisabilityDeclaration.tryParse('غير معروف', '10'), isNull);
  });
}
