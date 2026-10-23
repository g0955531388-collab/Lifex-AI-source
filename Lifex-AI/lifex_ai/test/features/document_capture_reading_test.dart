import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/vision/document_capture_reading.dart';

void main() {
  test('وثيقة بلا نص تبقى بلا محتوى مخترع', () {
    final reading = DocumentCaptureReading.compose('   ');
    expect(reading.read, isFalse);
    expect(reading.storedAr, DocumentCaptureReading.unreadAr);
    expect(reading.storedAr, isNot(contains('نتيجة')));
  });

  test('النص المقروء يُحفظ كملاحظة من الوثيقة', () {
    final reading = DocumentCaptureReading.compose('اسم المريض: سطر مطبوع');
    expect(reading.read, isTrue);
    expect(reading.storedAr, contains('اسم المريض: سطر مطبوع'));
    expect(reading.storedAr, contains('ليس تشخيصاً'));
  });
}
