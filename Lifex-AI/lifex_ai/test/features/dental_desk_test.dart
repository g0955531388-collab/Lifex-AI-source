import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/dental/dental_desk.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';

void main() {
  test('عيادة الأسنان بلا قائمة وهمية ولا متابعة عامة', () {
    final branch = UnitBranchCatalog.forUnit('dental')
        .firstWhere((item) => item.id == 'publicDental');
    expect(branch.subtitleAr, contains(DentalDesk.bannerAr));
    final keys = branch.extraFields.map((field) => field.key);
    expect(keys, contains('place'));
    expect(keys, contains('labNote'));
    expect(DentalDesk.sampleCatalogAllowed, isFalse);
    expect(DentalDesk.autoSuggestFromCoordinatesAllowed, isFalse);
    expect(DentalDesk.publicFollowOfPatientAllowed, isFalse);
    expect(DentalDesk.donationAmountIsDouble, isFalse);
    expect(DentalDesk.emergencyBroadcastAllowed, isFalse);
    expect(DentalDesk.placeFollowsLocationSystem, isTrue);
    expect(
      DentalDesk.shareFooter(),
      contains('الملكية والشراكة مناصفة'),
    );
  });
}
