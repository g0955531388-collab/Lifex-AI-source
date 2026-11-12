/// =============================================================
/// Lifex-AI — مخزن مواعيد المستخدم المحلي (Calendar domain)
/// الملف: user_appointment_store.dart
/// Appointment ≠ Encounter. مصدر user_created قابل للحذف المباشر.
/// =============================================================
library lifex_ai.features.scheduling.user_appointment_store;

enum AppointmentLifecycle {
  draft,
  requested,
  pending,
  confirmed,
  rescheduleRequested,
  rescheduled,
  cancelled,
  completed,
  noShow,
  expired,
  failed,
}

enum AppointmentSourceOwnership {
  userCreated,
  providerCreated,
  organizationControlled,
}

enum AppointmentRecurrence { none, daily, weekly, monthly, yearly, custom }

class UserAppointment {
  UserAppointment({
    required this.id,
    required this.title,
    required this.dateIso,
    required this.timeHm,
    required this.type,
    this.place = '',
    this.timezone = 'local',
    this.notes = '',
    this.reminderMinutes = 30,
    this.recurrence = AppointmentRecurrence.none,
    this.status = AppointmentLifecycle.confirmed,
    this.source = AppointmentSourceOwnership.userCreated,
    this.providerId,
    this.endTimeHm,
  });

  final String id;
  String title;
  String dateIso;
  String timeHm;
  String? endTimeHm;
  String type;
  String place;
  String timezone;
  String notes;
  int reminderMinutes;
  AppointmentRecurrence recurrence;
  AppointmentLifecycle status;
  AppointmentSourceOwnership source;
  String? providerId;

  bool get canDirectDelete =>
      source == AppointmentSourceOwnership.userCreated &&
      status != AppointmentLifecycle.cancelled;

  bool get canDirectEdit =>
      source == AppointmentSourceOwnership.userCreated &&
      status != AppointmentLifecycle.cancelled &&
      status != AppointmentLifecycle.completed;

  DateTime? get date {
    final d = DateTime.tryParse(dateIso);
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': dateIso,
        'time': timeHm,
        'endTime': endTimeHm,
        'type': type,
        'place': place,
        'timezone': timezone,
        'notes': notes,
        'reminderMinutes': reminderMinutes,
        'recurrence': recurrence.name,
        'status': status.name,
        'source': source.name,
        'providerId': providerId,
      };

  factory UserAppointment.fromMap(Map<String, dynamic> m) {
    AppointmentRecurrence rec = AppointmentRecurrence.none;
    for (final v in AppointmentRecurrence.values) {
      if (v.name == m['recurrence']?.toString()) rec = v;
    }
    AppointmentLifecycle life = AppointmentLifecycle.confirmed;
    for (final v in AppointmentLifecycle.values) {
      if (v.name == m['status']?.toString()) life = v;
    }
    AppointmentSourceOwnership src = AppointmentSourceOwnership.userCreated;
    final rawSrc = m['source']?.toString();
    if (rawSrc == 'provider_created' || rawSrc == 'providerCreated') {
      src = AppointmentSourceOwnership.providerCreated;
    } else if (rawSrc == 'organization_controlled' ||
        rawSrc == 'organizationControlled') {
      src = AppointmentSourceOwnership.organizationControlled;
    }
    return UserAppointment(
      id: m['id']?.toString() ??
          'apt_${DateTime.now().millisecondsSinceEpoch}',
      title: m['title']?.toString() ?? '',
      dateIso: m['date']?.toString() ?? '',
      timeHm: m['time']?.toString() ?? '09:00',
      endTimeHm: m['endTime']?.toString(),
      type: m['type']?.toString() ?? 'other',
      place: m['place']?.toString() ?? '',
      timezone: m['timezone']?.toString() ?? 'local',
      notes: m['notes']?.toString() ?? '',
      reminderMinutes: (m['reminderMinutes'] as num?)?.toInt() ?? 30,
      recurrence: rec,
      status: life,
      source: src,
      providerId: m['providerId']?.toString(),
    );
  }

  String spokenSummaryAr() {
    final st = status == AppointmentLifecycle.cancelled ? 'ملغى' : 'مؤكد';
    return '$timeHm $title. النوع $type. $st. ${place.isEmpty ? '' : 'المكان $place.'}';
  }
}

class UserAppointmentStore {
  UserAppointmentStore([List<UserAppointment>? seed])
      : _items = List.of(seed ?? const []);

  final List<UserAppointment> _items;

  List<UserAppointment> get all => List.unmodifiable(_items);

  factory UserAppointmentStore.fromMaps(List<dynamic>? raw) {
    final store = UserAppointmentStore();
    if (raw == null) return store;
    for (final item in raw) {
      if (item is Map) {
        store._items.add(
          UserAppointment.fromMap(Map<String, dynamic>.from(item)),
        );
      }
    }
    return store;
  }

  List<Map<String, dynamic>> toMaps() =>
      _items.map((e) => e.toMap()).toList();

  List<UserAppointment> forDay(DateTime day) {
    final list = _items.where((a) {
      final d = a.date;
      return d != null &&
          d.year == day.year &&
          d.month == day.month &&
          d.day == day.day &&
          a.status != AppointmentLifecycle.cancelled;
    }).toList();
    list.sort((a, b) => a.timeHm.compareTo(b.timeHm));
    return list;
  }

  int countOn(DateTime day) => forDay(day).length;

  UserAppointment add(UserAppointment a) {
    _items.add(a);
    return a;
  }

  bool update(String id, UserAppointment next) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return false;
    if (!_items[i].canDirectEdit) return false;
    _items[i] = next;
    return true;
  }

  /// حذف مباشر للمستخدم فقط؛ غير ذلك → إلغاء/طلب.
  String removeOrCancel(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return 'not_found';
    final a = _items[i];
    if (a.canDirectDelete) {
      _items.removeAt(i);
      return 'deleted';
    }
    a.status = AppointmentLifecycle.cancelled;
    return 'cancelled_request';
  }

  String spokenDayAr(DateTime day) {
    final list = forDay(day);
    if (list.isEmpty) {
      return 'لا مواعيد في ${day.year}/${day.month}/${day.day}.';
    }
    final parts = list.map((e) => e.spokenSummaryAr()).join(' ثم ');
    return 'لديك ${list.length} موعد في هذا اليوم. $parts';
  }

  String spokenMonthSummaryAr(DateTime month) {
    var n = 0;
    for (final a in _items) {
      final d = a.date;
      if (d != null &&
          d.year == month.year &&
          d.month == month.month &&
          a.status != AppointmentLifecycle.cancelled) {
        n++;
      }
    }
    return n == 0
        ? 'لا مواعيد في هذا الشهر.'
        : 'لديك $n موعد في هذا الشهر.';
  }
}
