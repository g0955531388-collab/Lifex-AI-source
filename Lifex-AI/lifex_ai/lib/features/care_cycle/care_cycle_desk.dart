/// =============================================================
/// Lifex-AI — الدورة التشغيلية
/// من الشكوى إلى الاقتراح والحجز والطلب المالي.
/// الاحتمال ليس تشخيصاً. الدفع لا ينجح بلا مزود مرخّص.
/// =============================================================
library lifex_ai.features.care_cycle.care_cycle_desk;

import '../doctors/accredited_doctor_bond.dart';
import '../doctors/doctor_directory.dart';
import '../doctors/doctor_remote_slot.dart';
import '../emergency/risk_level_engine.dart';
import '../finance/billing_exemption_policy.dart';
import '../location/nearby_care_finder.dart';
import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';
import '../providers/pharmacy_stock_ledger.dart';
import '../../core/app_constants.dart';

class CareReport {
  const CareReport({
    required this.summaryAr,
    required this.specialtyAr,
    required this.urgent,
    required this.hypothesesAr,
  });

  final String summaryAr;
  final String specialtyAr;
  final bool urgent;
  final List<String> hypothesesAr;
}

class ServiceQuote {
  const ServiceQuote({
    required this.grossMinor,
    required this.commissionMinor,
    required this.providerMinor,
    required this.exempt,
    required this.status,
    required this.messageAr,
  });

  final int grossMinor;
  final int commissionMinor;
  final int providerMinor;
  final bool exempt;
  final String status;
  final String messageAr;
}

class CareCycleDesk {
  const CareCycleDesk();

  static const commissionPermille = 50;

  CareReport report({
    required String complaint,
    required String duration,
    required String severity,
    required HealthProfile patient,
  }) {
    final text = complaint.trim();
    final chronic = patient.chronicConditions
        .map((item) => item.conditionName)
        .where((item) => item.trim().isNotEmpty)
        .join('، ');
    final allergy = patient.allergies
        .map((item) => item.substance)
        .where((item) => item.trim().isNotEmpty)
        .join('، ');
    final trigger = _urgentTrigger(text);
    final risk = RiskLevelEngine().assess({
      'triggerType': trigger,
      'hasChronicCondition': patient.chronicConditions.isNotEmpty,
    });
    final urgent = risk.level == AppConstants.riskLevelCritical;
    final specialty = _specialty(text, urgent);
    final hypotheses = <String>[
      if (text.isNotEmpty) 'الشكوى المسجّلة: $text.',
      if (duration.trim().isNotEmpty) 'المدة كما ذكرها المريض: ${duration.trim()}.',
      if (severity.trim().isNotEmpty) 'الشدة كما ذكرها المريض: ${severity.trim()}.',
      if (chronic.isNotEmpty) 'من السيرة في الملف: $chronic.',
      if (allergy.isNotEmpty) 'حساسيات مسجّلة في الملف: $allergy.',
      'هذه احتمالات تستحق تقييماً سريرياً، وليست تشخيصاً نهائياً.',
      'الاختصاص المناسب للمراجعة: $specialty.',
    ];
    final summary = urgent
        ? '${risk.reasonAr} التوجه إلى الطوارئ يسبق حجز موعد عادي.'
        : 'تقرير أولي للمراجعة. ${risk.reasonAr}';
    return CareReport(
      summaryAr: summary,
      specialtyAr: specialty,
      urgent: urgent,
      hypothesesAr: hypotheses,
    );
  }

  NearbyCareReport suggest({
    required double? latitude,
    required double? longitude,
    required String specialty,
    required List<CareBox> boxes,
  }) {
    return const NearbyCareFinder().suggest(
      hereLat: latitude,
      hereLon: longitude,
      specialty: specialty,
      boxes: boxes,
    );
  }

  AccreditedBondResult accredit({
    required HealthProfile patient,
    required HealthProfile? doctor,
    required String doctorName,
    required String complaint,
    required bool shareFullRecord,
    String fullRecordText = '',
  }) {
    final minimum =
        'الحد الأدنى للرعاية: اختار المريض ${patient.fullName} الطبيب $doctorName. الشكوى: ${complaint.trim()}.';
    final result = const AccreditedDoctorBond().accredit(
      patient: patient,
      doctor: doctor,
      doctorName: doctorName,
      cvPlainText: shareFullRecord ? fullRecordText : minimum,
      shareFullRecord: shareFullRecord,
    );
    ProfileBoxStore(patient).add(BoxKeys.careNotices, {
      'title': 'طبيبي المعتمد',
      'detail': shareFullRecord
          ? 'اعتمدت $doctorName مع مشاركة النص الذي وافقت على إرساله.'
          : 'اعتمدت $doctorName. لم تُرسل السيرة الكاملة.',
    });
    return result;
  }

  String? holdDoctorSlot({
    required HealthProfile doctor,
    required HealthProfile patient,
    required DateTime day,
    required String time,
    required int workHours,
    required int examMinutes,
    required int startHour,
  }) {
    final blocked = const DoctorRemoteSlot().book(
      doctor: doctor,
      patient: patient,
      day: day,
      time: time,
      workHours: workHours,
      examMinutes: examMinutes,
      startHour: startHour,
    );
    if (blocked != null) return blocked;
    final line =
        'حُجزت الحصة $time على جهاز الطبيب. لوحة الحجز الخارجية غير مربوطة، فلم يُعلَن الموعد مؤكداً خارج هذا الجهاز.';
    ProfileBoxStore(patient).add(BoxKeys.careNotices, {
      'title': 'موعد محلي',
      'detail': line,
    });
    ProfileBoxStore(doctor).add(BoxKeys.doctorNotices, {
      'title': 'حجز حصة',
      'detail': '${patient.fullName} — $time. $line',
    });
    return null;
  }

  String? holdUnitSlot({
    required HealthProfile provider,
    required HealthProfile patient,
    required String unitKind,
    required DateTime at,
  }) {
    final stamp = at.toIso8601String();
    final store = ProfileBoxStore(provider);
    final taken = store.list(BoxKeys.unitHolds).any(
          (row) =>
              row['unitKind'] == unitKind &&
              row['at'] == stamp &&
              row['status'] != 'cancelled',
        );
    if (taken) return 'هذا الوقت محجوز على الجهاز لنفس الوحدة.';
    final line =
        'حُفظ طلب $unitKind عند $stamp. لوحة الحجز الخارجية غير مربوطة، فالموعد غير مؤكد خارج هذا الجهاز.';
    store.add(BoxKeys.unitHolds, {
      'title': unitKind,
      'unitKind': unitKind,
      'at': stamp,
      'status': 'heldLocal',
      'patientId': patient.profileId,
      'detail': line,
    });
    ProfileBoxStore(patient).add(BoxKeys.careNotices, {
      'title': 'طلب $unitKind',
      'detail': line,
    });
    return null;
  }

  String accreditPharmacy({
    required HealthProfile patient,
    required HealthProfile? pharmacy,
    required String pharmacyName,
  }) {
    ProfileBoxStore(patient).add(BoxKeys.pharmacyAccredited, {
      'title': pharmacyName,
      'pharmacyProfileId': pharmacy?.profileId ?? '',
      'detail': 'صيدليتي المعتمدة. لم تُرسل السيرة الصحية الكاملة.',
    });
    final line = pharmacy == null
        ? 'أُضيفت $pharmacyName في ملفك. الإشعار يصل عندما يكون ملف الصيدلية على هذا الجهاز.'
        : 'اختار ${patient.fullName} الصيدلية $pharmacyName. وصل اسمه فقط، بلا سيرة كاملة.';
    if (pharmacy != null) {
      ProfileBoxStore(pharmacy).add(BoxKeys.pharmacyNotices, {
        'title': 'مريض اعتمد الصيدلية',
        'patientId': patient.profileId,
        'detail': line,
      });
    }
    ProfileBoxStore(patient).add(BoxKeys.careNotices, {
      'title': 'صيدليتي المعتمدة',
      'detail': line,
    });
    return line;
  }

  ServiceQuote quote({
    required HealthProfile payer,
    required int grossMinor,
  }) {
    if (grossMinor <= 0) {
      return const ServiceQuote(
        grossMinor: 0,
        commissionMinor: 0,
        providerMinor: 0,
        exempt: false,
        status: 'empty',
        messageAr: 'لا عرض دفع. المبلغ بأصغر وحدة عملة ويجب أن يكون أكبر من صفر.',
      );
    }
    final exempt = const BillingExemptionPolicy().evaluate(payer).isExempt;
    final commission = exempt ? 0 : (grossMinor * commissionPermille) ~/ 1000;
    final provider = grossMinor - commission;
    return ServiceQuote(
      grossMinor: grossMinor,
      commissionMinor: commission,
      providerMinor: provider,
      exempt: exempt,
      status: 'pending',
      messageAr:
          'قبل التأكيد: الإجمالي $grossMinor، عمولة المنصة $commission (5٪ ما لم يُعفَ)، '
          'وللمقدم $provider. المزود المرخّص غير مربوط، فالحالة قيد الانتظار وليست ناجحة. '
          'لا تُخزَّن بيانات البطاقة.',
    );
  }

  ServiceQuote requestRefund(ServiceQuote quote) {
    if (quote.status != 'pending') {
      return ServiceQuote(
        grossMinor: quote.grossMinor,
        commissionMinor: quote.commissionMinor,
        providerMinor: quote.providerMinor,
        exempt: quote.exempt,
        status: quote.status,
        messageAr: 'لا استرداد. لا توجد عملية ناجحة عند مزود مرخّص.',
      );
    }
    return ServiceQuote(
      grossMinor: quote.grossMinor,
      commissionMinor: quote.commissionMinor,
      providerMinor: quote.providerMinor,
      exempt: quote.exempt,
      status: 'refundRequested',
        messageAr:
          'طُلب الاسترداد على هذا الجهاز. المزود المرخّص غير مربوط، فلم يُرجَع مبلغ ولم تُعلَم العملية ناجحة.',
    );
  }

  String recordPrescription({
    required HealthProfile doctor,
    required HealthProfile patient,
    required String substance,
    required String dose,
    required String form,
    required String duration,
    required String instructions,
  }) {
    if (substance.trim().isEmpty || dose.trim().isEmpty) {
      return 'الوصفة لم تُحفظ. اسم المادة والجرعة يكتبهما الطبيب، ولا يستنتجهما النظام.';
    }
    final line =
        'وصفة كتبها ${doctor.fullName} لـ ${patient.fullName}: ${substance.trim()}، ${dose.trim()}، ${form.trim()}، ${duration.trim()}. ${instructions.trim()} لم يُغيّر النظام الجرعة ولا استبدل المادة.';
    ProfileBoxStore(doctor).add(BoxKeys.doctorNotices, {
      'title': 'وصفة',
      'patientId': patient.profileId,
      'detail': line,
    });
    ProfileBoxStore(patient).add(BoxKeys.careNotices, {
      'title': 'وصفة',
      'detail': line,
    });
    return line;
  }

  String requestCodedStock({
    required HealthProfile patient,
    required HealthProfile? pharmacy,
    required String code,
    required int units,
  }) {
    if (pharmacy == null || code.trim().isEmpty || units <= 0) {
      return 'الطلب لم يُرسل. اختر صيدلية على هذا الجهاز، ورمزاً، وكمية أكبر من صفر.';
    }
    final stock = ProfileBoxStore(pharmacy).list(BoxKeys.pharmacyStock);
    final row = stock.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['barcode']?.toString().trim() == code.trim(),
          orElse: () => null,
        );
    final onHand = row == null ? 0 : PharmacyStockLedger.readQuantity(row);
    if (row == null || onHand < units) {
      return 'الصيدلية على هذا الجهاز لا تسجّل كمية كافية للرمز ${code.trim()}. لا يُعلَن التوفر مؤكداً.';
    }
    ProfileBoxStore(pharmacy).add(BoxKeys.pharmacyRequests, {
      'title': row['title']?.toString() ?? code.trim(),
      'barcode': code.trim(),
      'units': units,
      'patientId': patient.profileId,
      'status': 'pendingReview',
      'detail': 'طلب قيد المراجعة. الكمية لم تُنقص قبل قبول الصيدلي.',
    });
    final line =
        'أُرسل طلب الرمز ${code.trim()} بكمية $units. الحالة: قيد المراجعة. الكمية في الدفتر $onHand ولم تُحجز بعد.';
    ProfileBoxStore(patient).add(BoxKeys.careNotices, {
      'title': 'طلب صيدلية',
      'detail': line,
    });
    return line;
  }

  String acceptCodedStock({
    required HealthProfile pharmacy,
    required String code,
    required int units,
  }) {
    final store = ProfileBoxStore(pharmacy);
    final requests = store.list(BoxKeys.pharmacyRequests);
    final index = requests.indexWhere(
      (row) =>
          row['barcode']?.toString().trim() == code.trim() &&
          row['status'] == 'pendingReview' &&
          (row['units'] is int
              ? row['units'] as int
              : int.tryParse('${row['units']}') ?? 0) ==
              units,
    );
    if (index < 0) {
      return 'لا طلب قيد المراجعة بهذا الرمز والكمية. لم يُنقص المخزون.';
    }
    final stock = store.list(BoxKeys.pharmacyStock);
    final title = requests[index]['title']?.toString() ?? '';
    final census = const PharmacyStockLedger().apply(
      stock: stock,
      code: code,
      name: title,
      materialKind: '',
      flow: PharmacyFlow.sale,
      units: units,
    );
    if (!census.recorded) return census.messageAr;
    store.setList(BoxKeys.pharmacyStock, stock);
    requests[index]['status'] = 'confirmed';
    requests[index]['detail'] = census.messageAr;
    store.setList(BoxKeys.pharmacyRequests, requests);
    store.add(BoxKeys.pharmacyLedger, {
      'title': census.name,
      'barcode': census.code,
      'flow': 'sale',
      'units': units,
      'before': census.quantityBefore,
      'after': census.quantityAfter,
      'detail': census.messageAr,
    });
    store.add(BoxKeys.pharmacyNotices, {
      'title': 'حُجزت الكمية',
      'detail': census.messageAr,
    });
    return census.messageAr;
  }

  String? _urgentTrigger(String text) {
    if (text.contains('إغماء') || text.contains('فقدان الوعي')) {
      return 'loss_of_consciousness';
    }
    if (text.contains('نزيف')) return 'severe_bleeding';
    if (text.contains('ضيق نفس')) return 'respiratory_distress';
    if (text.contains('ألم صدر') || text.contains('خفقان')) {
      return 'cardiac_symptom';
    }
    return null;
  }

  String _specialty(String text, bool urgent) {
    if (urgent && DoctorDirectory.specialtiesAr.contains('طوارئ')) {
      return 'طوارئ';
    }
    for (final specialty in DoctorDirectory.specialtiesAr) {
      if (text.contains(specialty)) return specialty;
    }
    const hints = <String, String>{
      'ألم صدر': 'قلب',
      'خفقان': 'قلب',
      'طفل': 'أطفال',
      'حمل': 'نساء وتوليد',
      'جلد': 'جلدية',
      'حكة': 'جلدية',
      'أسنان': 'أسنان',
      'عين': 'عيون',
      'عظم': 'عظام',
    };
    for (final entry in hints.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return DoctorDirectory.specialtiesAr.first;
  }
}
