import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/blind_scene_brief.dart';
import 'package:lifex_ai/features/accessibility/local_object_detector.dart';

void main() {
  test('الكاشف غير المثبت لا يعيد أجساماً ولا يدّعي أنه رأى إطاراً', () {
    final outcome = const LocalObjectDetector().run();
    expect(outcome.ran, isFalse);
    expect(outcome.objects, isEmpty);
    expect(outcome.reasonAr, contains('ليس كشف أجسام'));
    expect(outcome.reasonAr, isNot(contains('أمامك')));
  });

  test('وصف الكشف يتجاهل التسمية بلا صندوق والثقة المنخفضة', () {
    final spoken = BlindSceneBrief.fromDetections(const [
      DetectedObject(
        label: 'Person',
        confidence: 0.2,
        left: 0,
        top: 0,
        right: 10,
        bottom: 20,
      ),
      DetectedObject(
        label: 'Car',
        confidence: 0.9,
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
      ),
      DetectedObject(
        label: 'Door',
        confidence: 0.8,
        left: 1,
        top: 2,
        right: 30,
        bottom: 40,
      ),
    ]);
    expect(spoken, 'باب');
    expect(spoken, isNot(contains('شخص')));
    expect(spoken, isNot(contains('سيارة')));
    expect(spoken, isNot(contains('متر')));
    expect(spoken, isNot(contains('يقترب')));
    expect(spoken, isNot(contains('متوقفة')));
  });
}
