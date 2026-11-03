/// =============================================================
/// Lifex-AI — المكوّنات المشتركة
/// الملف: honesty_banner.dart
/// تنبيه صادق: محلي على الجهاز أو ينتظر خادماً.
/// =============================================================
library lifex_ai.widgets.honesty_banner;

import 'package:flutter/material.dart';
import 'lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class HonestyBanner extends StatelessWidget {
  const HonestyBanner({
    super.key,
    required this.messageAr,
  });

  final String messageAr;

  factory HonestyBanner.localAndServer() => const HonestyBanner(
        messageAr:
            'السجلات هنا تُحفظ في ملفك على هذا الجهاز. الربط المؤسسي والدفع والرسائل الخارجية يحتاج خادماً وحسابات وصلاحيات. لا تُعرض نتائج وهمية.',
      );

  factory HonestyBanner.medical() => const HonestyBanner(
        messageAr:
            'هذه البيانات للتنظيم الشخصي وليست تشخيصاً ولا بديلاً عن الطبيب أو خدمات الطوارئ.',
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr(messageAr),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LifexText(messageAr),
        ),
      ),
    );
  }
}
