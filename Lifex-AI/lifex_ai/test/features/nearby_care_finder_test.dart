import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/location/nearby_care_finder.dart';

void main() {
  const finder = NearbyCareFinder();

  test('الأقرب بالاختصاص والموقع والوحدات بلا إحداثيات لا تُرتَّب', () {
    final report = finder.suggest(
      hereLat: 33.51,
      hereLon: 36.29,
      specialty: 'قلب',
      boxes: [
        CareBox(
          kindAr: 'طبيب',
          specialtyApplies: true,
          rows: [
            {
              'title': 'بعيد',
              'detail': 'قلب — عيادة',
              'latitude': 34.8,
              'longitude': 36.7,
            },
            {
              'title': 'قريب',
              'detail': 'قلب — عيادة',
              'latitude': 33.52,
              'longitude': 36.30,
            },
            {
              'title': 'جلد',
              'detail': 'جلدية — عيادة',
              'latitude': 33.511,
              'longitude': 36.291,
            },
            {
              'title': 'بلا نقطة',
              'detail': 'قلب — بلا موقع',
            },
          ],
        ),
        CareBox(
          kindAr: 'صيدلية',
          rows: [
            {
              'title': 'صيدلية الحي',
              'detail': 'صرف عام',
              'lat': 33.511,
              'lng': 36.291,
            },
            {
              'title': 'صيدلية القلب',
              'detail': 'قلب',
              'lat': 33.60,
              'lng': 36.40,
            },
          ],
        ),
        CareBox(
          kindAr: 'مستشفى',
          rows: [
            {
              'title': 'مشفى القلب',
              'detail': 'قلب',
              'latitude': 33.53,
              'longitude': 36.31,
            },
            {
              'title': 'نقطة وهمية',
              'detail': 'قلب',
              'latitude': 0,
              'longitude': 0,
            },
          ],
        ),
      ],
    );

    expect(report.doctors.map((item) => item.title).toList(), [
      'قريب',
      'بعيد',
      'بلا نقطة',
    ]);
    expect(report.doctors.first.km, lessThan(report.doctors[1].km!));
    expect(report.doctors.last.ranked, isFalse);
    expect(report.units.map((item) => item.title), [
      'مشفى القلب',
      'صيدلية القلب',
      'نقطة وهمية',
    ]);
    expect(report.units.last.ranked, isFalse);
    expect(NearbyCareFinder.usableFix(0, 0), isFalse);
  });
}
