// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: project_attribution_test.dart
// المسار: test/core/attribution/project_attribution_test.dart
// الوصف: يحرس النص الرسمي الوحيد للإسناد ويمنع صيغ الورثة/الشركاء/
// الملكية المشتركة أو أي إعادة صياغة في AppConstants.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/core/attribution/project_attribution.dart';
import 'package:lifex_ai/core/license_manager.dart';

void main() {
  group('الإسناد الرسمي المعتمد', () {
    test('الصيغة العربية مطابقة حرفياً للنص المعتمد', () {
      expect(
        AppConstants.ownershipStatement,
        ProjectAttribution.officialStatementAr,
      );
      expect(
        AppConstants.ownershipStatement,
        'Lifex-AI\n'
        'الملكية والشراكة مناصفة: غازي سليم بكفلاوي ورباب الحايك\n'
        'المخترع: غازي سليم بكفلاوي\n'
        'خبير الهندسة الطبية الحيوية',
      );
    });

    test('الصيغة الإنجليزية مطابقة حرفياً للنص المعتمد', () {
      expect(
        AppConstants.ownershipStatementEn,
        ProjectAttribution.officialStatementEn,
      );
      expect(
        AppConstants.ownershipStatementEn,
        'Lifex-AI\n'
        'Equal ownership and partnership: Ghazi Salim Bekfalawi and Rabab Al-Hayek\n'
        'Inventor: Ghazi Salim Bekfalawi\n'
        'Biomedical Engineering Expert',
      );
    });

    test('الملكية والشراكة مناصفة والمخترع غازي', () {
      expect(
        AppConstants.developerCredit,
        ProjectAttribution.inventorOwnerAr,
      );
      expect(AppConstants.developerCredit.contains('رباب'), isFalse);
      expect(AppConstants.guideCreditAr, 'الشريكة رباب الحايك');
      expect(
        AppConstants.ownershipStatement.contains(
          'الملكية والشراكة مناصفة: غازي سليم بكفلاوي ورباب الحايك',
        ),
        isTrue,
      );
      expect(
        AppConstants.ownershipStatement.contains('المخترع: غازي سليم بكفلاوي'),
        isTrue,
      );
    });

    test('لا توجد صيغ ورثة أو شركاء ملكية أو أسماء عائلية في الإسناد', () {
      final surfaces = [
        AppConstants.ownershipStatement,
        AppConstants.ownershipStatementEn,
        AppConstants.ownershipStatementShort,
        AppConstants.ownershipStatementShortEn,
        AppConstants.builderAttributionAr,
        AppConstants.developerCredit,
        AppConstants.guideCreditAr,
      ];

      for (final text in surfaces) {
        expect(
          ProjectAttribution.containsForbiddenFragment(text),
          isFalse,
          reason: 'نص إسناد يحتوي صيغة محظورة: $text',
        );
      }
    });

    test('تذييل الترخيص يذكر المناصفة ولا يضيف ورثة', () {
      final stamped = LicenseManager.instance.appendEn('Body');
      expect(stamped.contains(AppConstants.ownershipStatementShortEn), isTrue);
      expect(stamped.contains('Equal ownership and partnership'), isTrue);
      expect(stamped.contains('with Rabab'), isFalse);
      expect(stamped.contains('ورث'), isFalse);
    });

    test('builderAttribution يطابق الإسناد الرسمي دون تكرار صيغة أخرى', () {
      expect(
        AppConstants.builderAttributionAr,
        AppConstants.ownershipStatement,
      );
    });
  });
}
