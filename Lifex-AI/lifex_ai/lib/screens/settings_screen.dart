/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: settings_screen.dart
/// المسار: lib/screens/settings_screen.dart
/// الوصف: شاشة الإعدادات العامة — لغة، وضع ليلي، صلاحيات، خصوصية،
/// وتحديث المحتوى الطبي. ترتبط منطقياً بـ AppConfig وProfilePrivacyManager
/// وMedicalDatabaseManager.
/// =============================================================
library lifex_ai.screens.settings_screen;

import 'dart:async';

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
    AppConfig.instance.explicitLanguage = null;
    unawaited(AppConfig.instance.saveExplicitLanguage());
    AppConfig.instance.updateFrom(
      appearance: _appearance,
      voiceGuidanceEnabledByDefault: _voiceGuidanceEnabled,
      followDeviceLanguage: true,
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
        content: Text(msg),
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
    return HealthIdentityManager.instance.getByProfileId(activeProfileId)?.lifexId;
  }

  void _showOwnerActivationClosed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(const OwnerIdentityPolicy().activationHintAr())),
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
    final arabicNow =
        AppConfig.instance.defaultLanguage == AppLanguage.arabic;
    return ScreenArrival(
      message: lifexUi('الإعدادات', 'Settings'),
      controls: const ['المظهر', 'محركات الذكاء', 'بحث داخل وخارج', 'الصلاحيات'],
      body: 'البحث بلا مفتاح يعمل. المفتاح اختياري ويبقى على هذا الجهاز.',
      child: Scaffold(
      appBar: AppBar(title: Text(lifexUi('الإعدادات', 'Settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('محركات الذكاء'),
            subtitle: const Text(
              'بلا مفتاح: المرجع المحلي ومحرك عام. بمفتاح: Gemini أو ChatGPT أو Claude على هذا الجهاز',
            ),
            onTap: () {
              final profileId = activeProfile?.profileId;
              if (profileId == null || profileId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'البحث بلا مفتاح متاح من بحث المنظومة. حفظ المفتاح يحتاج ملفاً صحياً.',
                    ),
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
            title: const Text('بحث داخل المنظومة وخارجها'),
            subtitle: const Text(
              'نتائج الجهاز أولاً، ثم خلاصة محرك عام بلا مفتاح. الملف الصحي لا يُرسل',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SystemSearchScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: const Text('البحث على الإنترنت'),
            subtitle: const Text('اختيار المحرك وإضافة رابط https'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SystemSearchScreen(startOnWeb: true),
              ),
            ),
          ),
          const ListTile(
            title: Text('مظهر الاستوديو'),
            subtitle: Text('ليلي أردوازي، نهاري، أو تباين عالٍ.'),
          ),
          RadioListTile<StudioAppearance>(
            title: const Text('ليلي'),
            value: StudioAppearance.dark,
            groupValue: _appearance,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _appearance = value);
              _persist();
            },
          ),
          RadioListTile<StudioAppearance>(
            title: const Text('نهاري'),
            value: StudioAppearance.light,
            groupValue: _appearance,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _appearance = value);
              _persist();
            },
          ),
          RadioListTile<StudioAppearance>(
            title: const Text('تباين عالٍ'),
            value: StudioAppearance.contrast,
            groupValue: _appearance,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _appearance = value);
              _persist();
            },
          ),
          SwitchListTile(
            title: const Text('الإرشاد الصوتي'),
            subtitle: const Text(
              'طبقة الإرشاد تبقى. الإيقاف يكتم النطق العادي. تنبيهات الطوارئ تُنطق.',
            ),
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
              title: Text(lifexUi('اللغة', 'Language')),
              subtitle: Text(
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
            title: const Text('هوية الحساب وبيانات الاتصال'),
            subtitle: const Text(
              'تحديث البريد أو الهاتف وتفعيل وصول المالك عند مطابقته',
            ),
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
            title: Text(lifexUi('إدارة الصورة المصغّرة', 'Profile thumbnail')),
            subtitle: const Text('إدارة الصورة المصغّرة للملف والختم الرسمي'),
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
            title: const Text('تقريب العدسة'),
            subtitle: const Text('معاينة حية وزوم العتاد. ليست تشخيص جلد'),
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
            title: const Text('إعدادات الخصوصية'),
            subtitle: const Text('التحكم بمن يرى بياناتك الصحية'),
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
                title: const Text('إشعارات التبرع بالدم'),
                subtitle: const Text(
                  'موقفة حتى تفعيلها. التبرع مجاني، والإيقاف لا يحذف محادثاتك.',
                ),
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
            title: const Text('صندوق المشروع أ'),
            subtitle: const Text('من التكوين حتى آخر يوم'),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProjectBoxHubScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('حالة النسخة والاشتراك'),
            subtitle: Text(
              context.read<TrialManager>().statusLineAr(
                    feeExempt: activeProfile != null &&
                        const BillingExemptionPolicy()
                            .evaluate(activeProfile)
                            .isExempt,
                    adminAccess: adminAccess,
                  ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'لا يجوز استنساخ التطبيق من غير مشترك. المشترك النظامي يُهدي نسخة واحدة لشخص آخر تعمل 15 يوماً ثم تتوقف حتى تخصيصها كمشترك جديد في الشهر المجاني المخفّف. التحقق بين جهازين يحتاج خادماً غير مربوط بعد.',
            ),
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
                    title: const Text('إهداء نسخة واحدة'),
                    subtitle: Text(
                      trial.hasIssuedGift
                          ? 'صدرت الهدية: ${trial.issuedGiftToken}'
                          : 'للمشترك النظامي فقط، مرة واحدة.',
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        final result = trial.issueGiftToken(
                          legallySubscribed: subscribed,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.messageAr)),
                        );
                        setState(() {});
                      },
                      child: const Text('إصدار'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _giftToken,
                      decoration: const InputDecoration(
                        labelText: 'رمز الإهداء على جهاز المستلم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final result = trial.redeemGiftToken(_giftToken.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.messageAr)),
                      );
                      setState(() {});
                    },
                    child: const Text('تفعيل نسخة الإهداء'),
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
                          SnackBar(content: Text(result.messageAr)),
                        );
                        setState(() {});
                      },
                      child: const Text('تخصيص النسخة وشهر مجاني مخفّف'),
                    ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.login_outlined),
            title: const Text('الدخول بحساب لايفكس'),
            subtitle: const Text(
              'يحق لك طلب الدخول لمواقع الذكاء الاصطناعي وغيرها ما عدا الإباحي. التنفيذ للشركاء فقط.',
            ),
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
            title: const Text('إدارة أفراد العائلة'),
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
            title: const Text('شفافية الصلاحيات'),
            subtitle: const Text('شرح وموافقة وإيقاف للكاميرا والصوت والموقع'),
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
            title: const Text('مراقبة سريرية ظاهرة'),
            subtitle: const Text('إشعار دائم بموافقة. بلا تصوير خفي وبلا حفظ صور'),
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
              title: Text(
                isOwner
                    ? 'لوحة المالك / المخترع'
                    : 'لوحة تحكم الأدمن',
              ),
              subtitle: Text(
                isOwner
                    ? 'صيانة النظام وتعيين مدير وموظف ومشرف، مأجورين أو متطوعين'
                    : 'إدارة الأدوار ومفاتيح الأحداث الدقيقة',
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
              title: const Text('دور المالك التشغيلي'),
              subtitle: Text(const OwnerIdentityPolicy().activationHintAr()),
              trailing: const Icon(Icons.chevron_left),
              onTap: _showOwnerActivationClosed,
            ),
          ],
          const Divider(),
          _buildMedicalUpdateSection(context),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('حول التطبيق'),
            subtitle: const Text(AppConstants.systemName),
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
                  const Text(
                    AppConstants.builderAttributionAr,
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppConstants.ownershipStatement,
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppConstants.humanitarianExemptionStatementAr,
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  const Text(
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
              Text(
                'تحديث وتوسيع المحتوى الطبي',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'قاعدة البحث الداخلية تدوم بلا انتهاء. الزر يبحث في قواعد الجهاز '
            'ويحاول جلب حزمة الخادم إن وُجدت، ثم يضيفها للمحرك. التطبيق يبقى يعمل.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                label: const Text('التحقق من وجود تحديثات'),
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
                label: const Text('ابحث وجُلب للقواعد الداخلية'),
                onPressed: _isCheckingForUpdate || _isDownloadingUpdate
                    ? null
                    : _downloadMedicalUpdate,
              ),
            ],
          ),
          if (_updateStatusMessageAr != null) ...[
            const SizedBox(height: 8),
            Text(
              _updateStatusMessageAr!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
