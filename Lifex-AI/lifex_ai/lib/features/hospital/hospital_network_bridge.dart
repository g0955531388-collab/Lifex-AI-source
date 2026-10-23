/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_network_bridge.dart
/// المسار: lib/features/hospital/hospital_network_bridge.dart
/// الوصف: طبقة تجريد للربط بين مستشفيات متعددة داخل شبكة Lifex-AI —
/// مفيدة لتحويل المرضى أو مشاركة توفر أسرّة الطوارئ بين مستشفيات قريبة.
///
/// ⚠️ حدود واقعية: الربط الفعلي بين أنظمة مستشفيات مختلفة يتطلب اتفاقيات
/// تبادل بيانات (Data Sharing Agreements) وامتثالاً قانونياً لكل جهة على
/// حدة، وخادماً مركزياً حقيقياً. هذا الملف يوفر بنية التنسيق المنطقي فقط.
/// =============================================================
library;

import 'dart:math' as math;

class HospitalNetworkNode {
  final String hospitalId;
  final double latitude;
  final double longitude;
  bool isOnline;

  HospitalNetworkNode({
    required this.hospitalId,
    required this.latitude,
    required this.longitude,
    this.isOnline = true,
  });
}

class TransferRequest {
  final String requestId;
  final String patientProfileId;
  final String fromHospitalId;
  final String toHospitalId;
  final String reasonAr;
  bool accepted;

  TransferRequest({
    required this.requestId,
    required this.patientProfileId,
    required this.fromHospitalId,
    required this.toHospitalId,
    required this.reasonAr,
    this.accepted = false,
  });
}

/// جسر الربط العالمي بين المستشفيات.
class HospitalNetworkBridge {
  HospitalNetworkBridge();

  final Map<String, HospitalNetworkNode> _nodes = {};
  final List<TransferRequest> _transferRequests = [];
  int _counter = 0;

  void registerNode(HospitalNetworkNode node) {
    _nodes[node.hospitalId] = node;
  }

  /// حساب المسافة التقريبية (كم) بين مستشفيين باستخدام صيغة Haversine
  /// القياسية، لتحديد أقرب مستشفى بديل عند الحاجة لتحويل مريض.
  double _distanceKm(HospitalNetworkNode a, HospitalNetworkNode b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// إيجاد أقرب مستشفى متصل بالشبكة وفعّال حالياً (غير المستشفى الحالي).
  HospitalNetworkNode? findNearestAlternative(String currentHospitalId) {
    final current = _nodes[currentHospitalId];
    if (current == null) return null;

    final candidates =
        _nodes.values.where((n) => n.hospitalId != currentHospitalId && n.isOnline);
    if (candidates.isEmpty) return null;

    return candidates.reduce((a, b) =>
        _distanceKm(current, a) <= _distanceKm(current, b) ? a : b);
  }

  TransferRequest createTransferRequest({
    required String patientProfileId,
    required String fromHospitalId,
    required String toHospitalId,
    required String reasonAr,
  }) {
    _counter++;
    final request = TransferRequest(
      requestId: 'TRF-$_counter',
      patientProfileId: patientProfileId,
      fromHospitalId: fromHospitalId,
      toHospitalId: toHospitalId,
      reasonAr: reasonAr,
    );
    _transferRequests.add(request);
    return request;
  }

  bool acceptTransfer(String requestId) {
    final matches =
        _transferRequests.where((r) => r.requestId == requestId).toList();
    if (matches.isEmpty) return false;
    matches.first.accepted = true;
    return true;
  }
}
