/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: home_screen.dart
/// المسار: lib/screens/home_screen.dart
/// الوصف: الشاشة الرئيسية — لوحة انطلاق نحو أهم وحدات التطبيق. تستخدم
/// AccessibleActionButton لكل عنصر تفاعلي لضمان توافق كامل مع قارئ
/// الشاشة (TalkBack/VoiceOver)، وليس فقط الشكل البصري.
/// =============================================================
library lifex_ai.screens.home_screen;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
import '../core/trial_manager.dart';
import '../features/emergency/emergency_manager.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../features/emergency/emergency_phone_contacts_registry.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/location/gps_priority_monitor.dart';
import '../features/network_box/studio_portal_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/health_profile.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/encyclopedia_share_bar.dart';
import '../widgets/studio_menu_bar.dart';
import '../widgets/studio_web_frame.dart';
import 'accessibility_assistant_screen.dart';
import 'ai_agent_screen.dart';
import 'ai_hub_screen.dart';
import 'appointments_screen.dart';
import 'blood_request_screen.dart';
import 'box_unit_screen.dart';
import 'camera_notes_screen.dart';
import 'doctor_directory_screen.dart';
import 'emergency_contacts_screen.dart';
import 'global_health_dashboard_screen.dart';
import 'health_chat_screen.dart';
import 'health_modules_screen.dart';
import 'health_profile_screen.dart';
import 'medications_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'project_box_hub_screen.dart';
import 'settings_screen.dart';
import 'smart_health_questionnaire_screen.dart';
import 'system_search_screen.dart';
import 'studio_network_screen.dart';
import 'voice_control_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const servicesKey = GlobalObjectKey('lifex-studio-services');

  bool _allowed(BuildContext context, String unitId) {
    final trial = context.read<TrialManager>();
    final profile = context.read<ActiveProfileController>().activeProfile;
    final exempt = profile != null &&
        const BillingExemptionPolicy().evaluate(profile).isExempt;
    final identity = profile == null
        ? null
        : HealthIdentityManager.instance.getByProfileId(profile.profileId);
    final adminAccess = identity != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
    return const SessionAccessPolicy().canOpenUnit(
      unitId,
      phase: trial.phase(feeExempt: exempt, adminAccess: adminAccess),
      feeExempt: exempt,
      adminAccess: adminAccess,
    );
  }

  void _open(BuildContext context, String unitId, Widget page) {
    if (!_allowed(context, unitId)) {
      final trial = context.read<TrialManager>();
      final profile = context.read<ActiveProfileController>().activeProfile;
      final exempt = profile != null &&
          const BillingExemptionPolicy().evaluate(profile).isExempt;
      final identity = profile == null
          ? null
          : HealthIdentityManager.instance.getByProfileId(profile.profileId);
      final adminAccess = identity != null &&
          GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trial.statusLineAr(
              feeExempt: exempt,
              adminAccess: adminAccess,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _openPortal(
    BuildContext context,
    StudioPortal portal,
    String? profileId,
    HealthProfile? profile,
  ) {
    final openWithoutProfile = portal.id == StudioPortalId.patient ||
        portal.id == StudioPortalId.doctor ||
        portal.id == StudioPortalId.emergency ||
        portal.id == StudioPortalId.privacy;
    if (!openWithoutProfile && profileId == null) {
      const message = 'أنشئ الملف الصحي أولاً، ثم تفتح هذه البوابة.';
      announceForScreenReader(context, message);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
      );
      return;
    }
    final unitId = switch (portal.id) {
      StudioPortalId.patient => 'profile',
      StudioPortalId.doctor => 'doctors',
      StudioPortalId.pharmacy => 'pharmacy',
      StudioPortalId.devices => 'devices',
      StudioPortalId.emergency => 'emergency',
      StudioPortalId.ai => 'ai',
      StudioPortalId.privacy => 'settings',
      _ => 'box',
    };
    _open(
      context,
      unitId,
      StudioNetworkScreen.pageFor(
        id: portal.id,
        profileId: profileId ?? '',
        profile: profile,
      ),
    );
  }

  void _confirmEmergency(BuildContext context, String? activeProfileId) {
    if (!_allowed(context, 'emergency')) {
      final trial = context.read<TrialManager>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trial.statusLineAr())),
      );
      return;
    }
    _showEmergencyConfirmationDialog(context, activeProfileId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, profileController, _) {
        final activeProfileId = profileController.activeProfileId;
        final trial = context.watch<TrialManager>();
        final exempt = profileController.activeProfile != null &&
            const BillingExemptionPolicy()
                .evaluate(profileController.activeProfile!)
                .isExempt;
        final identity = activeProfileId == null
            ? null
            : HealthIdentityManager.instance.getByProfileId(activeProfileId);
        final adminAccess = identity != null &&
            GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
        final phase = trial.phase(feeExempt: exempt, adminAccess: adminAccess);
        final showGate = !adminAccess &&
            !exempt &&
            phase != TrialPhase.subscribed &&
            phase != TrialPhase.giftWorking;

        return Scaffold(
          bottomNavigationBar: const EncyclopediaShareBar(),
          body: Column(
            children: [
              StudioMenuBar(
                onHome: () {
                  final target = servicesKey.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(target);
                  }
                },
                onPortal: (portal) => _openPortal(
                  context,
                  portal,
                  activeProfileId,
                  profileController.activeProfile,
                ),
                onSearch: () => _open(
                  context,
                  'search',
                  const SystemSearchScreen(),
                ),
                onAccount: () =>
                    _open(context, 'settings', const SettingsScreen()),
                onEmergency: () => _confirmEmergency(context, activeProfileId),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    StudioWebHero(
                      onStart: () => _openPortal(
                        context,
                        StudioPortalCatalog.portals.firstWhere(
                          (portal) => portal.id == StudioPortalId.patient,
                        ),
                        activeProfileId,
                        profileController.activeProfile,
                      ),
                      onExplore: () => _openPortal(
                        context,
                        StudioPortalCatalog.portals.firstWhere(
                          (portal) => portal.id == StudioPortalId.network,
                        ),
                        activeProfileId,
                        profileController.activeProfile,
                      ),
                      onLogin: () =>
                          _open(context, 'settings', const SettingsScreen()),
                      onServices: () {
                        final target = servicesKey.currentContext;
                        if (target != null) {
                          Scrollable.ensureVisible(target);
                        }
                      },
                      onEmergency: () =>
                          _confirmEmergency(context, activeProfileId),
                    ),
                    const SizedBox(height: 16),
                    StudioPortalGrid(
                      key: servicesKey,
                      onPortal: (portal) => _openPortal(
                        context,
                        portal,
                        activeProfileId,
                        profileController.activeProfile,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StudioPublicSections(
                      onNetwork: () => _openPortal(
                        context,
                        StudioPortalCatalog.portals.firstWhere(
                          (portal) => portal.id == StudioPortalId.network,
                        ),
                        activeProfileId,
                        profileController.activeProfile,
                      ),
                      onProfile: () => _open(
                        context,
                        'profile',
                        HealthProfileScreen(
                          profile: profileController.activeProfile,
                        ),
                      ),
                      onAi: () => _openPortal(
                        context,
                        StudioPortalCatalog.portals.firstWhere(
                          (portal) => portal.id == StudioPortalId.ai,
                        ),
                        activeProfileId,
                        profileController.activeProfile,
                      ),
                      onDevices: () => _openPortal(
                        context,
                        StudioPortalCatalog.portals.firstWhere(
                          (portal) => portal.id == StudioPortalId.devices,
                        ),
                        activeProfileId,
                        profileController.activeProfile,
                      ),
                      onEmergency: () =>
                          _confirmEmergency(context, activeProfileId),
                      onContact: () =>
                          _open(context, 'settings', const SettingsScreen()),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<PermissionStatus>(
                      future: Permission.location.status,
                      builder: (context, snapshot) {
                        final granted = snapshot.data?.isGranted == true;
                        final gps = const GpsPriorityMonitor()
                            .fromPermission(granted: granted);
                        return Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: ListTile(
                            leading: const Icon(Icons.gps_fixed),
                            title: const Text('حالة GPS — أولوية عالية'),
                            subtitle: Text(gps.messageAr),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (showGate)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(trial.statusLineAr(feeExempt: exempt)),
                        ),
                      ),
                    if (showGate) const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        AccessibleActionButton(
                          icon: Icons.badge_outlined,
                          label: 'ملفي الصحي',
                          semanticHint: 'يفتح صفحة الملف الصحي الشخصي',
                          onTap: () {
                            _open(
                              context,
                              'profile',
                              HealthProfileScreen(
                                profile: profileController.activeProfile,
                              ),
                            );
                          },
                        ),
                        AccessibleActionButton(
                          icon: Icons.assignment_outlined,
                          label: 'الاستبيان الصحي',
                          semanticHint:
                              'يفتح الاستبيان الصحي الموسع لتسجيل بياناتك وحفظها في ملفك',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'profile',
                                    const SmartHealthQuestionnaireScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.medication_outlined,
                          label: 'أدويتي',
                          semanticHint: 'يفتح سجل الأدوية الشخصي والمرجع العام',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'medications',
                                    MedicationsScreen(
                                      profileId: activeProfileId,
                                    ),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.calendar_month_outlined,
                          label: 'مواعيدي',
                          semanticHint: 'يفتح قائمة المواعيد الطبية المحفوظة',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'appointments',
                                    const AppointmentsScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.mic_none_outlined,
                          label: 'التحكم الصوتي',
                          semanticHint:
                              'يستمع إلى أوامرك العربية ويفتح الوظيفة المطلوبة',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'voice',
                                    const VoiceControlScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.visibility_outlined,
                          label: 'المساعد البصري',
                          semanticHint:
                              'يفتح أدوات مساعدة المكفوفين وضعاف البصر',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'accessibility',
                                    AccessibilityAssistantScreen(
                                      profileId: activeProfileId,
                                    ),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.inventory_2_outlined,
                          label: 'صندوق المشروع',
                          semanticHint:
                              'يفتح الصندوق الكامل من التكوين حتى آخر يوم بما فيه المقاعد الفارغة',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'box',
                                    const ProjectBoxHubScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.public_outlined,
                          label: 'منظومة Lifex-AI',
                          semanticHint:
                              'يفتح المركز الموحد لجميع الوحدات الصحية',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'box',
                                    GlobalHealthDashboardScreen(
                                      profileId: activeProfileId,
                                    ),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'القناة الصحية',
                          semanticHint:
                              'محادثة صحية بأسلوب المراسلة: فلتر عام ومرفقات للمشتركين',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'chat',
                                    const HealthChatScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.hub_outlined,
                          label: 'الوحدات الصحية',
                          semanticHint:
                              'يفتح مركز المخابر والدم والتبرعات والمرأة والأسنان والتدريب',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'modules',
                                    const HealthModulesScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.volunteer_activism_outlined,
                          label: 'التبرعات',
                          semanticHint:
                              'تبقى مفتوحة بلا اشتراك: حملات الدعم الإنساني على هذا الجهاز',
                          onTap: () {
                            _open(
                              context,
                              'donations',
                              const BoxUnitScreen(
                                  unit: BoxUnitCatalog.donations),
                            );
                          },
                        ),
                        AccessibleActionButton(
                          icon: Icons.bloodtype_outlined,
                          label: 'شبكة الدم',
                          semanticHint:
                              'يفتح طلبات الدم للموافقين على هذا الجهاز',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'blood',
                                    const BloodRequestScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.local_pharmacy_outlined,
                          label: 'الصيدلية',
                          semanticHint:
                              'يفتح المخزون المحلي وأقرب صنف في المدينة المدخلة',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'pharmacy',
                                    const PharmacyStockScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.medical_services_outlined,
                          label: 'الأطباء',
                          semanticHint:
                              'يفتح دليل الأطباء المحلي مرتباً حسب المسافة المدخلة',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'doctors',
                                    const DoctorDirectoryScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'الكاميرا الذكية',
                          semanticHint:
                              'يلتقط أوراقاً بموافقة ظاهرة دون قراءة آلية مزيفة',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'camera',
                                    const CameraNotesScreen(),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'محفظتي',
                          semanticHint: 'يفتح المحفظة الرقمية وسجل المعاملات',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'wallet',
                                    WalletScreen(profileId: activeProfileId),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.smart_toy_outlined,
                          label: 'مركز الذكاء الاصطناعي',
                          semanticHint:
                              'يفتح إدارة حسابات محركات الذكاء الاصطناعي '
                              'المرتبطة مثل Gemini وChatGPT وClaude',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'ai',
                                    AiHubScreen(profileId: activeProfileId),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.psychology_outlined,
                          label: 'الوكيل الذكي',
                          semanticHint: 'يفتح وضع الوكيل متعدد الخطوات '
                              'والمحادثة المباشرة مع Lifex-AI',
                          onTap: activeProfileId == null
                              ? null
                              : () {
                                  _open(
                                    context,
                                    'ai',
                                    AiAgentScreen(profileId: activeProfileId),
                                  );
                                },
                        ),
                        AccessibleActionButton(
                          icon: Icons.emergency_outlined,
                          label: 'طوارئ',
                          semanticHint:
                              'يسجّل حالة طوارئ على هذا الجهاز. الإرسال الخارجي غير مربوط بعد. '
                              'اضغط ضغطاً مزدوجاً للتأكيد',
                          isUrgent: true,
                          onTap: () {
                            if (!_allowed(context, 'emergency')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(trial.statusLineAr()),
                                ),
                              );
                              return;
                            }
                            _confirmEmergency(context, activeProfileId);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmergencyConfirmationDialog(
    BuildContext context,
    String? activeProfileId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حالة طوارئ'),
        content: const Text(
          'ستُسجَّل حالة طوارئ على هذا الجهاز. الإرسال لجهات الثقة يحتاج قناة SMS أو دفع حقيقية. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const EmergencyContactsScreen()),
              );
            },
            child: const Text('جهات الثقة'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final profileId = activeProfileId ?? 'unknown_profile';
              final registry = context.read<EmergencyPhoneContactsRegistry>();
              final profile =
                  context.read<ActiveProfileController>().activeProfile;
              registry.replaceForProfile(
                profileId,
                EmergencyPhoneContactsRegistry.phonesFromTrustedMaps(
                  profile?.questionnaireData['trustedContacts'],
                ),
              );
              final outcome = await context
                  .read<EmergencyManager>()
                  .triggerEmergency(
                    profileId: profileId,
                    reasonAr: 'تفعيل يدوي من الشاشة الرئيسية بواسطة المستخدم.',
                  );

              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();

              announceForScreenReader(context, outcome.messageAr);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(outcome.messageAr),
                  backgroundColor:
                      outcome.outboundSent ? Colors.red : Colors.orange,
                ),
              );
            },
            child: const Text('تأكيد الطوارئ'),
          ),
        ],
      ),
    );
  }
}
