/// =============================================================
/// Lifex-AI — وحدة الأسنان
/// الملف: dental_lab_manager.dart
/// المسار: lib/features/dental/dental_lab_manager.dart
/// الوصف: إدارة طلبات مخابر الأسنان الفنية (تركيبات، تقويم، زراعة) —
/// تنسيق بين طبيب الأسنان والمخبر الفني الذي يصنّع القطعة المطلوبة.
/// =============================================================
library;

enum DentalLabItemType { crown, bridge, denture, orthodonticAppliance, implantComponent }

enum DentalLabOrderStatus { submitted, inProduction, readyForFitting, delivered }

class DentalLabOrder {
  final String orderId;
  final String patientProfileId;
  final String dentalProviderId;
  final DentalLabItemType itemType;
  DentalLabOrderStatus status;
  final DateTime submittedAt;
  DateTime? estimatedCompletionDate;

  DentalLabOrder({
    required this.orderId,
    required this.patientProfileId,
    required this.dentalProviderId,
    required this.itemType,
    this.status = DentalLabOrderStatus.submitted,
    DateTime? submittedAt,
    this.estimatedCompletionDate,
  }) : submittedAt = submittedAt ?? DateTime.now();
}

/// مدير طلبات مخابر الأسنان.
class DentalLabManager {
  DentalLabManager();

  final Map<String, DentalLabOrder> _orders = {};
  int _counter = 0;

  DentalLabOrder submitOrder({
    required String patientProfileId,
    required String dentalProviderId,
    required DentalLabItemType itemType,
    DateTime? estimatedCompletionDate,
  }) {
    _counter++;
    final order = DentalLabOrder(
      orderId: 'DLB-$_counter',
      patientProfileId: patientProfileId,
      dentalProviderId: dentalProviderId,
      itemType: itemType,
      estimatedCompletionDate: estimatedCompletionDate,
    );
    _orders[order.orderId] = order;
    return order;
  }

  void advanceStatus(String orderId, DentalLabOrderStatus newStatus) {
    _orders[orderId]?.status = newStatus;
  }

  List<DentalLabOrder> ordersForProvider(String dentalProviderId) {
    return _orders.values
        .where((o) => o.dentalProviderId == dentalProviderId)
        .toList();
  }
}
