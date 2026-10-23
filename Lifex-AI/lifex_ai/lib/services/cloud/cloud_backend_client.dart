/// =============================================================
/// Lifex-AI — الخدمات السحابية
/// الملف: cloud_backend_client.dart
/// المسار: lib/services/cloud/cloud_backend_client.dart
/// الوصف: عميل HTTP رقيق للتواصل مع خادم Lifex-AI الخلفي (Backend).
/// يستخدم نفس مبدأ "تعريف التطبيق" (App Attribution) المتبع في
/// ai_service_router.dart للحفاظ على اتساق الهوية عبر كل الاتصالات
/// الخارجية للتطبيق.
///
/// ⚠️ لا يحتوي هذا الملف على أي رابط خادم فعلي يعمل حالياً — [baseUrl]
/// يجب استبداله برابط خادم Lifex-AI الحقيقي عند توفره.
/// =============================================================
library lifex_ai.services.cloud.cloud_backend_client;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_constants.dart';
import '../../core/error_handler.dart';
import 'cloud_sync_manager.dart';

/// عميل الاتصال بالخادم السحابي الخلفي لـ Lifex-AI.
class CloudBackendClient {
  CloudBackendClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  /// فراغ أو example.com أو placeholder ليس خادماً عاملاً.
  bool get isEndpointConfigured {
    final url = baseUrl.trim();
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return !lower.contains('example.com') && !lower.contains('placeholder');
  }

  static final String _installId =
      'install-${DateTime.now().microsecondsSinceEpoch}';

  /// يطلب معرّف ملف من الخادم. يعيد null إن لم يكن الخادم مضبوطاً أو رفض الطلب.
  /// [deviceId] معرّف تثبيت يرسله التطبيق، وليس إثبات هوية.
  Future<String?> requestServerProfileId({
    String? displayName,
    String? deviceId,
  }) async {
    if (!isEndpointConfigured) return null;
    final sentDeviceId =
        (deviceId == null || deviceId.trim().isEmpty) ? _installId : deviceId.trim();
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _defaultHeaders,
        body: jsonEncode({
          'deviceId': sentDeviceId,
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final profileId = decoded['profileId'];
      if (profileId is! String || profileId.trim().isEmpty) return null;
      return profileId.trim();
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'CLOUD_PROFILE_ID_FAILED',
        'تعذّر إصدار profileId من الخادم. يُستخدم معرّف محلي.',
        sourceModule: 'cloud_backend_client',
        severity: ErrorSeverity.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'X-App-Name': AppConstants.appName,
        'X-App-Version': AppConstants.appVersion,
      };

  /// دفع كيان واحد (ملف صحي، موعد، تبرع...) للخادم. تُرجع true عند
  /// النجاح، وfalse عند أي فشل (سيُعاد المحاولة لاحقاً من CloudSyncManager).
  Future<bool> pushEntity({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    if (!isEndpointConfigured) return false;
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: _defaultHeaders,
        body: jsonEncode({
          'profileId': entityId,
          'entityType': entityType.name,
          'payload': payload,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'CLOUD_PUSH_FAILED',
        'فشل رفع البيانات للخادم السحابي (${entityType.name}/$entityId).',
        sourceModule: 'cloud_backend_client',
        severity: ErrorSeverity.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// جلب أحدث نسخة من كيان معيّن من الخادم (يُستخدم عند تسجيل الدخول
  /// من جهاز جديد، أو عند حل تعارض بين نسخة محلية وأخرى سحابية).
  Future<Map<String, dynamic>?> pullEntity({
    required SyncEntityType entityType,
    required String entityId,
  }) async {
    if (!isEndpointConfigured) return null;
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '$baseUrl/sync/pull?profileId=${Uri.encodeQueryComponent(entityId)}',
        ),
        headers: _defaultHeaders,
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final payload = decoded['payload'];
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
      return Map<String, dynamic>.from(decoded);
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'CLOUD_PULL_FAILED',
        'فشل جلب البيانات من الخادم السحابي (${entityType.name}/$entityId).',
        sourceModule: 'cloud_backend_client',
        severity: ErrorSeverity.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
