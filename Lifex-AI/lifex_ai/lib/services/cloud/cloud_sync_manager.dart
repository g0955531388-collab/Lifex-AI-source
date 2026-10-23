/// =============================================================
/// Lifex-AI — الخدمات السحابية
/// الملف: cloud_sync_manager.dart
/// المسار: lib/services/cloud/cloud_sync_manager.dart
/// الوصف: مزامنة البيانات المحلية (ملفات صحية، مواعيد، تبرعات...) مع
/// خادم سحابي، بنمط Offline-First: كل تعديل محلي يُسجَّل في طابور
/// انتظار (Queue) أولاً، ويُزامَن فعلياً عند توفر الإنترنت، دون أن
/// يعتمد أي جزء من التطبيق على الاتصال السحابي ليعمل.
///
/// ⚠️ هذا الملف بنية تنظيمية فقط. الاتصال الفعلي بخادم حقيقي (Firebase/
/// خادم Lifex-AI الخاص) يتطلب اعتماد بنية خلفية (Backend) كاملة خارج
/// نطاق تطبيق Flutter نفسه.
/// =============================================================
library lifex_ai.services.cloud.cloud_sync_manager;

import '../../core/error_handler.dart';
import 'cloud_backend_client.dart';

/// نوع الكيان الذي يحتاج مزامنة (يُوسَّع لاحقاً لأي وحدة جديدة).
enum SyncEntityType {
  healthProfile,
  appointment,
  donation,
  walletTransaction,
}

/// عملية مزامنة واحدة معلَّقة في الطابور المحلي.
class PendingSyncOperation {
  final String operationId;
  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  PendingSyncOperation({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// مدير المزامنة السحابية — نمط Offline-First كامل.
class CloudSyncManager {
  CloudSyncManager({required this.backendClient});

  final CloudBackendClient backendClient;
  final List<PendingSyncOperation> _pendingQueue = [];
  bool _isSyncing = false;

  static const int _maxRetriesBeforeGivingUp = 5;

  /// إضافة عملية جديدة لطابور المزامنة — تُستدعى من أي وحدة عند حدوث
  /// تعديل محلي (مثلاً بعد إضافة حساسية جديدة للملف الصحي).
  void enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    _pendingQueue.add(PendingSyncOperation(
      operationId: 'SYNC-${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    ));
  }

  /// محاولة مزامنة كل العمليات المعلَّقة الآن (تُستدعى دورياً أو عند
  /// استعادة الاتصال بالإنترنت).
  Future<String?> requestServerProfileId({String? displayName}) {
    return backendClient.requestServerProfileId(displayName: displayName);
  }

  Future<void> syncPendingOperations() async {
    if (_isSyncing || _pendingQueue.isEmpty) return;
    if (!backendClient.isEndpointConfigured) return;
    _isSyncing = true;

    final stillPending = <PendingSyncOperation>[];

    for (final operation in List<PendingSyncOperation>.from(_pendingQueue)) {
      final success = await backendClient.pushEntity(
        entityType: operation.entityType,
        entityId: operation.entityId,
        payload: operation.payload,
      );

      if (!success) {
        operation.retryCount++;
        if (operation.retryCount < _maxRetriesBeforeGivingUp) {
          stillPending.add(operation);
        } else {
          ErrorHandler.instance.report(
            'CLOUD_SYNC_GAVE_UP',
            'فشلت مزامنة العملية ${operation.operationId} بعد '
                '${operation.retryCount} محاولات. البيانات محفوظة محلياً '
                'فقط الآن.',
            sourceModule: 'cloud_sync_manager',
            severity: ErrorSeverity.warning,
          );
        }
      }
    }

    _pendingQueue
      ..clear()
      ..addAll(stillPending);
    _isSyncing = false;
  }

  int get pendingOperationsCount => _pendingQueue.length;

  bool get hasPendingChanges => _pendingQueue.isNotEmpty;

  List<PendingSyncOperation> get pendingOperations =>
      List.unmodifiable(_pendingQueue);

  bool get isEndpointConfigured => backendClient.isEndpointConfigured;
}
