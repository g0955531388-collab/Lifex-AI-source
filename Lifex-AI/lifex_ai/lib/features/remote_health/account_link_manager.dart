/// =============================================================
/// Lifex-AI — المراقبة الصحية عن بعد
/// الملف: account_link_manager.dart
/// المسار: lib/features/remote_health/account_link_manager.dart
/// الوصف: إدارة طلبات الربط بين حسابين مختلفين (مثلاً ابن يطلب متابعة
/// حساب والده المستقل) — يتطلب دائماً موافقة الطرف الآخر صراحة.
/// =============================================================
library;

enum LinkRequestStatus { pending, approved, rejected, revoked }

class AccountLinkRequest {
  final String requestId;
  final String requesterLifexId;
  final String targetLifexId;
  LinkRequestStatus status;
  final DateTime createdAt;
  DateTime? respondedAt;

  AccountLinkRequest({
    required this.requestId,
    required this.requesterLifexId,
    required this.targetLifexId,
    this.status = LinkRequestStatus.pending,
    DateTime? createdAt,
    this.respondedAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// مدير طلبات ربط الحسابات — لا يتم أي ربط تلقائياً؛ يتطلب دائماً فعلاً
/// إيجابياً صريحاً (موافقة) من الحساب المستهدف.
class AccountLinkManager {
  AccountLinkManager();

  final Map<String, AccountLinkRequest> _requests = {};

  AccountLinkRequest createRequest({
    required String requestId,
    required String requesterLifexId,
    required String targetLifexId,
  }) {
    final request = AccountLinkRequest(
      requestId: requestId,
      requesterLifexId: requesterLifexId,
      targetLifexId: targetLifexId,
    );
    _requests[requestId] = request;
    return request;
  }

  /// موافقة صريحة من صاحب الحساب المستهدف فقط.
  bool approve(String requestId) {
    final request = _requests[requestId];
    if (request == null || request.status != LinkRequestStatus.pending) {
      return false;
    }
    request.status = LinkRequestStatus.approved;
    request.respondedAt = DateTime.now();
    return true;
  }

  bool reject(String requestId) {
    final request = _requests[requestId];
    if (request == null || request.status != LinkRequestStatus.pending) {
      return false;
    }
    request.status = LinkRequestStatus.rejected;
    request.respondedAt = DateTime.now();
    return true;
  }

  /// إلغاء ربط قائم بالفعل، بمبادرة من أي من الطرفين في أي وقت.
  bool revoke(String requestId) {
    final request = _requests[requestId];
    if (request == null || request.status != LinkRequestStatus.approved) {
      return false;
    }
    request.status = LinkRequestStatus.revoked;
    return true;
  }

  List<AccountLinkRequest> pendingRequestsFor(String targetLifexId) {
    return _requests.values
        .where((r) =>
            r.targetLifexId == targetLifexId &&
            r.status == LinkRequestStatus.pending)
        .toList();
  }

  List<AccountLinkRequest> approvedLinksFor(String lifexId) {
    return _requests.values
        .where((r) =>
            (r.requesterLifexId == lifexId || r.targetLifexId == lifexId) &&
            r.status == LinkRequestStatus.approved)
        .toList();
  }
}
