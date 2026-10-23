/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: permission_transparency.dart
/// المسار: lib/core/permission_transparency.dart
/// الوصف: إطار شفافية الصلاحيات (القسم 2 من الوثيقة الموحّدة): شرح ثم
/// موافقة صريحة ثم إدارة داخل التطبيق. لا يفعّل إذناً على النظام مباشرة،
/// بل يحفظ قرار المستخدم وسجل الاستخدام لكل إذن حسّاس.
/// =============================================================
library lifex_ai.core.permission_transparency;

enum LifexSensitivePermission {
  camera,
  microphone,
  location,
  healthData,
}

class PermissionDecisionRecord {
  PermissionDecisionRecord({
    required this.permission,
    required this.granted,
    required this.reasonAr,
    DateTime? decidedAt,
  }) : decidedAt = decidedAt ?? DateTime.now();

  final LifexSensitivePermission permission;
  bool granted;
  final String reasonAr;
  DateTime decidedAt;
  final List<DateTime> usageLog = [];

  void recordUsage() => usageLog.add(DateTime.now());
}

class PermissionTransparencyManager {
  PermissionTransparencyManager._internal();
  static final PermissionTransparencyManager instance =
      PermissionTransparencyManager._internal();

  final Map<LifexSensitivePermission, PermissionDecisionRecord> _records = {};

  static const Map<LifexSensitivePermission, String> titlesAr = {
    LifexSensitivePermission.camera: 'الكاميرا الطبية الذكية',
    LifexSensitivePermission.microphone: 'المساعد الصوتي الصحي',
    LifexSensitivePermission.location: 'الموقع الصحي والطوارئ',
    LifexSensitivePermission.healthData: 'البيانات الصحية على الجهاز',
  };

  static const Map<LifexSensitivePermission, String> explanationsAr = {
    LifexSensitivePermission.camera:
        'تُستخدم لقراءة الأوراق الطبية والأدوية ومساعدة المكفوفين والرادار الضوئي، '
            'وليس للبث المستمر بدون موافقتك.',
    LifexSensitivePermission.microphone:
        'يُستخدم للأوامر الصوتية وتنبيهات الطوارئ الصوتية. لا يُرسل '
            'مقطع صوتي لأي خادم دون موافقة منفصلة.',
    LifexSensitivePermission.location:
        'يُستخدم في الطوارئ وشبكة الدم لإرشاد أقرب مساعدة. يمكن إيقافه '
            'في أي وقت من هذه الشاشة.',
    LifexSensitivePermission.healthData:
        'تبقى في ملفك الصحي المحلي. لا تُشارك مع طبيب أو عائلة إلا حسب '
            'قواعد الخصوصية التي تضبطها أنت.',
  };

  PermissionDecisionRecord? recordOf(LifexSensitivePermission permission) =>
      _records[permission];

  bool isGranted(LifexSensitivePermission permission) =>
      _records[permission]?.granted == true;

  void decide({
    required LifexSensitivePermission permission,
    required bool granted,
  }) {
    final existing = _records[permission];
    if (existing == null) {
      _records[permission] = PermissionDecisionRecord(
        permission: permission,
        granted: granted,
        reasonAr: explanationsAr[permission] ?? '',
      );
    } else {
      existing.granted = granted;
      existing.decidedAt = DateTime.now();
    }
    onDecided?.call(permission, granted);
  }

  /// يُستدعى بعد الحفظ حتى تبقى موافقة التطبيق بعد إعادة التشغيل.
  void Function(LifexSensitivePermission permission, bool granted)? onDecided;

  void restore(Map<String, bool> saved) {
    final hook = onDecided;
    onDecided = null;
    for (final permission in LifexSensitivePermission.values) {
      final granted = saved[permission.name];
      if (granted == null) continue;
      decide(permission: permission, granted: granted);
    }
    onDecided = hook;
  }

  bool useIfGranted(LifexSensitivePermission permission) {
    final record = _records[permission];
    if (record == null || !record.granted) return false;
    record.recordUsage();
    return true;
  }
}
