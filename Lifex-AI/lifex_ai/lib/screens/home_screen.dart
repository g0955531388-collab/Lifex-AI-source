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

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/trial_manager.dart';
import '../features/emergency/emergency_phone_contacts_registry.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/location/gps_priority_monitor.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/encyclopedia_share_bar.dart';
import 'accessibility_assistant_screen.dart';
import 'ai_agent_screen.dart';
import 'ai_hub_screen.dart';
import 'appointments_screen.dart';
import 'blood_request_screen.dart';
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
import 'device_center_screen.dart';
import 'donations_center_screen.dart';
import 'voice_control_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool _allowed(BuildContext context, String unitId) {
    final trial = context.read<TrialManager>();
    final profile = context.read<ActiveProfileController>().activeProfile;
    final exempt = profile != null &&
        const BillingExemptionPolicy().evaluate(profile).isExempt;
    return const SessionAccessPolicy().canOpenUnit(
      unitId,
      phase: trial.phase(feeExempt: exempt),
      feeExempt: exempt,
    );
  }

  void _open(BuildContext context, String unitId, Widget page) {
    if (!_allowed(context, unitId)) {
      final trial = context.read<TrialManager>();
      final phase = trial.phase();
      final reason = phase == TrialPhase.giftFrozen
          ? 'REQUIRES_EXTERNAL_SETUP — نسخة الإهداء غير مخصّصة بعد. '
              'افتح الإعدادات لإكمال التخصيص.'
          : trial.statusLineAr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
        final phase = trial.phase(feeExempt: exempt);
        final showGate = !exempt &&
            phase != TrialPhase.subscribed &&
            phase != TrialPhase.giftWorking;

        return Scaffold(
          bottomNavigationBar: const EncyclopediaShareBar(),
          appBar: AppBar(
            title: const Text('Lifex-AI'),
            actions: [
              Semantics(
                button: true,
                label: 'بحث المنظومة',
                hint: 'يفتح البحث في الوحدات والمرجع المحلي',
                child: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'بحث المنظومة',
                  onPressed: () => _open(
                    context,
                    'search',
                    const SystemSearchScreen(),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'الإعدادات',
                hint: 'يفتح شاشة إعدادات التطبيق واللغة والخصوصية',
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'الإعدادات',
                  onPressed: () {
                    _open(context, 'settings', const SettingsScreen());
                  },
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
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
                  Expanded(
                    child: GridView.count(
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
                          icon: Icons.devices_other_outlined,
                          label: 'مركز الأجهزة',
                          semanticHint:
                              'اكتشاف وربط الأجهزة عبر السائق والبروتوكول ومركز التحكم',
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
                    reasonAr:
                        'تفعيل يدوي من الشاشة الرئيسية بواسطة المستخدم.',
                  );

              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();

              final msg = outcome.executed
                  ? (outcome.value?.messageAr ?? 'أُرسلت إشارة الطوارئ المحدودة.')
                  : 'توقفت الطوارئ عند LIO (${outcome.decision.wireDecision}): ${outcome.decision.reasonAr}';

              announceForScreenReader(context, msg);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: outcome.executed &&
                          (outcome.value?.outboundSent ?? false)
                      ? Colors.red
                      : Colors.orange,
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
