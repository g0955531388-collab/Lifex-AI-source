import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/studio_portal_catalog.dart';

void main() {
  test('بوابات الاستوديو تغطي شاشات المستودع بلا قياس منسوخ', () {
    final ids = StudioPortalCatalog.portals.map((item) => item.id).toSet();
    expect(ids, StudioPortalId.values.toSet());
    expect(StudioPortalCatalog.honestyAr, contains('ليست قياساً'));
    expect(StudioPortalCatalog.honestyAr, contains('ولا تشخيصاً'));
    expect(StudioPortalCatalog.sourceRepo, 'g0955531388-collab/google-studio');
    expect(
      StudioPortalCatalog.mainNav.map((item) => item.titleAr),
      [
        'الرئيسية',
        'الشبكة الصحية',
        'ذكاء Lifex-AI',
        'الأجهزة الطبية',
        'طوارئ 24/7',
        'الخصوصية والأمان',
      ],
    );
    expect(StudioPortalCatalog.portalsMenuTitle, 'بوابات المنظومة');
    expect(
        StudioPortalCatalog.disclaimerBarAr, contains('ليست بديلاً عن الطبيب'));
    expect(
      StudioPortalCatalog.portals
          .firstWhere((item) => item.id == StudioPortalId.pharmacy)
          .titleAr,
      'بوابة الصيدلية والدواء',
    );
    expect(
      StudioPortalCatalog.portals
          .firstWhere((item) => item.id == StudioPortalId.pharmacy)
          .titleEn,
      'Pharmacy Portal',
    );
    expect(StudioPortalCatalog.mainNav.first.title(false), 'Home');
    expect(
        StudioPortalCatalog.disclaimer(false), contains('not a replacement'));
    expect(
      StudioPortalCatalog.disclaimerBarAr.contains('المرشدة'),
      isFalse,
    );
  });
}
