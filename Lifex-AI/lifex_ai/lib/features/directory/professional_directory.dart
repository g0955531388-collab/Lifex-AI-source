/// دليل مهني محلي. القائمة ليست تشخيصاً ولا حجزاً مؤكداً.
library lifex_ai.features.directory.professional_directory;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfessionCategory {
  const ProfessionCategory._();

  static const medical = 'medical';
  static const legal = 'legal';
  static const engineering = 'engineering';
  static const education = 'education';
  static const consulting = 'consulting';
  static const crafts = 'crafts';
  static const grooming = 'grooming';
  static const care = 'care';
  static const trade = 'trade';
  static const general = 'general';

  static const all = [
    medical,
    legal,
    engineering,
    education,
    consulting,
    crafts,
    grooming,
    care,
    trade,
    general,
  ];
}

class DirectoryTheme {
  const DirectoryTheme({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;
}

const directoryThemes = <DirectoryTheme>[
  DirectoryTheme(id: 'medical', nameAr: 'طبي', nameEn: 'Medical'),
  DirectoryTheme(id: 'legal', nameAr: 'قانوني', nameEn: 'Legal'),
  DirectoryTheme(id: 'engineering', nameAr: 'هندسي', nameEn: 'Engineering'),
  DirectoryTheme(id: 'education', nameAr: 'تعليمي', nameEn: 'Education'),
  DirectoryTheme(id: 'consulting', nameAr: 'استشارات', nameEn: 'Consulting'),
  DirectoryTheme(id: 'crafts', nameAr: 'حرف', nameEn: 'Crafts'),
  DirectoryTheme(id: 'grooming', nameAr: 'عناية', nameEn: 'Grooming'),
  DirectoryTheme(id: 'care', nameAr: 'رعاية', nameEn: 'Care'),
  DirectoryTheme(id: 'trade', nameAr: 'تجارة', nameEn: 'Trade'),
  DirectoryTheme(id: 'general', nameAr: 'عام', nameEn: 'General'),
];

DirectoryTheme directoryThemeById(String id) {
  for (final theme in directoryThemes) {
    if (theme.id == id) return theme;
  }
  return directoryThemes.last;
}

class DirectoryPoint {
  const DirectoryPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
      };

  static DirectoryPoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = _double(raw['lat']);
    final lng = _double(raw['lng']);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return DirectoryPoint(latitude: lat, longitude: lng);
  }
}

class ProfessionalProfile {
  const ProfessionalProfile({
    required this.id,
    required this.fullName,
    required this.category,
    required this.specialty,
    required this.country,
    required this.city,
    required this.address,
    required this.point,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.trialStart,
    required this.expiry,
    required this.isPaid,
    required this.paymentProvider,
    required this.themeId,
    required this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String category;
  final String specialty;
  final String country;
  final String city;
  final String address;
  final DirectoryPoint? point;
  final String phone;
  final String whatsapp;
  final String email;
  final DateTime trialStart;
  final DateTime expiry;
  final bool isPaid;
  final String? paymentProvider;
  final String themeId;
  final String avatarUrl;

  bool trialActive(DateTime now) =>
      !isPaid && !now.isBefore(trialStart) && now.isBefore(expiry);

  bool listingActive(DateTime now) =>
      trialActive(now) || (isPaid && now.isBefore(expiry));

  ProfessionalProfile copyWith({
    String? fullName,
    String? category,
    String? specialty,
    String? country,
    String? city,
    String? address,
    DirectoryPoint? point,
    bool clearPoint = false,
    String? phone,
    String? whatsapp,
    String? email,
    String? themeId,
    String? avatarUrl,
  }) {
    return ProfessionalProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      category: category ?? this.category,
      specialty: specialty ?? this.specialty,
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      point: clearPoint ? null : (point ?? this.point),
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      trialStart: trialStart,
      expiry: expiry,
      isPaid: isPaid,
      paymentProvider: paymentProvider,
      themeId: themeId ?? this.themeId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'category': category,
        'specialty': specialty,
        'country': country,
        'city': city,
        'address': address,
        'point': point?.toJson(),
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'trialStart': trialStart.toUtc().toIso8601String(),
        'expiry': expiry.toUtc().toIso8601String(),
        'isPaid': isPaid,
        'paymentProvider': paymentProvider,
        'themeId': themeId,
        'avatarUrl': avatarUrl,
      };

  static ProfessionalProfile? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['fullName']?.toString().trim() ?? '';
    final category = json['category']?.toString() ?? '';
    final specialty = json['specialty']?.toString().trim() ?? '';
    final phone = json['phone']?.toString().trim() ?? '';
    final trial = DateTime.tryParse(json['trialStart']?.toString() ?? '');
    final expiry = DateTime.tryParse(json['expiry']?.toString() ?? '');
    if (id.isEmpty ||
        name.isEmpty ||
        !ProfessionCategory.all.contains(category) ||
        specialty.isEmpty ||
        phone.isEmpty ||
        trial == null ||
        expiry == null) {
      return null;
    }
    return ProfessionalProfile(
      id: id,
      fullName: name,
      category: category,
      specialty: specialty,
      country: json['country']?.toString().trim() ?? '',
      city: json['city']?.toString().trim() ?? '',
      address: json['address']?.toString().trim() ?? '',
      point: DirectoryPoint.fromJson(json['point']),
      phone: phone,
      whatsapp: json['whatsapp']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      trialStart: trial.toLocal(),
      expiry: expiry.toLocal(),
      isPaid: json['isPaid'] == true,
      paymentProvider: json['paymentProvider']?.toString(),
      themeId: directoryThemeById(json['themeId']?.toString() ?? '').id,
      avatarUrl: json['avatarUrl']?.toString().trim() ?? '',
    );
  }
}

const directoryTrialLength = Duration(hours: 48);

ProfessionalProfile? newProfessionalProfile({
  required String id,
  required String fullName,
  required String category,
  required String specialty,
  required String phone,
  required DateTime now,
  String country = '',
  String city = '',
  String address = '',
  DirectoryPoint? point,
  String whatsapp = '',
  String email = '',
  String themeId = 'general',
  String avatarUrl = '',
}) {
  final name = fullName.trim();
  final focus = specialty.trim();
  final line = phone.trim();
  if (name.isEmpty ||
      focus.isEmpty ||
      line.isEmpty ||
      !ProfessionCategory.all.contains(category)) {
    return null;
  }
  final start = now.toLocal();
  return ProfessionalProfile(
    id: id,
    fullName: name,
    category: category,
    specialty: focus,
    country: country.trim(),
    city: city.trim(),
    address: address.trim(),
    point: point,
    phone: line,
    whatsapp: whatsapp.trim(),
    email: email.trim(),
    trialStart: start,
    expiry: start.add(directoryTrialLength),
    isPaid: false,
    paymentProvider: null,
    themeId: directoryThemeById(themeId).id,
    avatarUrl: avatarUrl.trim(),
  );
}

class DirectoryPaymentAttempt {
  const DirectoryPaymentAttempt({
    required this.charged,
    required this.isPaid,
    required this.messageAr,
    required this.messageEn,
  });

  final bool charged;
  final bool isPaid;
  final String messageAr;
  final String messageEn;
}

/// لا يُرسل مبلغ. شام كاش والمحفظة بلا تأكيد مرخّص.
DirectoryPaymentAttempt refuseDirectoryPayment(String provider) {
  final name = provider.trim().isEmpty ? 'payment' : provider.trim();
  return DirectoryPaymentAttempt(
    charged: false,
    isPaid: false,
    messageAr:
        'لم يُخصم مبلغ. $name بلا تأكيد من جهة مرخّصة، والحالة تبقى غير مدفوعة.',
    messageEn:
        'No amount was charged. $name has no licensed confirmation, and the status stays unpaid.',
  );
}

List<ProfessionalProfile> searchProfessionals(
  List<ProfessionalProfile> profiles,
  String query,
) {
  final folded = query.trim().toLowerCase();
  if (folded.isEmpty) return profiles;
  return profiles.where((profile) {
    final haystack = [
      profile.fullName,
      profile.specialty,
      profile.category,
      profile.country,
      profile.city,
      profile.address,
    ].join(' ').toLowerCase();
    return haystack.contains(folded);
  }).toList();
}

class ProfessionalDirectoryBook {
  const ProfessionalDirectoryBook();

  static const storageKey = 'lifex_professional_directory_v1';

  Future<List<ProfessionalProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) =>
              ProfessionalProfile.fromJson(Map<String, dynamic>.from(item)))
          .whereType<ProfessionalProfile>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<ProfessionalProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }
}

double? _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
