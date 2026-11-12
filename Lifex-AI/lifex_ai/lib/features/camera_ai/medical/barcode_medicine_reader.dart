/// باركود العبوة يطابق معرّفاً موجوداً في الخريطة حرفياً.
/// غياب المطابقة يرجّع إلى قراءة الملصق. بلا جرعة وبلا اسم مخترع.
library lifex_ai.features.camera_ai.medical.barcode_medicine_reader;

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class BarcodeScanResult {
  const BarcodeScanResult({
    required this.code,
    required this.formatName,
    this.matchedMedicationId,
    this.fallbackToOcr = false,
  });

  final String code;
  final String formatName;
  final String? matchedMedicationId;
  final bool fallbackToOcr;
}

class BarcodeMedicineReader {
  BarcodeMedicineReader({required this.gtinToMedicationIdMap});

  /// رقم GTIN كما طُبع إلى معرّف الدواء. لا مطابقة باللاحقة.
  final Map<String, String> gtinToMedicationIdMap;

  final _scanner = BarcodeScanner();

  BarcodeScanResult lookup(String code, {String formatName = ''}) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const BarcodeScanResult(
        code: '',
        formatName: '',
        fallbackToOcr: true,
      );
    }
    final matched = gtinToMedicationIdMap[trimmed];
    return BarcodeScanResult(
      code: trimmed,
      formatName: formatName,
      matchedMedicationId: matched,
      fallbackToOcr: matched == null,
    );
  }

  Future<BarcodeScanResult> scanFromImagePath(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final barcodes = await _scanner.processImage(input);
      if (barcodes.isEmpty) {
        return const BarcodeScanResult(
          code: '',
          formatName: '',
          fallbackToOcr: true,
        );
      }
      final first = barcodes.first;
      return lookup(first.rawValue ?? '', formatName: first.format.name);
    } catch (_) {
      return const BarcodeScanResult(
        code: '',
        formatName: '',
        fallbackToOcr: true,
      );
    }
  }

  Future<void> dispose() => _scanner.close();
}
