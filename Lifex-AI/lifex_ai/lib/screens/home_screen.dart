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
import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import '../core/studio_theme.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/trial_manager.dart';
import '../features/emergency/emergency_phone_contacts_registry.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/location/gps_priority_monitor.dart';
import '../features/network_box/studio_portal_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/health_profile.dart';
import '../widgets/studio_menu_bar.dart';
import '../widgets/studio_web_frame.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/accessible_widgets.dart';
import '../features/voice/first_run_voice.dart';
import '../features/spot/spot_camera_page.dart';
import '../widgets/blind_assist_entry.dart';
import '../widgets/device_wall_clock.dart';
import '../widgets/lifex_language_button.dart';
import '../widgets/encyclopedia_share_bar.dart';
import 'accessibility_assistant_screen.dart';
import 'ai_agent_screen.dart';
import 'ai_hub_screen.dart';
import 'appointments_screen.dart';
import 'blood_request_screen.dart';
import 'camera_notes_screen.dart';
import 'care_cycle_screen.dart';
import 'doctor_directory_screen.dart';
import 'professional_directory_screen.dart';
import 'nearby_care_screen.dart';
import 'emergency_contacts_screen.dart';
import 'global_health_dashboard_screen.dart';
import 'health_chat_screen.dart';
import 'health_modules_screen.dart';
import 'messenger_screen.dart';
import 'health_guidance_screen.dart';
import 'epidemic_surveillance_screen.dart';
import 'live_sight_screen.dart';
import 'lifex_unified_web_portal_screen.dart';
import 'health_profile_screen.dart';
import 'medications_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'project_box_hub_screen.dart';
import 'settings_screen.dart';
import 'studio_network_screen.dart';
import 'smart_health_questionnaire_screen.dart';
import 'clinical_watch_screen.dart';
import 'system_search_screen.dart';
import 'device_center_screen.dart';
import 'donations_center_screen.dart';
import 'voice_control_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const servicesKey = GlobalObjectKey('lifex-studio-services');

  bool _adminAccess(HealthProfile? profile) {
    if (profile == null) return false;
    final identity =
        HealthIdentityManager.instance.getByProfileId(profile.profileId);
    return identity != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
  }

  bool _allowed(BuildContext context, String unitId) {
    final trial = context.read<TrialManager>();
    final profile = context.read<ActiveProfileController>().activeProfile;
    final exempt = profile != null &&
        const BillingExemptionPolicy().evaluate(profile).isExempt;
    final adminAccess = _adminAccess(profile);
    return const SessionAccessPolicy().canOpenUnit(
      unitId,
      phase: trial.phase(feeExempt: exempt, adminAccess: adminAccess),
      feeExempt: exempt,
      adminAccess: adminAccess,
    );
  }

  Future<void> _open(BuildContext context, String unitId, Widget page) async {
    if (!_allowed(context, unitId)) {
      final trial = context.read<TrialManager>();
      final phase = trial.phase();
      final reason = phase == TrialPhase.giftFrozen
          ? 'REQUIRES_EXTERNAL_SETUP — نسخة الإهداء غير مخصّصة بعد. '
              'افتح الإعدادات لإكمال التخصيص.'
          : trial.statusLineAr();
      announceForScreenReader(context, reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
      announceForScreenReader(context, BlindNavigationCopy.needsProfileText);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BlindNavigationCopy.needsProfileText)),
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
        final adminAccess = _adminAccess(profileController.activeProfile);
        final phase = trial.phase(feeExempt: exempt, adminAccess: adminAccess);
        final showGate = !adminAccess &&
            !exempt &&
            phase != TrialPhase.subscribed &&
            phase != TrialPhase.giftWorking;

        return ScreenArrival(
          message: BlindNavigationCopy.homeArrival(
            hasProfile: activeProfileId != null,
          ),
          child: Scaffold(
            bottomNavigationBar: const EncyclopediaShareBar(),
            body: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlindAssistEntry(
                  onOpenAssistant: () => _open(
                    context,
                    'camera',
                    LiveSightScreen(
                      profileId: activeProfileId ?? '',
                      ask: BlindCameraAsk.scene,
                      initialOrder: BlindCameraOrder.back,
                    ),
                  ),
                  onOpenSpot: () => _open(
                    context,
                    'camera',
                    const SpotCameraPage(),
                  ),
                ),
                Expanded(
                  child: Column(
              children: [
                const FirstRunVoiceHook(),
                const AttributionMarqueeBar(),
                _HomeDirectActions(
                  onMessenger: () {
                    if (activeProfileId == null) {
                      announceForScreenReader(
                        context,
                        BlindNavigationCopy.needsProfileText,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(BlindNavigationCopy.needsProfileText),
                        ),
                      );
                      return;
                    }
                    _open(context, 'chat', const MessengerScreen());
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      StudioMenuBar(
                        includeBanner: false,
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
                        onEmergency: () => _showEmergencyConfirmationDialog(
                          context,
                          activeProfileId,
                        ),
                      ),
                      AccessibleActionButton(
                        icon: Icons.visibility_outlined,
                        label: context.nav('nav.blindCamera'),
                        semanticHint:
                            'يفتح البث الحي. الوصف الأساسي أولاً، والتفاصيل عند الطلب',
                        onTap: () {
                          _open(
                            context,
                            'camera',
                            LiveSightScreen(
                              profileId: activeProfileId ?? '',
                              ask: BlindCameraAsk.scene,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AccessibleActionButton(
                        icon: Icons.settings_outlined,
                        label: context.nav('nav.settings'),
                        semanticHint:
                            'تفتح المظهر واللغة والصلاحيات وربط محركات الذكاء والبحث داخل المنظومة وخارجها',
                        onTap: () {
                          _open(
                            context,
                            'settings',
                            const SettingsScreen(),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      AccessibleActionButton(
                        icon: Icons.public,
                        label: context.nav('nav.portal'),
                        semanticHint:
                            'تشغّل بوابة الموقع داخل التطبيق: بحث وصوت وكاميرا وطوارئ. ليست موقعاً على الإنترنت ولا علاجاً معتمداً',
                        onTap: () {
                          _open(
                            context,
                            'box',
                            LifexUnifiedWebPortalScreen(
                              profileId: activeProfileId ?? '',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
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
                            Scrollable.ensureVisible(
                              target,
                              duration: const Duration(milliseconds: 250),
                            );
                          }
                        },
                        onEmergency: () => _showEmergencyConfirmationDialog(
                          context,
                          activeProfileId,
                        ),
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
                      HonestyBanner.medical(),
                      const SizedBox(height: 12),
                      FutureBuilder<PermissionStatus>(
                        future: Permission.location.status,
                        builder: (context, snapshot) {
                          final granted = snapshot.data?.isGranted == true;
                          final gps = const GpsPriorityMonitor()
                              .fromPermission(granted: granted);
                          return Card(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: ListTile(
                              leading: const Icon(Icons.gps_fixed),
                              title: Text(lifexUi('حالة GPS — أولوية عالية', 'GPS status — high priority')),
                              subtitle: Text(
                                '${gps.messageAr} اضغط لاقتراح الأقرب حسب الاختصاص.',
                              ),
                              onTap: () => _open(
                                context,
                                'nearby',
                                const NearbyCareScreen(),
                              ),
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
                      Text(
                        'صفحات الجهاز',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      AccessibleActionButton(
                        icon: Icons.public_outlined,
                        label: context.nav('nav.outbreak'),
                        semanticHint:
                            'يفتح تقييم إشارة وبائية من أرقام تُدخلها. ليس إعلاناً رسمياً',
                        onTap: () {
                          _open(
                            context,
                            'box',
                            EpidemicSurveillanceScreen(
                              profileId: activeProfileId,
                            ),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.health_and_safety_outlined,
                        label: context.nav('nav.guidance'),
                        semanticHint:
                            'يفتح استشارة تثقيفية مجانية من المرجع المحلي. ليست تشخيصاً',
                        onTap: () {
                          _open(
                            context,
                            'box',
                            HealthGuidanceScreen(profileId: activeProfileId),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.badge_outlined,
                        label: context.nav('nav.healthProfile'),
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
                        label: context.nav('nav.questionnaire'),
                        semanticHint:
                            'يفتح الاستبيان الصحي الموسع لتسجيل بياناتك وحفظها في ملفك',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        icon: Icons.account_tree_outlined,
                        label: context.nav('nav.careCycle'),
                        semanticHint:
                            'تقرير أولي ثم طبيب معتمد وحجز وطلب صيدلية وعرض مالي',
                        disabledHint: BlindNavigationCopy.needsProfileText,
                        onTap: activeProfileId == null
                            ? null
                            : () {
                                _open(
                                  context,
                                  'profile',
                                  const CareCycleScreen(),
                                );
                              },
                      ),
                      AccessibleActionButton(
                        icon: Icons.medication_outlined,
                        label: context.nav('nav.medications'),
                        semanticHint: 'يفتح سجل الأدوية الشخصي والمرجع العام',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.appointments'),
                        semanticHint:
                            'يفتح التقويم ومواعيدك المحلية شهراً ويوماً',
                        onTap: () {
                          _open(
                            context,
                            'appointments',
                            const AppointmentsScreen(),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.mic_none_outlined,
                        label: context.nav('nav.voice'),
                        semanticHint:
                            'يستمع إلى أوامرك العربية ويفتح الوظيفة المطلوبة',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        icon: Icons.search,
                        label: context.nav('nav.search'),
                        semanticHint:
                            'يبحث داخل المنظومة فوراً، والإنترنت زر منفصل. يمكن الكتابة أو الصوت',
                        onTap: () {
                          _open(
                            context,
                            'search',
                            const SystemSearchScreen(),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.devices_other_outlined,
                        label: context.nav('nav.devices'),
                        semanticHint:
                            'اكتشاف وربط الأجهزة عبر السائق والبروتوكول ومركز التحكم',
                        disabledHint: BlindNavigationCopy.needsProfileText,
                        onTap: activeProfileId == null
                            ? null
                            : () {
                                _open(
                                  context,
                                  'devices',
                                  const DeviceCenterScreen(),
                                );
                              },
                      ),
                      AccessibleActionButton(
                        icon: Icons.visibility_outlined,
                        label: context.nav('nav.visualAssistant'),
                        semanticHint: 'يفتح أدوات مساعدة المكفوفين وضعاف البصر',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.projectBox'),
                        semanticHint:
                            'يفتح الصندوق الكامل من التكوين حتى آخر يوم بما فيه المقاعد الفارغة',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.network'),
                        semanticHint: 'يفتح المركز الموحد لجميع الوحدات الصحية',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        icon: Icons.dashboard_outlined,
                        label: context.nav('nav.studio'),
                        semanticHint:
                            'يفتح بوابات مستودع الاستوديو على المقاعد المحلية',
                        disabledHint: BlindNavigationCopy.needsProfileText,
                        onTap: activeProfileId == null
                            ? null
                            : () {
                                _open(
                                  context,
                                  'box',
                                  StudioNetworkScreen(
                                    profileId: activeProfileId,
                                  ),
                                );
                              },
                      ),
                      AccessibleActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: context.nav('nav.healthChannel'),
                        semanticHint:
                            'محادثة صحية بأسلوب المراسلة: فلتر عام ومرفقات للمشتركين',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        icon: Icons.forum_outlined,
                        label: context.nav('nav.messenger'),
                        semanticHint:
                            'محادثات بالرقم أو البريد على هذا الجهاز، والاسم الظاهر مستعار. بلا إنترنت تُفتح مسودة رسالة قصيرة وورقة مشاركة للبلوتوث أو الواي فاي القريب. الكابل غير مربوط. الغرفة محلية بلا فيديو بعيد',
                        disabledHint: BlindNavigationCopy.needsProfileText,
                        onTap: activeProfileId == null
                            ? null
                            : () {
                                _open(
                                  context,
                                  'chat',
                                  const MessengerScreen(),
                                );
                              },
                      ),
                      AccessibleActionButton(
                        icon: Icons.health_and_safety_outlined,
                        label: context.nav('nav.background'),
                        semanticHint:
                            'إشعار ظاهر يبقي الاستماع للأوامر لحماية من يستخدم الهاتف. ليس تصويراً خفياً ولا اتصالاً صامتاً',
                        onTap: () {
                          _open(
                            context,
                            'voice',
                            const ClinicalWatchScreen(),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.meeting_room_outlined,
                        label: context.nav('nav.meeting'),
                        semanticHint:
                            'غرفة فيديو على هذا الجهاز. الصورة لا تغادر الهاتف',
                        disabledHint: BlindNavigationCopy.needsProfileText,
                        onTap: activeProfileId == null
                            ? null
                            : () {
                                _open(
                                  context,
                                  'chat',
                                  const MessengerScreen(initialTab: 3),
                                );
                              },
                      ),
                      AccessibleActionButton(
                        icon: Icons.hub_outlined,
                        label: context.nav('nav.units'),
                        semanticHint:
                            'يفتح مركز المخابر والدم والتبرعات والمرأة والأسنان والتدريب',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.donations'),
                        semanticHint:
                            'يفتح مركز التبرعات: بحث عام موافق، رسوم، محفظة، عيني',
                        onTap: () {
                          _open(
                            context,
                            'donations',
                            const DonationsCenterScreen(),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.bloodtype_outlined,
                        label: context.nav('nav.blood'),
                        semanticHint:
                            'يفتح طلبات الدم للموافقين على هذا الجهاز',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.pharmacy'),
                        semanticHint:
                            'يفتح المخزون المحلي وأقرب صنف في المدينة المدخلة',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        icon: Icons.badge_outlined,
                        label: context.nav('nav.directory'),
                        semanticHint:
                            'يفتح دليلاً محلياً للمهن. التجربة 48 ساعة. الدفع لا يُرسل بلا تأكيد مرخّص',
                        onTap: () {
                          _open(
                            context,
                            'directory',
                            const ProfessionalDirectoryScreen(),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.medical_services_outlined,
                        label: context.nav('nav.doctors'),
                        semanticHint:
                            'يفتح دليل الأطباء. فارغ إن لم تُضف بيانات بعد — ليس رفض صلاحية',
                        onTap: () {
                          _open(
                            context,
                            'doctors',
                            const DoctorDirectoryScreen(),
                          );
                        },
                      ),
                      AccessibleActionButton(
                        icon: Icons.camera_alt_outlined,
                        label: context.nav('nav.smartCamera'),
                        semanticHint:
                            'يلتقط أوراقاً بموافقة ظاهرة دون قراءة آلية مزيفة',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.wallet'),
                        semanticHint: 'يفتح المحفظة الرقمية وسجل المعاملات',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.aiCenter'),
                        semanticHint:
                            'بحث بلا مفتاح في المرجع المحلي ومحرك عام، '
                            'وربط اختياري بمفتاح Gemini أو ChatGPT أو Claude',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.agent'),
                        semanticHint: 'يفتح وضع الوكيل متعدد الخطوات '
                            'والمحادثة المباشرة مع Lifex-AI',
                        disabledHint: BlindNavigationCopy.needsProfileText,
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
                        label: context.nav('nav.emergency'),
                        semanticHint:
                            'يسجّل حالة طوارئ على هذا الجهاز. الإرسال الخارجي غير مربوط بعد. '
                            'اضغط ضغطاً مزدوجاً للتأكيد',
                        isUrgent: true,
                        onTap: () {
                          if (!_allowed(context, 'emergency')) {
                            final line = trial.statusLineAr();
                            announceForScreenReader(context, line);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(line),
                              ),
                            );
                            return;
                          }
                          _showEmergencyConfirmationDialog(
                              context, activeProfileId);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
                ),
              ],
            ),
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
        title: Text(lifexUi('تأكيد حالة طوارئ', 'Confirm emergency')),
        content: const Text(
          'ستُسجَّل حالة طوارئ على هذا الجهاز. الإرسال لجهات الثقة يحتاج قناة SMS أو دفع حقيقية. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(lifexUi('إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const EmergencyContactsScreen()),
              );
            },
            child: Text(lifexUi('جهات الثقة', 'Trusted contacts')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
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
                  .read<LioSensitiveActionEntry>()
                  .triggerEmergencyLimited(
                    gatewayRequest: LioGatewayRequest(
                      requestId:
                          'emg_home_${profileId}_${DateTime.now().millisecondsSinceEpoch}',
                      correlationId: 'emg_$profileId',
                      identityAccountId: profileId,
                      purpose: 'emergency_signal',
                      requestedAction: 'signal_trusted_contacts',
                      dataScope: 'emergency_contacts_min',
                      sensitivity: LioDataSensitivity.personal,
                      consent: const LioConsentContext(
                        consentGranted: true,
                        purposeAligned: true,
                      ),
                      riskLevel: LioActionRisk.high,
                      timestamp: DateTime.now().toUtc(),
                      authenticated: true,
                      authorized: true,
                      emergencyLimitedMode: true,
                      humanConfirmed: true,
                      minimumNecessarySatisfied: true,
                    ),
                    profileId: profileId,
                    reasonAr: 'تفعيل يدوي من الشاشة الرئيسية بواسطة المستخدم.',
                  );

              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();

              final msg = outcome.executed
                  ? (outcome.value?.messageAr ??
                      'أُرسلت إشارة الطوارئ المحدودة.')
                  : 'توقفت الطوارئ عند LIO (${outcome.decision.wireDecision}): ${outcome.decision.reasonAr}';

              announceForScreenReader(context, msg);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor:
                      outcome.executed && (outcome.value?.outboundSent ?? false)
                          ? Colors.red
                          : Colors.orange,
                ),
              );
            },
            child: Text(lifexUi('تأكيد الطوارئ', 'Confirm emergency')),
          ),
        ],
      ),
    );
  }
}

class _HomeDirectActions extends StatelessWidget {
  const _HomeDirectActions({
    required this.onMessenger,
  });

  final VoidCallback onMessenger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: LifexLanguageButton(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DirectButton(
                  icon: Icons.chat_rounded,
                  label: context.nav('nav.messenger'),
                  hint: 'يفتح المسنجر على هذا الجهاز',
                  onPressed: onMessenger,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: DeviceWallClockView()),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectButton extends StatelessWidget {
  const _DirectButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: ExcludeSemantics(
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: StudioTheme.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
