/// =============================================================
/// Lifex-AI — مصادر اختيار الأشخاص
/// الملف: person_selection_sources.dart
/// المسار: lib/features/trusted_person/person_selection_sources.dart
/// الوصف: منتقي جهات النظام + مسارات CALL_LOG/SMS الصادقة + دليل Lifex.
/// =============================================================
library lifex_ai.features.trusted_person.person_selection_sources;

import 'package:flutter/services.dart';

import '../profile/health_identity_manager.dart';
import 'lifex_phone_permission.dart';
import 'phone_capability_mapper.dart';
import 'trusted_person_models.dart';

class SourceSelectionResult {
  const SourceSelectionResult({
    required this.ok,
    required this.messageAr,
    this.candidate,
    this.capabilityState,
  });

  final bool ok;
  final String messageAr;
  final PersonSelectionCandidate? candidate;
  final PlatformCapabilityState? capabilityState;

  factory SourceSelectionResult.unavailable(String messageAr,
          {PlatformCapabilityState? state}) =>
      SourceSelectionResult(
        ok: false,
        messageAr: messageAr,
        capabilityState: state ?? PlatformCapabilityState.unavailable,
      );

  factory SourceSelectionResult.selected(PersonSelectionCandidate candidate) =>
      SourceSelectionResult(
        ok: true,
        messageAr: 'تم اختيار الحد الأدنى من البيانات.',
        candidate: candidate,
        capabilityState: PlatformCapabilityState.systemPicker,
      );
}

/// منتقي جهات اتصال النظام — بدون نسخ الدفتر.
class PhoneContactPickerSource {
  PhoneContactPickerSource({
    MethodChannel? channel,
    PhoneCapabilityMapper mapper = const PhoneCapabilityMapper(),
  })  : _channel = channel ?? const MethodChannel('lifex_ai/contact_picker'),
        _mapper = mapper;

  final MethodChannel _channel;
  final PhoneCapabilityMapper _mapper;

  Future<SourceSelectionResult> pickOne() async {
    final assessment =
        _mapper.assess(LifexPhonePermission.phoneContactsSelect);
    if (!assessment.state.canSelectViaSystemPicker &&
        assessment.state != PlatformCapabilityState.systemPicker) {
      return SourceSelectionResult.unavailable(
        assessment.reasonAr,
        state: assessment.state,
      );
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>('pickContact');
      if (raw == null) {
        return const SourceSelectionResult(
          ok: false,
          messageAr: 'أُلغي الاختيار.',
          capabilityState: PlatformCapabilityState.requiresUserAction,
        );
      }
      if (raw is! Map) {
        return SourceSelectionResult.unavailable(
          'استجابة منتقي جهات الاتصال غير صالحة.',
          state: PlatformCapabilityState.unavailable,
        );
      }
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final name = (map['displayName'] ?? '').toString().trim();
      final phone = (map['phoneNumber'] ?? '').toString().trim();
      final email = (map['email'] ?? '').toString().trim();
      final lookup = (map['lookupKey'] ?? map['contactId'] ?? '')
          .toString()
          .trim();

      if (name.isEmpty && phone.isEmpty) {
        return SourceSelectionResult.unavailable(
          'الجهة المختارة بلا اسم أو رقم قابل للحفظ.',
          state: PlatformCapabilityState.limited,
        );
      }

      return SourceSelectionResult.selected(
        PersonSelectionCandidate(
          sourceType: TrustedPersonSourceType.phoneContact,
          displayName: name.isEmpty ? phone : name,
          phoneNumber: phone.isEmpty ? null : phone,
          email: email.isEmpty ? null : email,
          sourceReference: lookup.isEmpty ? null : lookup,
        ),
      );
    } on MissingPluginException {
      return SourceSelectionResult.unavailable(
        'منتقي جهات الاتصال غير مربوط على هذه المنصة. استخدم دليلاً أو إدخالاً يدوياً.',
        state: PlatformCapabilityState.unavailable,
      );
    } on PlatformException catch (e) {
      return SourceSelectionResult.unavailable(
        e.message ?? 'تعذّر فتح منتقي جهات الاتصال.',
        state: PlatformCapabilityState.denied,
      );
    }
  }
}

/// سجل المكالمات — صادق حول قيود Play.
class CallLogSelectionSource {
  const CallLogSelectionSource({
    this.mapper = const PhoneCapabilityMapper(),
  });

  final PhoneCapabilityMapper mapper;

  Future<SourceSelectionResult> pickOne({
    PersonSelectionCandidate? injectedForTest,
  }) async {
    final assessment = mapper.assess(LifexPhonePermission.phoneCallLogSelect);
    if (injectedForTest != null &&
        (assessment.state == PlatformCapabilityState.granted ||
            assessment.state == PlatformCapabilityState.limited)) {
      return SourceSelectionResult.selected(injectedForTest);
    }
    return SourceSelectionResult.unavailable(
      assessment.reasonAr,
      state: assessment.state,
    );
  }
}

/// SMS — صادق؛ لا READ_SMS شكلي.
class SmsSelectionSource {
  const SmsSelectionSource({
    this.mapper = const PhoneCapabilityMapper(),
  });

  final PhoneCapabilityMapper mapper;

  Future<SourceSelectionResult> pickOne({
    PersonSelectionCandidate? injectedForTest,
  }) async {
    final assessment = mapper.assess(LifexPhonePermission.phoneSmsSelect);
    if (injectedForTest != null &&
        (assessment.state == PlatformCapabilityState.granted ||
            assessment.state == PlatformCapabilityState.limited)) {
      return SourceSelectionResult.selected(injectedForTest);
    }
    return SourceSelectionResult.unavailable(
      assessment.reasonAr,
      state: assessment.state,
    );
  }
}

/// دليل Lifex المحلي — بحث هوية بلا منح وصول صحي.
class LifexDirectorySource {
  LifexDirectorySource({HealthIdentityManager? identityManager})
      : _identities = identityManager ?? HealthIdentityManager.instance;

  final HealthIdentityManager _identities;

  List<PersonSelectionCandidate> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final out = <PersonSelectionCandidate>[];
    for (final identity in _identities.allIdentities) {
      final id = identity.lifexId.toLowerCase();
      final phone = (identity.phoneNumber ?? '').toLowerCase();
      final email = (identity.email ?? '').toLowerCase();
      if (id.contains(q) || phone.contains(q) || email.contains(q)) {
        out.add(
          PersonSelectionCandidate(
            sourceType: TrustedPersonSourceType.lifexDirectory,
            displayName: identity.lifexId,
            phoneNumber: identity.phoneNumber,
            email: identity.email,
            identityId: identity.lifexId,
            personId: identity.linkedProfileId,
            sourceReference: identity.lifexId,
          ),
        );
      }
    }
    return out;
  }
}

/// إدخال يدوي — الملاذ الأخير وليس المصدر الأساسي.
class ManualEntrySource {
  const ManualEntrySource();

  SourceSelectionResult build({
    required String displayName,
    String? phoneNumber,
    String? email,
  }) {
    final name = displayName.trim();
    final phone = phoneNumber?.trim() ?? '';
    final mail = email?.trim() ?? '';
    if (name.isEmpty || (phone.isEmpty && mail.isEmpty)) {
      return const SourceSelectionResult(
        ok: false,
        messageAr: 'الإدخال اليدوي يتطلب اسماً ورقم هاتف أو بريداً.',
        capabilityState: PlatformCapabilityState.requiresUserAction,
      );
    }
    return SourceSelectionResult.selected(
      PersonSelectionCandidate(
        sourceType: TrustedPersonSourceType.manual,
        displayName: name,
        phoneNumber: phone.isEmpty ? null : phone,
        email: mail.isEmpty ? null : mail,
        sourceReference: 'manual',
      ),
    );
  }
}
