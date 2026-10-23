/// =============================================================
/// Lifex-AI — صندوق المشروع
/// الملف: profile_box_store.dart
/// يخزّن سجلات الوحدات داخل الملف الصحي الحي دون خادم.
/// =============================================================
library lifex_ai.features.network_box.profile_box_store;

import '../profile/health_profile.dart';

class BoxKeys {
  BoxKeys._();

  static const aliasName = 'aliasName';
  static const lifeOriginNotes = 'lifeOriginNotes';
  static const publicIdentityMode = 'publicIdentityMode';
  static const doctors = 'doctorNetworkRecords';
  static const patients = 'patientNetworkRecords';
  static const labs = 'labRecords';
  static const radiology = 'radiologyRecords';
  static const pharmacy = 'pharmacyRecords';
  static const hospital = 'hospitalRecords';
  static const dental = 'dentalRecords';
  static const dentalSessions = 'dentalSessionRecords';
  static const meetingRooms = 'localMeetingRooms';
  static const women = 'womenHealthRecords';
  static const donations = 'donationRecords';
  static const education = 'careTrainingRecords';
  static const connectedDevices = 'connectedDeviceRecords';
  static const medicalDevices = 'medicalDeviceRegistry';
  static const biometrics = 'biometricManualLogs';
  static const chronicPlans = 'chronicCarePlans';
  static const bookings = 'unifiedBookings';
  static const guardian = 'deviceGuardianState';
  static const remoteLinks = 'remoteGuardianLinks';
  static const familyMessages = 'familyMessages';
  static const pharmacyStock = 'pharmacyStock';
  static const pharmacyLedger = 'pharmacyMovementRecords';
  static const pharmacyRequests = 'pharmacyServiceRequests';
  static const pharmacyAccredited = 'pharmacyAccreditedLinks';
  static const pharmacyNotices = 'pharmacyNoticeRecords';
  static const careNotices = 'careCycleNotices';
  static const unitHolds = 'careUnitHolds';
  static const cameraNotes = 'cameraNotes';
  static const careOrders = 'careOrders';
  static const accountEmail = 'accountEmail';
  static const accountPhone = 'accountPhone';
  static const ownerNationalId = 'ownerNationalId';
  static const nationality = 'nationality';
  static const residencePlace = 'residencePlace';
  static const surgeries = 'surgeryHistoryRecords';
  static const vaccinations = 'vaccinationRecords';
  static const lifestyle = 'lifestyleRecords';
  static const medicalHistory = 'pastIllnessRecords';
  static const womenMembership = 'womenMembership';
  static const doctorInterested = 'doctorInterestedFollows';
  static const doctorMyDoctors = 'doctorMedicalLinks';
  static const labSamples = 'labSampleRecords';
  static const hospitalDepartments = 'hospitalDepartmentRecords';
  static const hospitalAdmissions = 'hospitalAdmissionRecords';
  static const hospitalDischarge = 'hospitalDischargeRecords';
  static const imagingModalities = 'imagingModalityRecords';
  static const donationKinds = 'donationKindRecords';
  static const educationPlan = 'educationPersonalPlan';
  static const familyHistory = 'familyHistoryRecords';
  static const profileThumbnailPath = 'profileThumbnailPath';
  static const layeredSlices = 'layeredSliceRecords';
  static const doctorDiaryDays = 'doctorDiaryDays';
  static const empowermentPact = 'empowermentPact';
  static const familyChildCharter = 'familyChildCharter';
  static const youthPact = 'youthPact';
  static const royalIntelligenceLast = 'royalIntelligenceLast';
  static const personalShelf = 'personalShelf';
  static const disabilityRecords = 'disabilitySelfRecords';
  static const marriageRequests = 'marriageHealthRequests';
  static const healthThreads = 'healthChannelThreads';
  static const messengerGroups = 'messengerGroups';
  static const messengerGroupPosts = 'messengerGroupPosts';
  static const messengerCalls = 'messengerCallRequests';
  static const messengerAnnouncements = 'messengerAnnouncements';
  static const messengerBloodNotes = 'messengerBloodNotes';
  static const cvVault = 'ownerCvVault';
  static const accreditedPatientInbox = 'accreditedPatientInbox';
  static const doctorNotices = 'doctorUnitNotices';
  static const medicationAlarms = 'medicationAlarms';
  static const choiceMirrorJournal = 'choiceMirrorJournal';
  static const unitOwnPlace = 'unitOwnPlace';
  static const unitExchange = 'unitExchangePackets';
}

/// قراءة وكتابة قوائم الصندوق داخل [HealthProfile.questionnaireData].
class ProfileBoxStore {
  ProfileBoxStore(this.profile);

  final HealthProfile profile;

  List<Map<String, dynamic>> list(String key) {
    final raw = profile.questionnaireData[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void setList(String key, List<Map<String, dynamic>> items) {
    profile.questionnaireData[key] = items;
    profile.lastUpdatedAt = DateTime.now();
  }

  Map<String, dynamic> add(String key, Map<String, dynamic> record) {
    final items = list(key);
    final stored = Map<String, dynamic>.from(record);
    stored['id'] ??= 'REC-${DateTime.now().millisecondsSinceEpoch}';
    stored['createdAt'] ??= DateTime.now().toIso8601String();
    items.add(stored);
    setList(key, items);
    return stored;
  }

  void removeAt(String key, int index) {
    final items = list(key);
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    setList(key, items);
  }

  String? stringField(String key) {
    final value = profile.questionnaireData[key];
    return value is String ? value : null;
  }

  void setString(String key, String value) {
    profile.questionnaireData[key] = value;
    profile.lastUpdatedAt = DateTime.now();
  }

  Map<String, dynamic> map(String key) {
    final raw = profile.questionnaireData[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  void setMap(String key, Map<String, dynamic> value) {
    profile.questionnaireData[key] = value;
    profile.lastUpdatedAt = DateTime.now();
  }
}
