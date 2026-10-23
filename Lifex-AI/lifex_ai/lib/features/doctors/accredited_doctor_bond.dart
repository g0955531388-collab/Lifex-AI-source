/// =============================================================
/// Lifex-AI — الأطباء
/// الملف: accredited_doctor_bond.dart
/// المريض يختار طبيبه المعتمد فيصل الإشعار والسي في إن كان ملف الطبيب هنا.
/// =============================================================
library lifex_ai.features.doctors.accredited_doctor_bond;

import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';

class AccreditedBondResult {
  const AccreditedBondResult({
    required this.deliveredToDoctor,
    required this.messageAr,
  });

  final bool deliveredToDoctor;
  final String messageAr;
}

class AccreditedDoctorBond {
  const AccreditedDoctorBond();

  AccreditedBondResult accredit({
    required HealthProfile patient,
    required HealthProfile? doctor,
    required String doctorName,
    required String cvPlainText,
    bool shareFullRecord = true,
  }) {
    ProfileBoxStore(patient).add(BoxKeys.doctorMyDoctors, {
      'title': doctorName,
      'detail': shareFullRecord
          ? 'طبيبي المعتمد — وافقت على إرسال اسمي الحقيقي والسي في'
          : 'طبيبي المعتمد — وافقت على إرسال الحد الأدنى فقط',
      'doctorProfileId': doctor?.profileId ?? '',
      'cvSent': doctor != null && shareFullRecord,
      'shareFullRecord': shareFullRecord,
    });
    if (doctor == null) {
      return const AccreditedBondResult(
        deliveredToDoctor: false,
        messageAr:
            'أُضيف طبيبك المعتمد في ملفك. الإشعار والسي في يصلان عندما يكون ملف الطبيب على هذا الجهاز.',
      );
    }
    final store = ProfileBoxStore(doctor);
    store.add(BoxKeys.doctorNotices, {
      'title': 'مريض معتمد جديد',
      'detail':
          'أصبح لديك المريض ${patient.fullName} باسمه الحقيقي ومعلوماته الحقيقية، لأنه اختار طبيبه المعتمد.',
    });
    store.add(BoxKeys.accreditedPatientInbox, {
      'title': patient.fullName,
      'patientId': patient.profileId,
      'nationalId': shareFullRecord
          ? (ProfileBoxStore(patient).stringField(BoxKeys.ownerNationalId) ??
              '')
          : '',
      'cv': cvPlainText,
      'detail': shareFullRecord
          ? patient.chronicConditions
              .map((item) => item.conditionName)
              .join('، ')
          : '',
      'shareFullRecord': shareFullRecord,
    });
    return AccreditedBondResult(
      deliveredToDoctor: true,
      messageAr: shareFullRecord
          ? 'وصل إشعار إلى ملف الطبيب على هذا الجهاز، ومعه السي في الكامل لأنك اخترت ذلك.'
          : 'وصل إشعار إلى ملف الطبيب على هذا الجهاز، ومعه الحد الأدنى الذي وافقت على إرساله.',
    );
  }
}
