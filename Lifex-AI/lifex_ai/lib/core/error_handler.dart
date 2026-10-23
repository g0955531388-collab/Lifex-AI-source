/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: error_handler.dart
/// المسار: lib/core/error_handler.dart
/// الوصف: نظام موحّد للتعامل مع الأخطاء وتسجيلها عبر كل وحدات التطبيق،
/// بما فيها الأخطاء الحرجة المرتبطة بالبيانات الصحية.
/// =============================================================
library;

import 'health_event_manager.dart';

/// تصنيف مستوى خطورة الخطأ.
enum ErrorSeverity {
  info, // معلومة فقط، لا تستدعي أي إجراء
  warning, // تحذير، لا يوقف سير العمل
  error, // خطأ يحتاج معالجة
  critical, // خطأ حرج قد يمس سلامة بيانات صحية أو حياة المستخدم
}

/// نموذج موحّد لأي خطأ يحدث داخل النظام.
class AppError {
  final String code;
  final String message;
  final ErrorSeverity severity;
  final String sourceModule;
  final DateTime timestamp;
  final Object? originalException;
  final StackTrace? stackTrace;

  AppError({
    required this.code,
    required this.message,
    required this.severity,
    required this.sourceModule,
    DateTime? timestamp,
    this.originalException,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] ($sourceModule) $code: $message';

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'severity': severity.name,
        'sourceModule': sourceModule,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// توقيع دالة الاستماع للأخطاء (Callback) لإعلام واجهات المستخدم أو
/// أنظمة التنبيه عند حدوث خطأ.
typedef ErrorListener = void Function(AppError error);

/// المدير المركزي للأخطاء. كل وحدة في التطبيق يجب أن تمرّر أخطاءها
/// عبر هذا المدير بدلاً من طباعتها مباشرة أو تجاهلها.
class ErrorHandler {
  ErrorHandler._internal();
  static final ErrorHandler instance = ErrorHandler._internal();

  final List<AppError> _errorLog = [];
  final List<ErrorListener> _listeners = [];

  /// سجل الأخطاء المحفوظة في الذاكرة أثناء الجلسة الحالية (للقراءة فقط).
  List<AppError> get errorLog => List.unmodifiable(_errorLog);

  /// تسجيل مستمع جديد يتم إعلامه عند وقوع أي خطأ (مثلاً لعرض Snackbar).
  void addListener(ErrorListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ErrorListener listener) {
    _listeners.remove(listener);
  }

  /// الإبلاغ عن خطأ جديد. هذه هي نقطة الدخول الموحدة لكل وحدات التطبيق.
  void report(
    String code,
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    required String sourceModule,
    Object? exception,
    StackTrace? stackTrace,
    String? profileId,
  }) {
    final error = AppError(
      code: code,
      message: message,
      severity: severity,
      sourceModule: sourceModule,
      originalException: exception,
      stackTrace: stackTrace,
    );

    _errorLog.add(error);

    for (final listener in _listeners) {
      listener(error);
    }

    // الأخطاء الحرجة (critical) المتعلقة بالسلامة الصحية يجب أن تصل
    // لأنظمة التنبيه الفوري، وليس فقط للسجل.
    if (severity == ErrorSeverity.critical) {
      _escalateCritical(error, profileId: profileId);
    }
  }

  /// تصعيد الأخطاء الحرجة عبر ناقل الأحداث المركزي (HealthEventManager)
  /// بدلاً من استيراد HealthAlertDispatcher مباشرة هنا — لأن هذا الملف
  /// جزء من core/ ويجب ألا يعتمد على أي وحدة من features/ (اتجاه
  /// الاعتماديات الصحيح هو أن تعتمد features/ على core/، وليس العكس).
  /// أي وحدة تريد الاستجابة لهذا الحدث (مثل health_alert_dispatcher.dart)
  /// تشترك فيه عبر HealthEventManager.instance.subscribe(...) بدلاً من
  /// أن يستدعيها هذا الملف مباشرة.
  void _escalateCritical(AppError error, {String? profileId}) {
    HealthEventManager.instance.emitQuick(
      HealthEventType.custom,
      sourceModule: error.sourceModule,
      profileId: profileId,
      data: {
        'escalationReason': 'critical_system_error',
        'errorCode': error.code,
        'errorMessage': error.message,
      },
    );
  }

  /// مسح السجل (يُستخدم عادة عند تسجيل الخروج أو لأغراض الاختبار).
  void clearLog() {
    _errorLog.clear();
  }

  /// استخراج آخر n من الأخطاء المسجّلة.
  List<AppError> recentErrors({int count = 20}) {
    if (_errorLog.length <= count) return List.unmodifiable(_errorLog);
    return List.unmodifiable(
      _errorLog.sublist(_errorLog.length - count),
    );
  }
}
