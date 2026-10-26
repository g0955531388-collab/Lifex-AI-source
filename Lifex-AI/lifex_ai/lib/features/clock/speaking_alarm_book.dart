/// منبهات ناطقة مربوطة بإحداثيات الجهاز. بلا عنوان شارع وبلا جرعة.
library lifex_ai.features.clock.speaking_alarm_book;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../location/device_location_reader.dart';
import '../voice/voice_engine.dart';

enum AlarmPlace { inside, outside, unconfirmed }

class SpeakingAlarm {
  const SpeakingAlarm({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final int hour;
  final int minute;
  final bool enabled;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  SpeakingAlarm copyWith({bool? enabled, String? name}) {
    return SpeakingAlarm(
      id: id,
      name: name ?? this.name,
      hour: hour,
      minute: minute,
      enabled: enabled ?? this.enabled,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
      };

  static SpeakingAlarm? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final hour = _int(json['hour']);
    final minute = _int(json['minute']);
    final latitude = _double(json['latitude']);
    final longitude = _double(json['longitude']);
    final radius = _double(json['radiusMeters']);
    if (id.isEmpty ||
        name.isEmpty ||
        hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        latitude == null ||
        longitude == null ||
        radius == null ||
        radius < 50 ||
        radius > 2000) {
      return null;
    }
    return SpeakingAlarm(
      id: id,
      name: name,
      hour: hour,
      minute: minute,
      enabled: json['enabled'] == true,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius,
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double lifexMetersBetween(
  double latitude,
  double longitude,
  double otherLatitude,
  double otherLongitude,
) {
  const earth = 6371000.0;
  double rad(double degree) => degree * math.pi / 180;
  final dLat = rad(otherLatitude - latitude);
  final dLon = rad(otherLongitude - longitude);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(latitude)) *
          math.cos(rad(otherLatitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

AlarmPlace judgeSpeakingAlarm({
  required double latitude,
  required double longitude,
  required double radiusMeters,
  required double? hereLatitude,
  required double? hereLongitude,
  required double? accuracyMeters,
}) {
  if (hereLatitude == null || hereLongitude == null) {
    return AlarmPlace.unconfirmed;
  }
  if (accuracyMeters != null && accuracyMeters > radiusMeters) {
    return AlarmPlace.unconfirmed;
  }
  final meters = lifexMetersBetween(
    latitude,
    longitude,
    hereLatitude,
    hereLongitude,
  );
  if (meters <= radiusMeters) return AlarmPlace.inside;
  return AlarmPlace.outside;
}

String speakingAlarmPhrase({
  required String name,
  required String timeLabel,
  required AlarmPlace place,
  required bool arabic,
}) {
  if (arabic) {
    switch (place) {
      case AlarmPlace.inside:
        return 'منبه $name. الساعة $timeLabel. أنت ضمن نطاق المكان المحفوظ.';
      case AlarmPlace.outside:
        return 'منبه $name. الساعة $timeLabel. أنت خارج نطاق المكان المحفوظ.';
      case AlarmPlace.unconfirmed:
        return 'منبه $name. الساعة $timeLabel. تعذّر تأكيد المكان.';
    }
  }
  switch (place) {
    case AlarmPlace.inside:
      return 'Alarm $name. The time is $timeLabel. You are inside the saved place.';
    case AlarmPlace.outside:
      return 'Alarm $name. The time is $timeLabel. You are outside the saved place.';
    case AlarmPlace.unconfirmed:
      return 'Alarm $name. The time is $timeLabel. The place could not be confirmed.';
  }
}

class SpeakingAlarmBook {
  const SpeakingAlarmBook();

  static const storageKey = 'lifex_speaking_alarms_v1';

  Future<List<SpeakingAlarm>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => SpeakingAlarm.fromJson(Map<String, dynamic>.from(item)))
          .whereType<SpeakingAlarm>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<SpeakingAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(alarms.map((alarm) => alarm.toJson()).toList()),
    );
  }
}

class SpeakingAlarmWatch {
  SpeakingAlarmWatch._();

  static final SpeakingAlarmWatch instance = SpeakingAlarmWatch._();

  final SpeakingAlarmBook book = const SpeakingAlarmBook();
  final Set<String> _spoken = <String>{};
  Timer? _timer;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(tick(DateTime.now()));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tick(
    DateTime now, {
    DeviceLocationRead? fix,
    Future<void> Function(String text)? speak,
  }) async {
    final local = now.toLocal();
    final alarms = await book.load();
    final due = alarms.where(
      (alarm) =>
          alarm.enabled && alarm.hour == local.hour && alarm.minute == local.minute,
    );
    if (due.isEmpty) return;
    final read = fix ?? await const DeviceLocationReader().peek();
    final say = speak ?? VoiceEngine.instance.speak;
    for (final alarm in due) {
      final stamp =
          '${alarm.id}|${local.year}-${local.month}-${local.day}|${local.hour}:${local.minute}';
      if (!_spoken.add(stamp)) continue;
      if (_spoken.length > 240) {
        _spoken.remove(_spoken.first);
      }
      final place = judgeSpeakingAlarm(
        latitude: alarm.latitude,
        longitude: alarm.longitude,
        radiusMeters: alarm.radiusMeters,
        hereLatitude: read.fix?.latitude,
        hereLongitude: read.fix?.longitude,
        accuracyMeters: read.fix?.accuracyMeters,
      );
      final time = '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      await say(speakingAlarmPhrase(
        name: alarm.name,
        timeLabel: time,
        place: place,
        arabic: AppConfig.instance.defaultLanguage != AppLanguage.english,
      ));
    }
  }
}
