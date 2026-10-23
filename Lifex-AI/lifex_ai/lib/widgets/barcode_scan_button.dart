/// =============================================================
/// Lifex-AI — زر قراءة الباركود
/// يفتح العدسة ويعيد النص المقروء إلى نموذج الوحدة.
/// =============================================================
library lifex_ai.widgets.barcode_scan_button;

import 'package:flutter/material.dart';

import '../screens/barcode_lens_page.dart';

class BarcodeScanButton extends StatelessWidget {
  const BarcodeScanButton({
    super.key,
    required this.onCode,
    this.current,
  });

  final ValueChanged<String> onCode;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final shown = current?.trim() ?? '';
    return OutlinedButton.icon(
      onPressed: () async {
        final code = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const BarcodeLensPage()),
        );
        if (code == null || code.trim().isEmpty) return;
        onCode(code.trim());
      },
      icon: const Icon(Icons.qr_code_scanner),
      label: Text(shown.isEmpty ? 'اقرأ الباركود بالكاميرا' : shown),
    );
  }
}
