/// =============================================================
/// Lifex-AI — المراقبة الصحية عن بعد
/// الملف: remote_health_monitor.dart
/// المسار: lib/features/remote_health/remote_health_monitor.dart
/// الوصف: يسمح لفرد موثوق (مثلاً ابن يتابع صحة والده) بمراقبة مؤشرات
/// صحية محدودة عن بعد، وفق صلاحيات profile_privacy_manager.dart فقط.
/// =============================================================
library;

import '../../core/health_event_manager.dart';

/// لقطة مؤشرات صحية مبسّطة يُسمح بمشاركتها عن بعد (ملخص لا تفاصيل خام).
class RemoteHealthSnapshot {
  final String profileId;
  final DateTime timestamp;
  final Map<String, dynamic> summaryMetrics;

  const RemoteHealthSnapshot({
    required this.profileId,
    required this.timestamp,
    required this.summaryMetrics,
  });
}

/// مدير المراقبة عن بعد — يبني لقطات ملخّصة ويوزّعها على المراقبين
/// المصرَّح لهم فقط (تُحدَّد صلاحياتهم عبر trusted_contacts_manager.dart).
class RemoteHealthMonitor {
  RemoteHealthMonitor();

  final Map<String, List<String>> _monitorsByProfileId = {};
  final Map<String, RemoteHealthSnapshot> _latestSnapshotByProfileId = {};

  /// ربط معرّف مراقِب (lifexId) بملف صحي معيّن ليتابعه عن بعد.
  void addMonitor({required String profileId, required String monitorLifexId}) {
    _monitorsByProfileId.putIfAbsent(profileId, () => []).add(monitorLifexId);
  }

  void removeMonitor({required String profileId, required String monitorLifexId}) {
    _monitorsByProfileId[profileId]?.remove(monitorLifexId);
  }

  List<String> monitorsFor(String profileId) =>
      List.unmodifiable(_monitorsByProfileId[profileId] ?? const []);

  /// نشر لقطة صحية ملخّصة جديدة، وإعلام المراقبين المصرَّح لهم عبر
  /// ناقل الأحداث المركزي.
  void publishSnapshot(RemoteHealthSnapshot snapshot) {
    _latestSnapshotByProfileId[snapshot.profileId] = snapshot;

    HealthEventManager.instance.emitQuick(
      HealthEventType.profileUpdated,
      sourceModule: 'remote_health_monitor',
      profileId: snapshot.profileId,
      data: {
        'updateType': 'remote_snapshot_published',
        'monitors': monitorsFor(snapshot.profileId),
      },
    );
  }

  RemoteHealthSnapshot? latestSnapshotFor(String profileId) =>
      _latestSnapshotByProfileId[profileId];
}
