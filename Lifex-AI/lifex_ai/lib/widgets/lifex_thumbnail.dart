/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: lifex_thumbnail.dart
/// دائرة الصورة المصغّرة: مسار محلي إن وُجد، وإلا الختم الرسمي.
/// =============================================================
library lifex_ai.widgets.lifex_thumbnail;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class LifexThumbnail extends StatelessWidget {
  const LifexThumbnail({
    super.key,
    this.localPath,
    this.size = 72,
  });

  final String? localPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: tr('الصورة المصغّرة للملف أو ختم Lifex-AI الرسمي'),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: _frame(),
        ),
      ),
    );
  }

  Widget _frame() {
    final path = localPath?.trim();
    if (path != null && path.isNotEmpty && !kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Image.asset(
      AppConstants.officialSealAsset,
      fit: BoxFit.cover,
    );
  }
}
