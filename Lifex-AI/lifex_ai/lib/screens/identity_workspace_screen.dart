/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: identity_workspace_screen.dart
/// الهوية الحقيقية والمستعارة ومن التكوين.
/// =============================================================
library lifex_ai.screens.identity_workspace_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
import '../core/app_config.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/network_box/unit_branch_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_thumbnail.dart';
import '../widgets/voice_fill_button.dart';
import 'partner_sign_in_screen.dart';
import 'thumbnail_manage_screen.dart';
import 'unit_branch_navigator.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class IdentityWorkspaceScreen extends StatefulWidget {
  const IdentityWorkspaceScreen({super.key});

  @override
  State<IdentityWorkspaceScreen> createState() =>
      _IdentityWorkspaceScreenState();
}

class _IdentityWorkspaceScreenState extends State<IdentityWorkspaceScreen> {
  late final TextEditingController _alias;
  late final TextEditingController _origin;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _nationalId;
  late final TextEditingController _nationality;
  late final TextEditingController _residence;
  bool _seeded = false;
  bool _publicAliasMode = true;

  @override
  void initState() {
    super.initState();
    _alias = TextEditingController();
    _origin = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _nationalId = TextEditingController();
    _nationality = TextEditingController();
    _residence = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final store = _store();
    _alias.text = store?.stringField(BoxKeys.aliasName) ?? '';
    _origin.text = store?.stringField(BoxKeys.lifeOriginNotes) ?? '';
    _phone.text = store?.stringField(BoxKeys.accountPhone) ?? '';
    _email.text = store?.stringField(BoxKeys.accountEmail) ?? '';
    _nationalId.text = store?.stringField(BoxKeys.ownerNationalId) ?? '';
    _nationality.text = store?.stringField(BoxKeys.nationality) ?? '';
    _residence.text = store?.stringField(BoxKeys.residencePlace) ?? '';
    _publicAliasMode = store?.stringField(BoxKeys.publicIdentityMode) != 'real';
    _seeded = true;
  }

  ProfileBoxStore? _store() {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return null;
    return ProfileBoxStore(profile);
  }

  @override
  void dispose() {
    _alias.dispose();
    _origin.dispose();
    _phone.dispose();
    _email.dispose();
    _nationalId.dispose();
    _nationality.dispose();
    _residence.dispose();
    super.dispose();
  }

  void _save() {
    final controller = context.read<ActiveProfileController>();
    final store = _store();
    if (store == null) return;
    store.setString(BoxKeys.aliasName, _alias.text.trim());
    store.setString(BoxKeys.lifeOriginNotes, _origin.text.trim());
    store.setString(BoxKeys.accountPhone, _phone.text.trim());
    store.setString(BoxKeys.accountEmail, _email.text.trim());
    store.setString(BoxKeys.ownerNationalId, _nationalId.text.trim());
    store.setString(BoxKeys.nationality, _nationality.text.trim());
    store.setString(BoxKeys.residencePlace, _residence.text.trim());
    store.setString(
      BoxKeys.publicIdentityMode,
      _publicAliasMode ? 'alias' : 'real',
    );
    controller.updateAccountIdentity(
      email: _email.text.trim(),
      phoneNumber: _phone.text.trim(),
    );
    final lifexId = controller.engine.activeProfile == null
        ? null
        : HealthIdentityManager.instance
            .getByProfileId(controller.engine.activeProfile!.profileId)
            ?.lifexId;
    final opened =
        lifexId != null && GlobalAdminManager.instance.isOwner(lifexId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LifexText(
          opened
              ? 'حُفظت وسيلة الاتصال. دور المالك التشغيلي مفتوح لهذه الهوية. '
                  'الصلاحية للصيانة وتعيين الطاقم، وليست فتحاً لملفات المرضى.'
              : 'حُفظت وسيلة الاتصال. لم تطابق بريد المالك أو هاتفه تطابقاً كاملاً، '
                  'فبقي الدور مغلقاً.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        final identity = profile == null
            ? null
            : HealthIdentityManager.instance.getByProfileId(profile.profileId);
        return Scaffold(
          appBar: AppBar(title: const LifexText('الهوية من الصفر')),
          body: profile == null
              ? const Center(child: LifexText('لا يوجد ملف صحي نشط.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const HonestyBanner(
                      messageAr:
                          'الهوية الحقيقية للجهات الصحية المخوّلة فقط. الهوية المستعارة للمجتمع والتعليم. التحقق الوثائقي يحتاج خادماً.',
                    ),
                    const SizedBox(height: 8),
                    const LifexText(
                      'مالك النظام: أدخل البريد الإلكتروني أو الهاتف المسجّل للمالك ثم احفظ. عند المطابقة تُفعّل صلاحيات المالك فوراً على هذا الجهاز.',
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: LifexThumbnail(
                        localPath:
                            _store()?.stringField(BoxKeys.profileThumbnailPath),
                        size: 96,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThumbnailManageScreen(),
                        ),
                      ),
                      child: LifexText(lifexUi('إدارة الصورة المصغّرة', 'Profile thumbnail')),
                    ),
                    ListTile(
                      title: const LifexText('الاسم الحقيقي'),
                      subtitle: LifexText(profile.fullName),
                    ),
                    ListTile(
                      title: const LifexText('Lifex-Health ID'),
                      subtitle: LifexText(identity?.lifexId ?? 'يُنشأ مع الملف'),
                    ),
                    ListTile(
                      title: const LifexText('مستوى التحقق'),
                      subtitle: LifexText(
                          '${identity?.verificationLevel.name ?? 'unverified'} — التحقق الوثائقي ليس محلياً'),
                    ),
                    const SizedBox(height: 8),
                    LifexText('الهوية الحقيقية للجهات المخوّلة',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: tr('رقم الهاتف'),
                      ),
                    ),
                    TextField(
                      controller: _nationalId,
                      decoration: InputDecoration(
                        labelText: tr('الرقم الوطني الحقيقي (اختياري)'),
                      ),
                    ),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: tr('البريد الإلكتروني'),
                      ),
                    ),
                    TextField(
                      controller: _nationality,
                      decoration: InputDecoration(
                        labelText: tr('الجنسية (اختياري)'),
                      ),
                    ),
                    TextField(
                      controller: _residence,
                      decoration: InputDecoration(
                        labelText: tr('مكان الإقامة (اختياري)'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LifexText('الهوية المستعارة للمجتمع والتعليم',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                      controller: _alias,
                      decoration: InputDecoration(
                        labelText: tr('الهوية المستعارة'),
                        hintText: tr('مثال: مريض الأمل'),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const LifexText('في الصفحات العامة استخدم المستعار'),
                      subtitle: const LifexText(
                          'الطبيب والمستشفى والإسعاف يرون الاسم الحقيقي حسب صلاحياتك'),
                      value: _publicAliasMode,
                      onChanged: (value) =>
                          setState(() => _publicAliasMode = value),
                    ),
                    const SizedBox(height: 12),
                    LifexText('من التكوين',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                      controller: _origin,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: tr('حمل أو ولادة أو بداية الملف'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: VoiceFillButton(
                        onText: (text) {
                          _origin.text = _origin.text.isEmpty
                              ? text
                              : '${_origin.text} $text';
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _save,
                      child: const LifexText('حفظ الهوية'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.login_outlined),
                      label: const LifexText('الدخول بحساب لايفكس في موقع آخر'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PartnerSignInScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.emergency_outlined),
                        title: const LifexText('معلومات الطوارئ'),
                        subtitle: const LifexText('جهات الثقة على هذا الجهاز'),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvEmergency',
                          ),
                          profileId: profile.profileId,
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.family_restroom_outlined),
                        title: const LifexText('أفراد العائلة'),
                        subtitle: const LifexText(
                            'ملفات مستقلة. الإشعارات باسم كل فرد'),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvFamily',
                          ),
                          profileId: profile.profileId,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
