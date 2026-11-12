/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: stream_data_pipeline.dart
/// واجهة خط القراءات الحية من السواقات إلى الواجهة ومحرك الذكاء.
/// =============================================================
library lifex_ai.core.device_integration.pipeline.stream_data_pipeline;

import 'dart:async';

import 'device_reading.dart';

abstract class StreamDataPipeline {
  /// إدخال قراءة. القيم غير الصالحة تُرفض ولا تُستبدل بقيم مختلقة.
  bool ingest(DeviceReading reading);

  /// ربط مصدر قراءات (سواقة) بالخط.
  StreamSubscription<DeviceReading> attach(Stream<DeviceReading> source);

  /// كل قراءة كما وصلت، مع تصفية اختيارية.
  Stream<DeviceReading> watch({String? deviceId, String? channel});

  /// أحدث قيمة لقناة، بمعدل لا يتجاوز مرة كل [minInterval]؛ القيمة المتجاوزة تُستبدل بالأحدث.
  Stream<DeviceReading> watchLatest({
    required String deviceId,
    required String channel,
    Duration minInterval = Duration.zero,
  });

  DeviceReading? latest(String deviceId, String channel);

  int get rejectedReadings;

  /// قراءات استُبدلت بأحدث منها قبل وصولها لمشترك مقيَّد المعدل.
  int get conflatedReadings;

  Future<void> close();
}
