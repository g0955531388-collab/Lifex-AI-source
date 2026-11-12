import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/lifex_blind_vision_engine.dart';

class _CountingLocal implements LocalVisionAnalyzer {
  _CountingLocal(this.result, {this.throws = false});

  final BlindVisionResult result;
  final bool throws;
  int calls = 0;

  @override
  Future<BlindVisionResult> analyze(Uint8List imageBytes) async {
    calls++;
    if (throws) throw StateError('local');
    return result;
  }
}

class _CountingCloud implements CloudVisionAnalyzer {
  int calls = 0;
  String? reply;

  @override
  Future<String?> analyze(Uint8List imageBytes, String prompt) async {
    calls++;
    if (reply == 'throw') throw StateError('cloud');
    return reply;
  }
}

void main() {
  test('الصورة الفارغة لا تُحلَّل ولا تُرسل', () async {
    final local = _CountingLocal(
      const BlindVisionResult(description: 'أمامك باب', hasReliableDetection: true),
    );
    final cloud = _CountingCloud()..reply = 'سحابة';
    final engine = LifexBlindVisionEngine(
      localAnalyzer: local,
      cloudAnalyzer: cloud,
    );
    final spoken = await engine.analyzeScene(
      imageBytes: Uint8List(0),
      allowCloud: true,
    );
    expect(spoken, LifexBlindVisionEngine.noImageAr);
    expect(local.calls, 0);
    expect(cloud.calls, 0);
  });

  test('الكشف المحلي الموثوق يُنطق ولا تُستدعى السحابة', () async {
    final cloud = _CountingCloud()..reply = 'وصف سحابي';
    final engine = LifexBlindVisionEngine(
      localAnalyzer: _CountingLocal(
        const BlindVisionResult(
          description: '  أمامك باب  ',
          hasReliableDetection: true,
        ),
      ),
      cloudAnalyzer: cloud,
    );
    final spoken = await engine.analyzeScene(
      imageBytes: Uint8List.fromList(const [1, 2, 3]),
      allowCloud: true,
    );
    expect(spoken, 'أمامك باب');
    expect(cloud.calls, 0);
  });

  test('غياب الكشف الموثوق لا يدّعي مشهداً ولا يرسل بلا موافقة', () async {
    final cloud = _CountingCloud()..reply = 'وصف سحابي';
    final engine = LifexBlindVisionEngine(
      localAnalyzer: const NoModelLocalVisionAnalyzer(),
      cloudAnalyzer: cloud,
    );
    final bytes = Uint8List.fromList(const [9]);
    final blocked = await engine.analyzeScene(imageBytes: bytes);
    expect(blocked, LifexBlindVisionEngine.unsureAr);
    expect(cloud.calls, 0);
    expect(blocked, isNot(contains('متر')));
    expect(blocked, isNot(contains('أمامك')));
  });

  test('السحابة تُستدعى بعد الفشل المحلي فقط عند السماح', () async {
    final cloud = _CountingCloud()..reply = 'أمامك درج';
    final engine = LifexBlindVisionEngine(
      localAnalyzer: _CountingLocal(
        const BlindVisionResult(description: '', hasReliableDetection: false),
      ),
      cloudAnalyzer: cloud,
    );
    final spoken = await engine.analyzeScene(
      imageBytes: Uint8List.fromList(const [4]),
      allowCloud: true,
    );
    expect(spoken, 'أمامك درج');
    expect(cloud.calls, 1);
    expect(LifexBlindVisionEngine.defaultPrompt, contains('لا تخترع مسافة'));
  });

  test('تعطل المحلي والسحابة لا يتحول إلى كشف', () async {
    final cloud = _CountingCloud()..reply = 'throw';
    final engine = LifexBlindVisionEngine(
      localAnalyzer: _CountingLocal(
        const BlindVisionResult(description: 'أمامك شخص', hasReliableDetection: true),
        throws: true,
      ),
      cloudAnalyzer: cloud,
    );
    final spoken = await engine.analyzeScene(
      imageBytes: Uint8List.fromList(const [7]),
      allowCloud: true,
    );
    expect(spoken, LifexBlindVisionEngine.unsureAr);
    expect(spoken, isNot(contains('أمامك شخص')));
  });

  test('المحلل المغلق لا يعيد نصاً ولا يحتاج مفتاحاً', () async {
    expect(
      await const ClosedCloudVisionAnalyzer().analyze(
        Uint8List.fromList(const [1]),
        LifexBlindVisionEngine.defaultPrompt,
      ),
      isNull,
    );
    expect(
      (await const NoModelLocalVisionAnalyzer().analyze(Uint8List.fromList(const [1])))
          .hasReliableDetection,
      isFalse,
    );
  });
}
