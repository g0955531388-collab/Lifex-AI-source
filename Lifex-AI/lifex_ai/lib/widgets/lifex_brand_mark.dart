/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: lifex_brand_mark.dart
/// المسار: lib/widgets/lifex_brand_mark.dart
/// الوصف: الختم الرسمي الدائري (LIFEX-AI + أكاديمية غازي ورباب) كما
/// أُرسل من المالك. يُعرض في الشاشة الافتتاحية وحول التطبيق.
/// =============================================================
library lifex_ai.widgets.lifex_brand_mark;

import 'package:flutter/material.dart';

import '../core/app_constants.dart';

class LifexBrandMark extends StatelessWidget {
  const LifexBrandMark({super.key, this.size = 168});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label:
          'ختم Lifex-AI الرسمي. ${AppConstants.academyHandle}. البريد ${AppConstants.officialContactEmail}.',
      child: ClipOval(
        child: Image.asset(
          AppConstants.officialSealAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
