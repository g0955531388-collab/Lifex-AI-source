/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: settings_screen.dart
/// المسار: lib/screens/settings_screen.dart
/// الوصف: شاشة الإعدادات العامة — لغة، وضع ليلي، صلاحيات، خصوصية،
/// وتحديث المحتوى الطبي. ترتبط منطقياً بـ AppConfig وProfilePrivacyManager
/// وMedicalDatabaseManager.
/// =============================================================
library lifex_ai.screens.settings_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
import '../core/admin/admin_permissions.dart';
import '../core/admin/owner_identity_policy.dart';
import '../core/app_config.dart';
import '../core/lifex_locale.dart';
import '../core/studio_theme.dart';
import '../core/app_constants.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/trial_manager.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/lifex_brand_mark.dart';
import 'ai_hub_screen.dart';
import 'system_search_screen.dart';
import 'admin_dashboard_screen.dart';
import 'clinical_watch_screen.dart';
import 'family_management_screen.dart';
import 'identity_workspace_screen.dart';
import 'layered_lens_studio_screen.dart';
import 'partner_sign_in_screen.dart';
import 'permission_transparency_screen.dart';
import 'privacy_settings_screen.dart';
import 'project_box_hub_screen.dart';
import 'thumbnail_manage_screen.dart';
import '../widgets/lifex_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late StudioAppearance _appearance;
  late bool _voiceGuidanceEnabled;

  bool _isCheckingForUpdate = false;
  bool _isDownloadingUpdate = false;
  String? _updateStatusMessageAr;
  final _giftToken = TextEditingController();

  @override
  void initState() {
    super.initState();
    final config = AppConfig.instance;
    _appearance = config.appearance;
    _voiceGuidanceEnabled = config.voiceGuidanceEnabledByDefault;
  }

  @override
  void dispose() {
    _giftToken.dispose();
    super.dispose();
  }

  void _persist() {
    StudioThemeController.instance.setAppearance(_appearance);
    AppConfig.instance.updateFrom(
      appearance: _appearance,
      voiceGuidanceEnabledByDefault: _voiceGuidanceEnabled,
    );
    StudioThemeController.instance.refresh();
  }

  LioGatewayRequest _medicalReq(String action, {LioActionRisk risk = LioActionRisk.low}) {
    final profileId =
        Provider.of<ActiveProfileController>(context, listen: false)
                .activeProfileId ??
            'settings_local';
    return LioGatewayRequest(
      requestId: 'settings_${action}_${DateTime.now().millisecondsSinceEpoch}',
      correlationId: 'settings_$profileId',
      identityAccountId: profileId,
      purpose: 'settings',
      requestedAction: action,
      dataScope: 'settings_local',
      sensitivity: LioDataSensitivity.operational,
      consent: const LioConsentContext(
        consentGranted: true,
        purposeAligned: true,
      ),
      riskLevel: risk,
      timestamp: DateTime.now().toUtc(),
      authenticated: true,
      authorized: true,
      minimumNecessarySatisfied: true,
    );
  }

  Future<void> _checkForMedicalUpdate() async {
    setState(() {
      _isCheckingForUpdate = true;
      _updateStatusMessageAr = null;
    });

    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.checkMedicalDbVersion(
      gatewayRequest: _medicalReq('check_medical_db_version'),
    );

    if (!mounted) return;
    setState(() {
      _isCheckingForUpdate = false;
      if (!outcome.executed) {
        _updateStatusMessageAr =
            'توقف التحقق عند LIO (${outcome.decision.wireDecision}): ${outcome.decision.reasonAr}';
      } else {
        final newVersion = outcome.value;
        _updateStatusMessageAr = newVersion != null
            ? 'يتوفر إصدار جديد ($newVersion) لقاعدة البيانات الطبية.'
            : 'قاعدة بياناتك الطبية محدَّثة بالفعل.';
      }
    });
  }

  Future<void> _downloadMedicalUpdate() async {
    setState(() {
      _isDownloadingUpdate = true;
      _updateStatusMessageAr = null;
    });

    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.refreshMedicalKnowledge(
      gatewayRequest: _medicalReq(
        'download_medical_bundle',
        risk: LioActionRisk.medium,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isDownloadingUpdate = false;
      if (!outcome.executed) {
        _updateStatusMessageAr =
            'توقف التحديث عند LIO (${outcome.decision.wireDecision}): ${outcome.decision.reasonAr}';
      } else {
        _updateStatusMessageAr = outcome.value?.messageAr;
      }
    });

    final msg = _updateStatusMessageAr ?? 'تعذّر التحديث.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LifexText(msg),
        backgroundColor:
            outcome.executed && (outcome.value?.remoteOk ?? false)
                ? null
                : Colors.orange,
      ),
    );
  }

  /// معرّف Lifex-ID للملف النشط حالياً، أو null إن لم توجد هوية صحية
  /// مرتبطة بعد بالملف النشط.
  String? _activeLifexId(BuildContext context) {
    final activeProfileId =
        Provider.of<ActiveProfileController>(context).activeProfileId;
    if (activeProfileId == null) return null;
    return HealthIdentityManager.instance
        .getByProfileId(activeProfileId)
        ?.lifexId;
  }

  void _showOwnerActivationClosed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: LifexText(const OwnerIdentityPolicy().activationHintAr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLifexId = _activeLifexId(context);
    final activeProfile =
        Provider.of<ActiveProfileController>(context).activeProfile;
    final hasAdminRole = activeLifexId != null &&
        GlobalAdminManager.instance.roleOf(activeLifexId) != GlobalAdminRole.none;
    final isOwner = activeLifexId != null &&
        GlobalAdminManager.instance.isOwner(activeLifexId);
    final adminAccess = activeLifexId != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(activeLifexId);

    final phoneCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final fallbackNotice = lifexUntranslatedLanguageNotice(
      deviceCode: phoneCode,
    );
    return ListenableBuilder(
      listenable: StudioThemeController.instance,
      builder: (context, _) {
        final arabicNow =
            AppConfig.instance.defaultLanguage == AppLanguage.arabic;
        return ScreenArrival(
      message: lifexUi('الإعدادات', 'Settings'),
      controls: [
        lifexUi('المظهر', 'Appearance'),
        lifexUi('محركات الذكاء', 'AI engines'),
        lifexUi('بحث داخل وخارج', 'Search inside and outside'),
        lifexUi('الصلاحيات', 'Permissions'),
      ],
      body: lifexUi(
        'البحث بلا مفتاح يعمل. المفتاح اختياري ويبقى على هذا الجهاز.',
        'Search without a key works. A key is optional and stays on this device.',
      ),
      child: Scaffold(
      appBar: AppBar(title: LifexText(lifexUi('الإعدادات', 'Settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: LifexText(lifexUi('محركات الذكاء', 'AI engines')),
            subtitle: LifexText(lifexUi(
              'بلا مفتاح: المرجع المحلي ومحرك عام. بمفتاح: Gemini أو ChatGPT أو Claude على هذا الجهاز',
              'Without a key: the local reference and a general engine. With a key: Gemini, ChatGPT, or Claude on this device.',
            )),
            onTap: () {
              final profileId = activeProfile?.profileId;
              if (profileId == null || profileId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: LifexText(lifexUi(
                      'البحث بلا مفتاح متاح من بحث المنظومة. حفظ المفتاح يحتاج ملفاً صحياً.',
                      'Search without a key is available from system search. Saving a key needs a health profile.',
                    )),
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SystemSearchScreen(),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiHubScreen(profileId: profileId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: LifexText(lifexUi('بحث داخل المنظومة وخارجها', 'Search inside and outside')),
            subtitle: LifexText(lifexUi(
              'نتائج الجهاز أولاً، ثم خلاصة محرك عام بلا مفتاح. الملف الصحي لا يُرسل',
              'On-device results first, then a general engine summary without a key. The health profile is not sent.',
            )),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SystemSearchScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: LifexText(lifexUi('البحث على الإنترنت', 'Web search')),
            subtitle: LifexText(lifexUi(
              'اختيار المحرك وإضافة رابط https',
              'Choose the engine and add an https link',
            )),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SystemSearchScreen(startOnWeb: true),
              ),
            ),
          ),
          ListTile(
            title: LifexText(lifexUi('مظهر الاستوديو', 'Studio appearance')),
            subtitle: LifexText(lifexUi(
              'ليلي أردوازي، نهاري، أو تباين عالٍ.',
              'Dark slate, light, or high contrast.',
            )),
          ),
          RadioListTile<StudioAppearance>(
            title: LifexText(lifexUi('ليلي', 'Dark')),
            value: StudioAppearance.dark,
            groupValue: _appearance,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _appearance = value);
              _persist();
            },
          ),
          RadioListTile<StudioAppearance>(
            title: LifexText(lifexUi('نهاري', 'Light')),
            value: StudioAppearance.light,
            groupValue: _appearance,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _appearance = value);
              _persist();
            },
          ),
          RadioListTile<StudioAppearance>(
            title: LifexText(lifexUi('تباين عالٍ', 'High contrast')),
            value: StudioAppearance.contrast,
            groupValue: _appearance,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _appearance = value);
              _persist();
            },
          ),
          SwitchListTile(
            title: LifexText(lifexUi('الإرشاد الصوتي', 'Voice guidance')),
            subtitle: LifexText(lifexUi(
              'طبقة الإرشاد تبقى. الإيقاف يكتم النطق العادي. تنبيهات الطوارئ تُنطق.',
              'The guidance layer stays. Turning it off mutes ordinary speech. Emergency alerts are still spoken.',
            )),
            value: _voiceGuidanceEnabled,
            onChanged: (value) {
              setState(() => _voiceGuidanceEnabled = value);
              _persist();
            },
          ),
          Semantics(
            label: lifexUi(
              'اللغة. زر الترجمة يبدّل بين العربية والإنجليزية. الحالية ${arabicNow ? "العربية" : "الإنجليزية"}',
              'Language. The translation button switches Arabic and English. Current language is ${arabicNow ? "Arabic" : "English"}.',
            ),
            child: ListTile(
              title: LifexText(lifexUi('اللغة', 'Language')),
              subtitle: LifexText(
                [
                  lifexUi(
                    'زر الترجمة في كل صفحة يبدّل العربية والإنجليزية. الحالية ${arabicNow ? "العربية" : "الإنجليزية"}. بلا ضغط تبقى لغة الهاتف.',
                    'The translation button on every page switches Arabic and English. Current: ${arabicNow ? "Arabic" : "English"}. Until you press it, the phone language is used.',
                  ),
                  if (AppConfig.instance.explicitLanguage == null &&
                      fallbackNotice != null)
                    fallbackNotice,
                ].join(' '),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: LifexText(lifexUi('هوية الحساب وبيانات الاتصال', 'Account identity and contact')),
            subtitle: LifexText(lifexUi(
              'تحديث البريد أو الهاتف وتفعيل وصول المالك عند مطابقته',
              'Update the email or phone, and turn on owner access when it matches',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IdentityWorkspaceScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: LifexText(lifexUi('إدارة الصورة المصغّرة', 'Profile thumbnail')),
            subtitle: LifexText(lifexUi(
              'إدارة الصورة المصغّرة للملف والختم الرسمي',
              'Manage the profile thumbnail and the official seal',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ThumbnailManageScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.filter_none_outlined),
            title: LifexText(lifexUi('تقريب العدسة', 'Lens zoom')),
            subtitle: LifexText(lifexUi(
              'معاينة حية وزوم العتاد. ليست تشخيص جلد',
              'A live preview and hardware zoom. Not a skin diagnosis',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LayeredLensStudioScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: LifexText(lifexUi('إعدادات الخصوصية', 'Privacy settings')),
            subtitle: LifexText(lifexUi(
              'التحكم بمن يرى بياناتك الصحية',
              'Choose who can see your health data',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          Consumer<ActiveProfileController>(
            builder: (context, profiles, _) {
              final profile = profiles.activeProfile;
              if (profile == null) return const SizedBox.shrink();
              return SwitchListTile(
                secondary: const Icon(Icons.bloodtype_outlined),
                title: LifexText(lifexUi('إشعارات التبرع بالدم', 'Blood donation notices')),
                subtitle: LifexText(lifexUi(
                  'موقفة حتى تفعيلها. التبرع مجاني، والإيقاف لا يحذف محادثاتك.',
                  'Off until you turn them on. Donation is free, and turning them off does not delete your chats.',
                )),
                value: profile.acceptsBloodDonationAlerts,
                onChanged: (value) {
                  profile.acceptsBloodDonationAlerts = value;
                  profiles.notifyProfileChanged();
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: LifexText(lifexUi('صندوق المشروع أ', 'Project box A')),
            subtitle: LifexText(lifexUi('من التكوين حتى آخر يوم', 'From setup through the last day')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              final trial = context.read<TrialManager>();
              final profile =
                  context.read<ActiveProfileController>().activeProfile;
              final exempt = profile != null &&
                  const BillingExemptionPolicy().evaluate(profile).isExempt;
              final allowed = const SessionAccessPolicy().canOpenUnit(
                'box',
                phase: trial.phase(
                  feeExempt: exempt,
                  adminAccess: adminAccess,
                ),
                feeExempt: exempt,
                adminAccess: adminAccess,
              );
              if (!allowed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: LifexText(
                      trial.statusLine(
                        feeExempt: exempt,
                        adminAccess: adminAccess,
                      ),
                    ),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProjectBoxHubScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: LifexText(lifexUi('حالة النسخة والاشتراك', 'Copy and subscription status')),
            subtitle: LifexText(
              context.read<TrialManager>().statusLine(
                    feeExempt: activeProfile != null &&
                        const BillingExemptionPolicy()
                            .evaluate(activeProfile)
                            .isExempt,
                    adminAccess: adminAccess,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LifexText(lifexUi(
              'لا يجوز استنساخ التطبيق من غير مشترك. المشترك النظامي يُهدي نسخة واحدة لشخص آخر تعمل 15 يوماً ثم تتوقف حتى تخصيصها كمشترك جديد في الشهر المجاني المخفّف. التحقق بين جهازين يحتاج خادماً غير مربوط بعد.',
              'A copy may not be made from an unsubscribed install. A regular subscriber may gift one copy to one other person. It runs for 15 days, then it stops until it is assigned as a new subscriber in the reduced free month. Checking two devices needs a server that is not connected yet.',
            )),
          ),
          Consumer<ActiveProfileController>(
            builder: (context, profiles, _) {
              final trial = context.watch<TrialManager>();
              final profile = profiles.activeProfile;
              final exempt = profile != null &&
                  const BillingExemptionPolicy().evaluate(profile).isExempt;
              final subscribed = trial.phase(
                    feeExempt: exempt,
                    adminAccess: adminAccess,
                  ) ==
                  TrialPhase.subscribed;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.card_giftcard_outlined),
                    title: LifexText(lifexUi('إهداء نسخة واحدة', 'Gift one copy')),
                    subtitle: LifexText(
                      trial.hasIssuedGift
                          ? lifexUi(
                              'صدرت الهدية: ${trial.issuedGiftToken}',
                              'Gift issued: ${trial.issuedGiftToken}',
                            )
                          : lifexUi(
                              'للمشترك النظامي فقط، مرة واحدة.',
                              'For a regular subscriber only, once.',
                            ),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        final result = trial.issueGiftToken(
                          legallySubscribed: subscribed,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LifexText(result.messageAr)),
                        );
                        setState(() {});
                      },
                      child: LifexText(lifexUi('إصدار', 'Issue')),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _giftToken,
                      decoration: InputDecoration(
                        labelText: lifexUi(
                          'رمز الإهداء على جهاز المستلم',
                          'Gift code on the recipient device',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final result = trial.redeemGiftToken(_giftToken.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: LifexText(result.messageAr)),
                      );
                      setState(() {});
                    },
                    child: LifexText(lifexUi('تفعيل نسخة الإهداء', 'Activate the gift copy')),
                  ),
                  if (trial.phase(
                        feeExempt: exempt,
                        adminAccess: adminAccess,
                      ) ==
                      TrialPhase.giftFrozen)
                    FilledButton(
                      onPressed: () {
                        final result = trial.claimAsNewSubscriber();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: LifexText(result.messageAr)),
                        );
                        setState(() {});
                      },
                      child: LifexText(lifexUi(
                        'تخصيص النسخة وشهر مجاني مخفّف',
                        'Assign the copy and the reduced free month',
                      )),
                    ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.login_outlined),
            title: LifexText(lifexUi('الدخول بحساب لايفكس', 'Sign in with a Lifex account')),
            subtitle: LifexText(lifexUi(
              'يحق لك طلب الدخول لمواقع الذكاء الاصطناعي وغيرها ما عدا الإباحي. التنفيذ للشركاء فقط.',
              'You may request sign-in to AI sites and others, except explicit sites. Only partners carry that out.',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PartnerSignInScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom_outlined),
            title: LifexText(lifexUi('إدارة أفراد العائلة', 'Manage family members')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FamilyManagementScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: LifexText(lifexUi('شفافية الصلاحيات', 'Permission transparency')),
            subtitle: LifexText(lifexUi(
              'شرح وموافقة وإيقاف للكاميرا والصوت والموقع',
              'An explanation, a consent, and an off switch for the camera, microphone, and location',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PermissionTransparencyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: LifexText(lifexUi('مراقبة سريرية ظاهرة', 'Visible clinical watch')),
            subtitle: LifexText(lifexUi(
              'إشعار دائم بموافقة. بلا تصوير خفي وبلا حفظ صور',
              'An ongoing notice with consent. No hidden capture and no saved images',
            )),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClinicalWatchScreen(),
                ),
              );
            },
          ),
          if (hasAdminRole) ...[
            const Divider(),
            ListTile(
              leading: Icon(
                isOwner ? Icons.star : Icons.admin_panel_settings_outlined,
              ),
              title: LifexText(
                isOwner
                    ? lifexUi('لوحة المالك / المخترع', 'Owner / inventor desk')
                    : lifexUi('لوحة تحكم الأدمن', 'Admin desk'),
              ),
              subtitle: LifexText(
                isOwner
                    ? lifexUi(
                        'صيانة النظام وتعيين مدير وموظف ومشرف، مأجورين أو متطوعين',
                        'System maintenance and assigning a manager, staff member, or supervisor, paid or volunteer',
                      )
                    : lifexUi(
                        'إدارة الأدوار ومفاتيح الأحداث الدقيقة',
                        'Manage roles and the precise event keys',
                      ),
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminDashboardScreen(currentUserLifexId: activeLifexId),
                  ),
                );
              },
            ),
          ] else ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: LifexText(lifexUi('دور المالك التشغيلي', 'Operational owner role')),
              subtitle: LifexText(lifexUi(
                const OwnerIdentityPolicy().activationHintAr(),
                const OwnerIdentityPolicy().activationHintEn(),
              )),
              trailing: const Icon(Icons.chevron_left),
              onTap: _showOwnerActivationClosed,
            ),
          ],
          const Divider(),
          _buildMedicalUpdateSection(context),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: LifexText(lifexUi('حول التطبيق', 'About')),
            subtitle: const LifexText(AppConstants.systemName),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: const LifexBrandMark(size: 72),
                children: [
                  const SizedBox(height: 12),
                  const LifexBrandMark(size: 140),
                  const SizedBox(height: 12),
                  const LifexText(
                    AppConstants.builderAttributionAr,
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const LifexText(
                    AppConstants.ownershipStatement,
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const LifexText(
                    AppConstants.humanitarianExemptionStatementAr,
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const LifexText(
                    AppConstants.academyNameAr,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      ),
    );
      },
    );
  }

  /// قسم "تحديث وتوسيع المحتوى الطبي" — يسمح للمستخدم بالتحقق من وجود
  /// إصدار أحدث لقاعدة البيانات الطبية وتحميله بأمان، مع إبقاء النسخة
  /// الحالية تعمل بلا انقطاع في حال فشل أو تأجيل التحديث.
  Widget _buildMedicalUpdateSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_information_outlined),
              const SizedBox(width: 12),
              LifexText(
                lifexUi('تحديث وتوسيع المحتوى الطبي', 'Update and extend the medical content'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LifexText(
            lifexUi(
              'قاعدة البحث الداخلية تدوم بلا انتهاء. الزر يبحث في قواعد الجهاز '
                  'ويحاول جلب حزمة الخادم إن وُجدت، ثم يضيفها للمحرك. التطبيق يبقى يعمل.',
              'The internal search base does not expire. The button searches the device bases, tries to fetch a server bundle if one exists, then adds it to the engine. The app keeps running.',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                icon: _isCheckingForUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: LifexText(lifexUi('التحقق من وجود تحديثات', 'Check for updates')),
                onPressed: _isCheckingForUpdate || _isDownloadingUpdate
                    ? null
                    : _checkForMedicalUpdate,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: _isDownloadingUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_outlined),
                label: LifexText(lifexUi(
                  'ابحث وجُلب للقواعد الداخلية',
                  'Search and bring into the internal bases',
                )),
                onPressed: _isCheckingForUpdate || _isDownloadingUpdate
                    ? null
                    : _downloadMedicalUpdate,
              ),
            ],
          ),
          if (_updateStatusMessageAr != null) ...[
            const SizedBox(height: 8),
            LifexText(
              _updateStatusMessageAr!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
