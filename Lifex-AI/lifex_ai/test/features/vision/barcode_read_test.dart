import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:lifex_ai/screens/barcode_lens_page.dart';

void main() {
  test('نتيجة الباركود تعرض نوع المكتبة وتبقي النص الخام', () {
    const raw = 'https://example.test/pay';
    final read = BarcodeRead.fromLibrary(
      rawValue: raw,
      format: BarcodeFormat.qrCode,
    );
    expect(read.formatName, 'QR Code');
    expect(read.raw, raw);
    expect(read.opensAutomatically, isFalse);
  });

  test('غياب النوع يُعرض unknown ولا يُخمَّن', () {
    final unknown = BarcodeRead.fromLibrary(
      rawValue: 'ABC',
      format: BarcodeFormat.unknown,
    );
    final scanAll = BarcodeRead.fromLibrary(
      rawValue: 'ABC',
      format: BarcodeFormat.all,
    );
    expect(unknown.formatName, 'unknown');
    expect(scanAll.formatName, 'unknown');
    expect(unknown.raw, 'ABC');
    expect(BarcodeRead.nameOf(BarcodeFormat.ean13), 'EAN-13');
    expect(BarcodeRead.nameOf(BarcodeFormat.pdf417), 'PDF417');
  });
}
