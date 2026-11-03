/// =============================================================
/// Lifex-AI — صندوق المشروع
/// الملف: unified_booking_service.dart
/// حجز واحد لكل الوحدات، مع رمز تحقق محلي.
/// =============================================================
library lifex_ai.features.network_box.unified_booking_service;

import 'profile_box_store.dart';

class UnifiedBooking {
  UnifiedBooking({
    required this.id,
    required this.unitId,
    required this.title,
    required this.place,
    required this.scheduledAt,
    required this.accessCode,
    this.status = 'localDraft',
  });

  final String id;
  final String unitId;
  final String title;
  final String place;
  final DateTime scheduledAt;
  final String accessCode;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'title': title,
        'place': place,
        'scheduledAt': scheduledAt.toIso8601String(),
        'accessCode': accessCode,
        'status': status,
      };

  factory UnifiedBooking.fromJson(Map<String, dynamic> json) => UnifiedBooking(
        id: json['id'] as String,
        unitId: json['unitId'] as String? ?? 'hospital',
        title: json['title'] as String? ?? '',
        place: json['place'] as String? ?? '',
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        accessCode: json['accessCode'] as String? ?? '',
        status: json['status'] as String? ?? 'localDraft',
      );
}

class UnifiedBookingService {
  UnifiedBookingService(this.store);

  final ProfileBoxStore store;

  List<UnifiedBooking> all() => store
      .activeRecords(BoxKeys.bookings)
      .map(UnifiedBooking.fromJson)
      .toList();

  UnifiedBooking add({
    required String unitId,
    required String title,
    required String place,
    required DateTime scheduledAt,
  }) {
    final id = 'BKG-${DateTime.now().millisecondsSinceEpoch}';
    final booking = UnifiedBooking(
      id: id,
      unitId: unitId,
      title: title,
      place: place,
      scheduledAt: scheduledAt,
      accessCode: generateAccessCode(id),
      status: 'awaitingServer',
    );
    store.add(BoxKeys.bookings, booking.toJson());
    return booking;
  }

  bool updateById(
    String id, {
    required String unitId,
    required String title,
    required String place,
    required DateTime scheduledAt,
  }) =>
      store.updateById(BoxKeys.bookings, id, {
        'unitId': unitId,
        'title': title,
        'place': place,
        'scheduledAt': scheduledAt.toIso8601String(),
      });

  bool archiveById(String id) => store.archiveById(BoxKeys.bookings, id);

  @Deprecated('Use archiveById with the booking ID.')
  void removeAt(int index) {
    final items = all();
    if (index < 0 || index >= items.length) return;
    archiveById(items[index].id);
  }

  static String generateAccessCode(String seed) {
    final n = seed.hashCode.abs() % 1000000;
    return 'LX${n.toString().padLeft(6, '0')}';
  }

  /// أرقام الدور العامة بلا أسماء.
  List<Map<String, String>> publicQueue() {
    final now = DateTime.now();
    return all()
        .where((booking) => !booking.scheduledAt.isBefore(now.subtract(
              const Duration(days: 1),
            )))
        .map((booking) => {
              'code': booking.accessCode,
              'unit': booking.unitId,
              'time':
                  '${booking.scheduledAt.year}/${booking.scheduledAt.month}/${booking.scheduledAt.day}',
            })
        .toList();
  }
}
