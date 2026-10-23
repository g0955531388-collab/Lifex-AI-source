import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/hospital/hospital_desk.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';

void main() {
  test('ملف المستشفى بلا قائمة وهمية ولا بث طوارئ', () {
    final branch = UnitBranchCatalog.forUnit('hospital')
        .firstWhere((item) => item.id == 'publicHosp');
    expect(branch.subtitleAr, contains(HospitalDesk.bannerAr));
    final keys = branch.extraFields.map((field) => field.key);
    expect(keys, contains('place'));
    expect(keys, contains('staffNote'));
    expect(keys, contains('achievement'));
    expect(HospitalDesk.sampleCatalogAllowed, isFalse);
    expect(HospitalDesk.autoSuggestFromCoordinatesAllowed, isFalse);
    expect(HospitalDesk.placeFollowsLocationSystem, isTrue);
    expect(HospitalDesk.donationAmountIsDouble, isFalse);
    expect(HospitalDesk.emergencyBroadcastAllowed, isFalse);
    expect(HospitalDesk.vaccinePlanIsSchedule, isFalse);
    final footer = HospitalDesk.shareFooter();
    expect(footer, contains('الملكية والشراكة مناصفة'));
    expect(footer.contains('المساعد'), isFalse);
    expect(footer.contains('Dummy'), isFalse);
  });
}
