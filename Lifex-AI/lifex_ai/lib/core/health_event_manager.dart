/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: health_event_manager.dart
/// المسار: lib/core/health_event_manager.dart
/// الوصف: ناقل أحداث مركزي (Event Bus) يسمح لكل وحدات النظام بالتواصل
/// فيما بينها دون اعتماد مباشر (Direct dependency) على بعضها البعض.
/// مثال: عند تسجيل قراءة سكر مرتفعة في وحدة الملف الصحي، يُصدر حدثاً
/// يمكن لوحدة الطوارئ أو وحدة التنبيهات الاستماع إليه دون أن تعرف
/// وحدة الملف الصحي بوجودهما أصلاً.
/// =============================================================
library;

/// أنواع الأحداث الصحية الأساسية المتداولة عبر النظام.
///
/// هذه القائمة تتوسع مع إضافة وحدات جديدة؛ يجب عدم تكرار نفس المعنى
/// باسمين مختلفين — أي حدث جديد يُضاف هنا أولاً قبل استخدامه في أي وحدة.
enum HealthEventType {
  vitalReadingRecorded, // تسجيل قراءة حيوية (ضغط، سكر، نبض...)
  medicationTaken, // تأكيد تناول دواء
  medicationMissed, // تفويت جرعة دواء
  appointmentScheduled, // حجز موعد جديد
  appointmentCancelled, // إلغاء موعد
  labResultReceived, // استلام نتيجة تحليل
  imagingResultReceived, // استلام نتيجة تصوير/أشعة
  emergencyTriggered, // إطلاق حالة طوارئ
  emergencyResolved, // انتهاء حالة الطوارئ
  profileUpdated, // تحديث بيانات الملف الصحي
  pregnancyMilestoneReached, // بلوغ مرحلة جديدة في متابعة الحمل
  donationMatched, // مطابقة تبرع مع حالة مستفيد
  bloodRequestCreated, // إنشاء طلب دم جديد
  epidemicSignalUpdated, // إشارة رصد وبائي. ليست إعلاناً رسمياً
  custom, // حدث مخصص لوحدة لم تُصنَّف بعد
}

/// حمولة (payload) الحدث الصحي — بيانات مرنة تحمل تفاصيل الحدث.
class HealthEvent {
  final HealthEventType type;
  final String sourceModule;
  final String? profileId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  HealthEvent({
    required this.type,
    required this.sourceModule,
    this.profileId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
  })  : data = data ?? const {},
        timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'HealthEvent(${type.name}) from $sourceModule at $timestamp';
}

/// توقيع دالة الاستماع لحدث صحي.
typedef HealthEventListener = void Function(HealthEvent event);

/// المدير المركزي لناقل الأحداث الصحية (Event Bus بنمط Pub/Sub).
class HealthEventManager {
  HealthEventManager._internal();
  static final HealthEventManager instance = HealthEventManager._internal();

  /// خريطة: نوع الحدث → قائمة المستمعين المسجّلين له.
  final Map<HealthEventType, List<HealthEventListener>> _listeners = {};

  /// مستمعون عامون يستقبلون كل الأحداث بغض النظر عن نوعها (مفيد للتسجيل
  /// العام / التدقيق / السجلات).
  final List<HealthEventListener> _globalListeners = [];

  /// الاشتراك في نوع حدث معيّن.
  void subscribe(HealthEventType type, HealthEventListener listener) {
    _listeners.putIfAbsent(type, () => []).add(listener);
  }

  /// إلغاء الاشتراك من نوع حدث معيّن.
  void unsubscribe(HealthEventType type, HealthEventListener listener) {
    _listeners[type]?.remove(listener);
  }

  /// الاشتراك في كل الأحداث بلا استثناء.
  void subscribeToAll(HealthEventListener listener) {
    _globalListeners.add(listener);
  }

  void unsubscribeFromAll(HealthEventListener listener) {
    _globalListeners.remove(listener);
  }

  /// إصدار حدث جديد إلى كل المستمعين المهتمين به.
  void emit(HealthEvent event) {
    final specificListeners = _listeners[event.type];
    if (specificListeners != null) {
      for (final listener in List<HealthEventListener>.from(specificListeners)) {
        listener(event);
      }
    }
    for (final listener in List<HealthEventListener>.from(_globalListeners)) {
      listener(event);
    }
  }

  /// دالة مختصرة لإصدار حدث بسرعة دون بناء كائن HealthEvent يدوياً.
  void emitQuick(
    HealthEventType type, {
    required String sourceModule,
    String? profileId,
    Map<String, dynamic>? data,
  }) {
    emit(HealthEvent(
      type: type,
      sourceModule: sourceModule,
      profileId: profileId,
      data: data,
    ));
  }

  /// إزالة كل المستمعين (يُستخدم غالباً في الاختبارات فقط).
  void clearAllListeners() {
    _listeners.clear();
    _globalListeners.clear();
  }
}
