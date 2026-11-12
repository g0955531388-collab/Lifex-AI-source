/// =============================================================
/// Lifex-AI — تكامل الأجهزة
/// الملف: reactive_data_pipeline.dart
/// تنفيذ StreamDataPipeline على Dart Streams: بلا نسخ، بلا تخزين غير محدود.
/// =============================================================
library lifex_ai.core.device_integration.pipeline.reactive_data_pipeline;

import 'dart:async';

import 'device_reading.dart';
import 'stream_data_pipeline.dart';

class ReactiveDataPipeline implements StreamDataPipeline {
  final _all = StreamController<DeviceReading>.broadcast();
  final _latest = <String, DeviceReading>{};
  final _sources = <StreamSubscription<DeviceReading>>[];
  int _rejected = 0;
  int _conflated = 0;

  static String _key(String deviceId, String channel) => '$deviceId\u0000$channel';

  static bool _valid(DeviceReading r) {
    if (r.deviceId.isEmpty || r.channel.isEmpty) return false;
    final v = r.value;
    if (v is double && !v.isFinite) return false;
    if (v is Map) {
      return v.values.every((x) => x is! double || x.isFinite);
    }
    return true;
  }

  @override
  bool ingest(DeviceReading reading) {
    if (_all.isClosed) return false;
    if (!_valid(reading)) {
      _rejected++;
      return false;
    }
    _latest[_key(reading.deviceId, reading.channel)] = reading;
    _all.add(reading);
    return true;
  }

  @override
  StreamSubscription<DeviceReading> attach(Stream<DeviceReading> source) {
    final sub = source.listen(ingest);
    _sources.add(sub);
    return sub;
  }

  @override
  Stream<DeviceReading> watch({String? deviceId, String? channel}) =>
      _all.stream.where(
        (r) =>
            (deviceId == null || r.deviceId == deviceId) &&
            (channel == null || r.channel == channel),
      );

  @override
  Stream<DeviceReading> watchLatest({
    required String deviceId,
    required String channel,
    Duration minInterval = Duration.zero,
  }) {
    late StreamController<DeviceReading> out;
    StreamSubscription<DeviceReading>? sub;
    Timer? timer;
    DeviceReading? pending;
    DateTime? lastEmit;

    void emit(DeviceReading r) {
      lastEmit = DateTime.now();
      out.add(r);
    }

    void onReading(DeviceReading r) {
      if (minInterval == Duration.zero) return emit(r);
      final since = lastEmit == null
          ? minInterval
          : DateTime.now().difference(lastEmit!);
      if (since >= minInterval && timer == null) return emit(r);
      if (pending != null) _conflated++;
      pending = r;
      timer ??= Timer(minInterval - since, () {
        timer = null;
        final next = pending;
        pending = null;
        if (next != null && !out.isClosed) emit(next);
      });
    }

    out = StreamController<DeviceReading>(
      onListen: () {
        final current = latest(deviceId, channel);
        if (current != null) emit(current);
        sub = watch(deviceId: deviceId, channel: channel).listen(onReading);
      },
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  DeviceReading? latest(String deviceId, String channel) =>
      _latest[_key(deviceId, channel)];

  @override
  int get rejectedReadings => _rejected;

  @override
  int get conflatedReadings => _conflated;

  @override
  Future<void> close() async {
    for (final s in _sources) {
      await s.cancel();
    }
    _sources.clear();
    await _all.close();
  }
}
