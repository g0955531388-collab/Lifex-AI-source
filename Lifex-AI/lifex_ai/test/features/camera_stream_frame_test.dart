import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/camera_stream_frame.dart';

void main() {
  test('ثلاث طبقات YUV تُحزم NV21 بالترتيب V ثم U', () {
    final packed = CameraStreamFrame.packNv21(
      width: 2,
      height: 2,
      yBytes: Uint8List.fromList([1, 2, 3, 4]),
      yRowStride: 2,
      uBytes: Uint8List.fromList([8]),
      uRowStride: 1,
      uPixelStride: 1,
      vBytes: Uint8List.fromList([9]),
      vRowStride: 1,
      vPixelStride: 1,
    );
    expect(packed, [1, 2, 3, 4, 9, 8]);
  });

  test('صف الإضاءة الأقصر من العرض لا يُخترع إطاراً', () {
    expect(
      CameraStreamFrame.packNv21(
        width: 4,
        height: 2,
        yBytes: Uint8List.fromList([1, 2]),
        yRowStride: 4,
        uBytes: Uint8List.fromList([1, 1]),
        uRowStride: 2,
        uPixelStride: 1,
        vBytes: Uint8List.fromList([1, 1]),
        vRowStride: 2,
        vPixelStride: 1,
      ),
      isNull,
    );
  });
}
