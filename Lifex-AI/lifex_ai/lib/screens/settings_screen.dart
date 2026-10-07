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
import '../core/app_config.dart';
import '../core/app_constants.dart';
import '../core/lasting_search_index.dart';
import '../core/local_knowledge.dart';
import '../core/search_refresh_engine.dart';
import '../core/trial_manager.dart';
import '../data/medical_database_manager.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../widgets/lifex_brand_mark.dart';
import 'admin_dashboard_screen.dart';
import 'clinical_watch_screen.dart';
import 'family_management_screen.dart';
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
  late bool _darkModeEnabled;
  late bool _voiceGuidanceEnabled;
  late AppLanguage _selectedLanguage;

  bool _isCheckingForUpdate = false;
  bool _isDownloadingUpdate = false;
  String? _updateStatusMessageAr;
  final _giftToken = TextEditingController();

  @override
  void initState() {
    super.initState();
    final config = AppConfig.instance;
    _darkModeEnabled = config.darkModeEnabled;
    _voiceGuidanceEnabled = config.voiceGuidanceEnabledByDefault;
    _selectedLanguage = config.defaultLanguage;
  }

  @override
  void dispose() {
    _giftToken.dispose();
    super.dispose();
  }

  void _persist() {
    AppConfig.instance.updateFrom(
      darkModeEnabled: _darkModeEnabled,
      voiceGuidanceEnabledByDefault: _voiceGuidanceEnabled,
      defaultLanguage: _selectedLanguage,
    );
  }

  Future<void> _checkForMedicalUpdate(
    MedicalDatabaseManager databaseManager,
  ) async {
    setState(() {
      _isCheckingForUpdate = true;
      _updateStatusMessageAr = null;
    });

    final newVersion = await databaseManager.checkForNewerVersion();

    if (!mounted) return;
    setState(() {
      _isCheckingForUpdate = false;
      _updateStatusMessageAr = newVersion != null
          ? 'يتوفر إصدار جديد ($newVersion) لقاعدة البيانات الطبية.'
          : 'قاعدة بياناتك الطبية محدَّثة بالفعل.';
    });
  }

  Future<void> _downloadMedicalUpdate(
    MedicalDatabaseManager databaseManager,
  ) async {
    setState(() {
      _isDownloadingUpdate = true;
      _updateStatusMessageAr = null;
    });

    final result = await const SearchRefreshEngine().refresh(
      knowledge: context.read<LocalKnowledge>(),
      lasting: context.read<LastingSearchIndex>(),
      database: databaseManager,
    );

    if (!mounted) return;
    setState(() {
      _isDownloadingUpdate = false;
      _updateStatusMessageAr = result.messageAr;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.messageAr),
        backgroundColor: result.remoteOk ? null : Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final activeLifexId = _activeLifexId(context);
    final activeProfile =
        Provider.of<ActiveProfileController>(context).activeProfile;
    final billingExempt = activeProfile != null &&
        const BillingExemptionPolicy().evaluate(activeProfile).isExempt;
    final hasAdminRole = activeLifexId != null &&
        GlobalAdminManager.instance.roleOf(activeLifexId) !=
            GlobalAdminRole.none;
    final adminAccess = activeLifexId != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(activeLifexId);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('الوضع الليلي'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() => _darkModeEnabled = value);
              _persist();
            },
          ),
          SwitchListTile(
            title: const Text('الإرشاد الصوتي'),
            subtitle: const Text('قراءة التنبيهات صوتياً تلقائياً'),
            value: _voiceGuidanceEnabled,
            onChanged: (value) {
              setState(() => _voiceGuidanceEnabled = value);
              _persist();
            },
          ),
          Semantics(
            label: 'اللغة، القيمة الحالية: '
                '${_selectedLanguage == AppLanguage.arabic ? "العربية" : "الإنجليزية"}',
            hint: 'اضغط لاختيار لغة مختلفة',
            child: ListTile(
              title: const Text('اللغة'),
              trailing: ExcludeSemantics(
                child: DropdownButton<AppLanguage>(
                  value: _selectedLanguage,
                  items: const [
                    DropdownMenuItem(
                      value: AppLanguage.arabic,
                      child: Text('العربية'),
                    ),
                    DropdownMenuItem(
                      value: AppLanguage.english,
                      child: Text('English'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedLanguage = value);
                    _persist();
                  },
                ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Manage the thumbnail'),
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
            title: const Text('عدسة الشرائح المتراكبة'),
            subtitle: const Text('تكبير جلدي وعدستان. بلا تشخيص وبلا دمج وهمي'),
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
                title: const Text('استقبال طلبات التبرع بالدم'),
                subtitle: const Text(
                  'التبرع مجاني. يمكنك إيقاف الإشعارات في أي وقت.',
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
              final allowed = const SessionAccessPolicy().canOpenUnit(
                'box',
                phase: trial.phase(
                  feeExempt: billingExempt,
                  adminAccess: adminAccess,
                ),
                feeExempt: billingExempt,
                adminAccess: adminAccess,
              );
              if (!allowed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      trial.statusLineAr(feeExempt: billingExempt),
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
                    feeExempt: billingExempt,
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
            subtitle:
                const Text('إشعار دائم بموافقة. بلا تصوير خفي وبلا حفظ صور'),
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
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('لوحة تحكم الأدمن'),
              subtitle: const Text('إدارة الأدوار ومفاتيح الأحداث الدقيقة'),
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
          ],
          const Divider(),
          _buildMedicalUpdateSection(context),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('حول التطبيق'),
            subtitle: const Text('Lifex-AI'),
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
                  Text(
                    '${AppConstants.academyNameAr}\n${AppConstants.ownerEmail}\n${AppConstants.officialContactEmail}\n${AppConstants.ownerPhoneNumber}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// قسم "تحديث وتوسيع المحتوى الطبي" — يسمح للمستخدم بالتحقق من وجود
  /// إصدار أحدث لقاعدة البيانات الطبية وتحميله بأمان، مع إبقاء النسخة
  /// الحالية تعمل بلا انقطاع في حال فشل أو تأجيل التحديث.
  Widget _buildMedicalUpdateSection(BuildContext context) {
    final databaseManager = Provider.of<MedicalDatabaseManager>(
      context,
      listen: false,
    );

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
                    : () => _checkForMedicalUpdate(databaseManager),
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
                    : () => _downloadMedicalUpdate(databaseManager),
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
