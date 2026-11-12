/// =============================================================
/// Lifex-AI — التراسل الصحي
/// الملف: health_channel_filter.dart
/// محادثة عامة: لا إباحي ولا نابية. الأطباء والوحدات الصحية يُستثنون
/// للمرفقات الطبية الحرجة. ليس واتساب تجارياً؛ قناة صحية على الجهاز.
/// =============================================================
library lifex_ai.features.messaging.health_channel_filter;

import 'conversation_type_router.dart';

class HealthChannelVerdict {
  const HealthChannelVerdict({
    required this.allowed,
    required this.messageAr,
    this.code = '',
  });

  final bool allowed;
  final String messageAr;
  final String code;
}

class HealthChannelFilter {
  const HealthChannelFilter();

  static const guestByteCap = 25 * 1024 * 1024;
  static const subscriberByteCap = 3 * 1024 * 1024 * 1024;

  static const _adult = [
    'porn',
    'xxx',
    'xvideos',
    'pornhub',
    'onlyfans',
    'nude',
    'nudes',
    'sex tape',
    'إباحي',
    'اباحي',
    'سكس',
    'إباحية',
  ];

  static const _profanity = [
    'fuck',
    'shit',
    'bitch',
    'كس أم',
    'كسمك',
    'عرص',
    'شرموط',
    'قحبة',
    'ابن كلب',
  ];

  static const _clinicalHints = [
    'genital',
    'cervix',
    'ultrasound',
    'mri',
    'xray',
    'أشعة',
    'تحليل',
    'مهبل',
    'رحم',
    'بروستات',
    'ثدي',
    'ولادة',
    'dicom',
  ];

  HealthChannelVerdict inspect({
    required ConversationType type,
    required String senderSeat,
    required String text,
    String fileName = '',
    int sizeBytes = 0,
    required bool subscriber,
  }) {
    final blob = '${text.toLowerCase()} ${fileName.toLowerCase()}';
    final clinical = _isClinical(type, senderSeat);
    if (_contains(_adult, blob) && !clinical) {
      return const HealthChannelVerdict(
        allowed: false,
        code: 'adult',
        messageAr:
            'المحادثة العامة لا تقبل عملاً إباحياً ولا ملفات من هذا الصنف.',
      );
    }
    if (_contains(_adult, blob) &&
        clinical &&
        !_looksMedical(blob) &&
        fileName.isNotEmpty) {
      return const HealthChannelVerdict(
        allowed: false,
        code: 'adultClinical',
        messageAr:
            'حتى العيادة: الملف الإباحي الصريح مرفوض. المرفق الطبي الحرج مسموح.',
      );
    }
    if (!clinical && _contains(_profanity, blob)) {
      return const HealthChannelVerdict(
        allowed: false,
        code: 'profanity',
        messageAr: 'الكلمات النابية محظورة في المحادثة العامة.',
      );
    }
    if (sizeBytes > 0) {
      final cap = subscriber ? subscriberByteCap : guestByteCap;
      if (sizeBytes > cap) {
        return HealthChannelVerdict(
          allowed: false,
          code: 'tooLarge',
          messageAr: subscriber
              ? 'تجاوز حد المرفق للمشترك (حتى أكثر من جيغا على هذا الجهاز، دون رفع سحابي).'
              : 'غير المشترك: حد المرفق 25 ميغا. المشتركون يرسلون قواعد أكبر محلياً.',
        );
      }
    }
    return const HealthChannelVerdict(
      allowed: true,
      code: 'sentHere',
      messageAr: 'أُرسلت على هذا الجهاز. لم تُرفع إلى شبكة خارجية.',
    );
  }

  bool _isClinical(ConversationType type, String seat) {
    if (type == ConversationType.medical) return true;
    return seat == 'healthUnit' || seat == 'hospital';
  }

  bool _looksMedical(String blob) => _contains(_clinicalHints, blob);

  bool _contains(List<String> tokens, String blob) {
    for (final token in tokens) {
      if (blob.contains(token)) return true;
    }
    return false;
  }
}
