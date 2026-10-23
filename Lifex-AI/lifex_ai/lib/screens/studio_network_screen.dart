/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: studio_network_screen.dart
/// بوابات مستودع الاستوديو تفتح المقاعد القائمة في هذا التطبيق.
/// =============================================================
library lifex_ai.screens.studio_network_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../features/network_box/studio_portal_catalog.dart';
import '../widgets/studio_web_frame.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/health_profile.dart';
import 'admin_dashboard_screen.dart';
import 'box_unit_screen.dart';
import 'care_order_screen.dart';
import 'device_center_screen.dart';
import 'doctor_directory_screen.dart';
import 'emergency_contacts_screen.dart';
import 'global_health_dashboard_screen.dart';
import 'health_profile_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'privacy_settings_screen.dart';
import 'voice_control_screen.dart';
import 'women_cycle_screen.dart';
import 'world_workspace_screen.dart';

class StudioNetworkScreen extends StatelessWidget {
  const StudioNetworkScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.systemName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StudioPortalGrid(
            onPortal: (portal) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _page(portal.id, profile)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _page(StudioPortalId id, HealthProfile? profile) {
    return pageFor(id: id, profileId: profileId, profile: profile);
  }

  static Widget pageFor({
    required StudioPortalId id,
    required String profileId,
    HealthProfile? profile,
  }) {
    switch (id) {
      case StudioPortalId.network:
        return GlobalHealthDashboardScreen(profileId: profileId);
      case StudioPortalId.patient:
        return HealthProfileScreen(profile: profile, preferThisProfile: true);
      case StudioPortalId.doctor:
        return const DoctorDirectoryScreen();
      case StudioPortalId.hospital:
        return const BoxUnitScreen(unit: BoxUnitCatalog.hospital);
      case StudioPortalId.lab:
        return CareOrderScreen.lab();
      case StudioPortalId.pharmacy:
        return const PharmacyStockScreen();
      case StudioPortalId.privacy:
        return const PrivacySettingsScreen();
      case StudioPortalId.admin:
        final lifexId = HealthIdentityManager.instance
            .getByProfileId(profileId)
            ?.lifexId;
        return AdminDashboardScreen(currentUserLifexId: lifexId ?? '');
      case StudioPortalId.emergency:
        return const EmergencyContactsScreen();
      case StudioPortalId.womenHealth:
        return const WomenCycleScreen();
      case StudioPortalId.devices:
        return const DeviceCenterScreen();
      case StudioPortalId.ai:
        return const VoiceControlScreen();
      case StudioPortalId.organizations:
        return const WorldWorkspaceScreen();
    }
  }
}
