import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/providers/doctor_desk.dart';

void main() {
  test('ملف الطبيب بلا مثال ولا لوحة ويب', () {
    final branch = UnitBranchCatalog.forUnit('doctors')
        .firstWhere((item) => item.id == 'publicCv');
    expect(branch.subtitleAr, contains(DoctorDesk.bannerAr));
    expect(branch.extraFields.map((field) => field.key), contains('license'));
    expect(DoctorDesk.sampleProfileAllowed, isFalse);
    expect(DoctorDesk.webDashboardAllowed, isFalse);
    expect(DoctorDesk.toastIsPrescriptionDelivery, isFalse);
    expect(DoctorDesk.placeFollowsLocationSystem, isTrue);
    final footer = DoctorDesk.shareFooter();
    expect(footer, contains('الملكية والشراكة مناصفة'));
    expect(footer.contains('تميم'), isFalse);
    expect(footer.contains('DOC-4677'), isFalse);
    expect(footer.contains('35.5'), isFalse);
    expect(footer.contains('المرشد'), isFalse);
  });
}
