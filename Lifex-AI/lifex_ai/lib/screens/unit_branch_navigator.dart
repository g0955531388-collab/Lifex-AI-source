/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: unit_branch_navigator.dart
/// فتح فرع سيناريو: سجل محلي أو شاشة قائمة مسبقاً.
/// =============================================================
library lifex_ai.screens.unit_branch_navigator;

import 'package:flutter/material.dart';

import '../features/network_box/unit_branch_catalog.dart';
import 'accessibility_assistant_screen.dart';
import 'appointments_screen.dart';
import 'blood_request_screen.dart';
import 'booking_workspace_screen.dart';
import 'camera_notes_screen.dart';
import 'care_order_screen.dart';
import 'dental_chart_screen.dart';
import 'disability_fixation_screen.dart';
import 'doctor_directory_screen.dart';
import 'doctor_diary_screen.dart';
import 'emergency_contacts_screen.dart';
import 'empowerment_lab_screen.dart';
import 'family_management_screen.dart';
import 'child_rights_book_screen.dart';
import 'choice_mirror_screen.dart';
import 'clinical_watch_screen.dart';
import 'knowledge_arcade_screen.dart';
import 'personal_shelf_screen.dart';
import 'royal_intelligence_screen.dart';
import 'youth_guide_screen.dart';
import 'identity_workspace_screen.dart';
import 'layered_lens_studio_screen.dart';
import 'live_sight_screen.dart';
import 'manual_vitals_screen.dart';
import 'medication_alarm_screen.dart';
import 'medical_reference_screen.dart';
import 'medications_screen.dart';
import 'optical_radar_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'privacy_settings_screen.dart';
import 'protection_workspace_screen.dart';
import 'smart_health_questionnaire_screen.dart';
import 'stamped_reports_screen.dart';
import 'thumbnail_manage_screen.dart';
import 'unit_branch_records_screen.dart';
import 'wallet_screen.dart';
import 'women_cycle_screen.dart';
import 'world_workspace_screen.dart';

class UnitBranchNavigator {
  const UnitBranchNavigator._();

  static void open(
    BuildContext context,
    UnitBranch branch, {
    String? profileId,
  }) {
    final page = _page(branch, profileId);
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static Widget? _page(UnitBranch branch, String? profileId) {
    switch (branch.shortcut) {
      case UnitShortcut.records:
        return UnitBranchRecordsScreen(branch: branch);
      case UnitShortcut.doctorDirectory:
        return const DoctorDirectoryScreen();
      case UnitShortcut.pharmacyStock:
        return const PharmacyStockScreen();
      case UnitShortcut.dentalChart:
        return const DentalChartScreen();
      case UnitShortcut.womenCycle:
        return const WomenCycleScreen();
      case UnitShortcut.labOrders:
        return CareOrderScreen.lab();
      case UnitShortcut.imagingOrders:
        return CareOrderScreen.imaging();
      case UnitShortcut.cameraNotes:
        return const CameraNotesScreen();
      case UnitShortcut.liveSight:
        if (profileId == null) return null;
        return LiveSightScreen(profileId: profileId);
      case UnitShortcut.layeredLens:
        return const LayeredLensStudioScreen();
      case UnitShortcut.thumbnail:
        return const ThumbnailManageScreen();
      case UnitShortcut.doctorDiary:
        return const DoctorDiaryScreen();
      case UnitShortcut.empowermentLab:
        return const EmpowermentLabScreen();
      case UnitShortcut.childRightsBook:
        return const ChildRightsBookScreen();
      case UnitShortcut.choiceMirror:
        return const ChoiceMirrorScreen();
      case UnitShortcut.youthGuide:
        return const YouthGuideScreen();
      case UnitShortcut.royalIntelligence:
        return const RoyalIntelligenceScreen();
      case UnitShortcut.knowledgeArcade:
        return const KnowledgeArcadeScreen();
      case UnitShortcut.personalShelf:
        return const PersonalShelfScreen();
      case UnitShortcut.clinicalWatch:
        return const ClinicalWatchScreen();
      case UnitShortcut.manualVitals:
        return const ManualVitalsScreen();
      case UnitShortcut.medicationAlarms:
        return const MedicationAlarmScreen();
      case UnitShortcut.disabilityFixation:
        return const DisabilityFixationScreen();
      case UnitShortcut.bookings:
        return const BookingWorkspaceScreen();
      case UnitShortcut.bloodNetwork:
        return const BloodRequestScreen();
      case UnitShortcut.medications:
        if (profileId == null) return null;
        return MedicationsScreen(profileId: profileId);
      case UnitShortcut.appointments:
        return const AppointmentsScreen();
      case UnitShortcut.family:
        return const FamilyManagementScreen();
      case UnitShortcut.identity:
        return const IdentityWorkspaceScreen();
      case UnitShortcut.questionnaire:
        return const SmartHealthQuestionnaireScreen();
      case UnitShortcut.accessibility:
        if (profileId == null) return null;
        return AccessibilityAssistantScreen(profileId: profileId);
      case UnitShortcut.opticalRadar:
        return const OpticalRadarScreen();
      case UnitShortcut.wallet:
        if (profileId == null) return null;
        return WalletScreen(profileId: profileId);
      case UnitShortcut.stampedReports:
        return const StampedReportsScreen();
      case UnitShortcut.emergencyContacts:
        return const EmergencyContactsScreen();
      case UnitShortcut.medicalReferenceDrugs:
        return const MedicalReferenceScreen(kind: MedicalReferenceKind.drugs);
      case UnitShortcut.medicalReferenceConditions:
        return const MedicalReferenceScreen(
          kind: MedicalReferenceKind.conditions,
        );
      case UnitShortcut.medicalReferenceGrowth:
        return const MedicalReferenceScreen(kind: MedicalReferenceKind.growth);
      case UnitShortcut.medicalReferenceCamera:
        return const MedicalReferenceScreen(
          kind: MedicalReferenceKind.cameraSigns,
        );
      case UnitShortcut.protection:
        return const ProtectionWorkspaceScreen();
      case UnitShortcut.world:
        return const WorldWorkspaceScreen();
      case UnitShortcut.privacy:
        return const PrivacySettingsScreen();
    }
  }
}
