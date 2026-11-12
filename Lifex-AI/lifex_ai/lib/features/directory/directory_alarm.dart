/// منبه الدليل: تذكير قبل ساعتين وساعة، ثم بحث عند الوقت.
/// يعمل ما دام التطبيق مفتوحاً. لا يفتح التطبيق وهو مغلق.
library lifex_ai.features.directory.directory_alarm;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../voice/voice_engine.dart';

enum DirectoryAlarmStatus { pending, notified2h, notified1h, executed }

enum DirectoryAlarmCue { remind2h, remind1h, searchNow }

class DirectoryAlarm {
  const DirectoryAlarm({
    required this.id,
    required this.userId,
    required this.targetProfessionalId,
    required this.targetNameOrKeyword,
    required this.scheduled,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String targetProfessionalId;
  final String targetNameOrKeyword;
  final DateTime scheduled;
  final String reason;
  final DirectoryAlarmStatus status;
  final DateTime createdAt;

  DirectoryAlarm copyWith({DirectoryAlarmStatus? status}) {
    return DirectoryAlarm(
      id: id,
      userId: userId,
      targetProfessionalId: targetProfessionalId,
      targetNameOrKeyword: targetNameOrKeyword,
      scheduled: scheduled,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'targetProfessionalId': targetProfessionalId,
        'targetNameOrKeyword': targetNameOrKeyword,
        'scheduled': scheduled.toUtc().toIso8601String(),
        'reason': reason,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static DirectoryAlarm? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final userId = json['userId']?.toString() ?? '';
    final target = json['targetNameOrKeyword']?.toString().trim() ?? '';
    final reason = json['reason']?.toString().trim() ?? '';
    final scheduled = DateTime.tryParse(json['scheduled']?.toString() ?? '');
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (id.isEmpty ||
        userId.isEmpty ||
        target.isEmpty ||
        reason.isEmpty ||
        scheduled == null ||
        created == null) {
      return null;
    }
    return DirectoryAlarm(
      id: id,
      userId: userId,
      targetProfessionalId: json['targetProfessionalId']?.toString() ?? '',
      targetNameOrKeyword: target,
      scheduled: scheduled.toLocal(),
      reason: reason,
      status: _status(json['status']?.toString()),
      createdAt: created.toLocal(),
    );
  }
}

DirectoryAlarmStatus _status(String? raw) {
  for (final status in DirectoryAlarmStatus.values) {
    if (status.name == raw) return status;
  }
  return DirectoryAlarmStatus.pending;
}

DirectoryAlarm? newDirectoryAlarm({
  required String id,
  required String userId,
  required String targetNameOrKeyword,
  required DateTime scheduled,
  required String reason,
  required DateTime now,
  String targetProfessionalId = '',
}) {
  final target = targetNameOrKeyword.trim();
  final why = reason.trim();
  final owner = userId.trim();
  if (target.isEmpty || why.isEmpty || owner.isEmpty) return null;
  return DirectoryAlarm(
    id: id,
    userId: owner,
    targetProfessionalId: targetProfessionalId,
    targetNameOrKeyword: target,
    scheduled: scheduled.toLocal(),
    reason: why,
    status: DirectoryAlarmStatus.pending,
    createdAt: now.toLocal(),
  );
}

/// أقرب خطوة مستحقة لم تُنطق بعد. إن فاتت خطوة لأن التطبيق كان مغلقاً تُتخطى.
DirectoryAlarmCue? dueDirectoryCue(DirectoryAlarm alarm, DateTime now) {
  if (alarm.status == DirectoryAlarmStatus.executed) return null;
  final localNow = now.toLocal();
  final at = alarm.scheduled.toLocal();
  if (!localNow.isBefore(at)) return DirectoryAlarmCue.searchNow;
  if (!localNow.isBefore(at.subtract(const Duration(hours: 1))) &&
      alarm.status != DirectoryAlarmStatus.notified1h) {
    return DirectoryAlarmCue.remind1h;
  }
  if (!localNow.isBefore(at.subtract(const Duration(hours: 2))) &&
      alarm.status == DirectoryAlarmStatus.pending) {
    return DirectoryAlarmCue.remind2h;
  }
  return null;
}

DirectoryAlarm applyDirectoryCue(DirectoryAlarm alarm, DirectoryAlarmCue cue) {
  switch (cue) {
    case DirectoryAlarmCue.remind2h:
      return alarm.copyWith(status: DirectoryAlarmStatus.notified2h);
    case DirectoryAlarmCue.remind1h:
      return alarm.copyWith(status: DirectoryAlarmStatus.notified1h);
    case DirectoryAlarmCue.searchNow:
      return alarm.copyWith(status: DirectoryAlarmStatus.executed);
  }
}

String directoryAlarmPhrase({
  required DirectoryAlarm alarm,
  required DirectoryAlarmCue cue,
  required bool arabic,
}) {
  if (arabic) {
    switch (cue) {
      case DirectoryAlarmCue.remind2h:
        return 'تذكير قبل ساعتين. ${alarm.reason}. البحث عن ${alarm.targetNameOrKeyword}.';
      case DirectoryAlarmCue.remind1h:
        return 'تذكير قبل ساعة. ${alarm.reason}. البحث عن ${alarm.targetNameOrKeyword}.';
      case DirectoryAlarmCue.searchNow:
        return 'حان موعد الدليل. ${alarm.reason}. جارٍ البحث عن ${alarm.targetNameOrKeyword}.';
    }
  }
  switch (cue) {
    case DirectoryAlarmCue.remind2h:
      return 'Reminder two hours before. ${alarm.reason}. Search for ${alarm.targetNameOrKeyword}.';
    case DirectoryAlarmCue.remind1h:
      return 'Reminder one hour before. ${alarm.reason}. Search for ${alarm.targetNameOrKeyword}.';
    case DirectoryAlarmCue.searchNow:
      return 'Directory time. ${alarm.reason}. Searching for ${alarm.targetNameOrKeyword}.';
  }
}

class DirectoryAlarmBook {
  const DirectoryAlarmBook();

  static const storageKey = 'lifex_directory_alarms_v1';

  Future<List<DirectoryAlarm>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => DirectoryAlarm.fromJson(Map<String, dynamic>.from(item)))
          .whereType<DirectoryAlarm>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<DirectoryAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(alarms.map((alarm) => alarm.toJson()).toList()),
    );
  }
}

class DirectoryAlarmWatch {
  DirectoryAlarmWatch._();

  static final DirectoryAlarmWatch instance = DirectoryAlarmWatch._();

  final DirectoryAlarmBook book = const DirectoryAlarmBook();
  Timer? _timer;
  void Function(DirectoryAlarm alarm)? onSearch;

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
    Future<void> Function(String text)? speak,
    void Function(DirectoryAlarm alarm)? search,
  }) async {
    final alarms = await book.load();
    if (alarms.isEmpty) return;
    final say = speak ?? VoiceEngine.instance.speak;
    final open = search ?? onSearch;
    final arabic = AppConfig.instance.defaultLanguage != AppLanguage.english;
    var changed = false;
    final next = <DirectoryAlarm>[];
    for (final alarm in alarms) {
      final cue = dueDirectoryCue(alarm, now);
      if (cue == null) {
        next.add(alarm);
        continue;
      }
      final updated = applyDirectoryCue(alarm, cue);
      next.add(updated);
      changed = true;
      await say(directoryAlarmPhrase(alarm: alarm, cue: cue, arabic: arabic));
      if (cue == DirectoryAlarmCue.searchNow) open?.call(updated);
    }
    if (changed) await book.save(next);
  }
}
