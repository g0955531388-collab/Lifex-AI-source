/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: identity_workspace_screen.dart
/// الهوية الحقيقية والمستعارة ومن التكوين.
/// =============================================================
library lifex_ai.screens.identity_workspace_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
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
    final profile = controller.activeProfile;
    final identity = profile == null
        ? null
        : HealthIdentityManager.instance.getByProfileId(profile.profileId);
    final hasAdminAccess = identity != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasAdminAccess
              ? 'حُفظت الهوية وتم تفعيل وصول المالك/الأدمن الكامل.'
              : 'حُفظت الهوية على هذا الجهاز. لم تتطابق بيانات الاتصال مع بيانات المالك المسجّلة.',
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
          appBar: AppBar(title: const Text('الهوية من الصفر')),
          body: profile == null
              ? const Center(child: Text('لا يوجد ملف صحي نشط.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const HonestyBanner(
                      messageAr:
                          'الهوية الحقيقية للجهات الصحية المخوّلة فقط. الهوية المستعارة للمجتمع والتعليم. التحقق الوثائقي يحتاج خادماً.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
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
                      child: const Text('Manage the thumbnail'),
                    ),
                    ListTile(
                      title: const Text('الاسم الحقيقي'),
                      subtitle: Text(profile.fullName),
                    ),
                    ListTile(
                      title: const Text('Lifex-Health ID'),
                      subtitle: Text(identity?.lifexId ?? 'يُنشأ مع الملف'),
                    ),
                    ListTile(
                      title: const Text('مستوى التحقق'),
                      subtitle: Text(
                          '${identity?.verificationLevel.name ?? 'unverified'} — التحقق الوثائقي ليس محلياً'),
                    ),
                    const SizedBox(height: 8),
                    Text('الهوية الحقيقية للجهات المخوّلة',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                      ),
                    ),
                    TextField(
                      controller: _nationalId,
                      decoration: const InputDecoration(
                        labelText: 'الرقم الوطني الحقيقي (اختياري)',
                      ),
                    ),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                    ),
                    TextField(
                      controller: _nationality,
                      decoration: const InputDecoration(
                        labelText: 'الجنسية (اختياري)',
                      ),
                    ),
                    TextField(
                      controller: _residence,
                      decoration: const InputDecoration(
                        labelText: 'مكان الإقامة (اختياري)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('الهوية المستعارة للمجتمع والتعليم',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                      controller: _alias,
                      decoration: const InputDecoration(
                        labelText: 'الهوية المستعارة',
                        hintText: 'مثال: مريض الأمل',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('في الصفحات العامة استخدم المستعار'),
                      subtitle: const Text(
                          'الطبيب والمستشفى والإسعاف يرون الاسم الحقيقي حسب صلاحياتك'),
                      value: _publicAliasMode,
                      onChanged: (value) =>
                          setState(() => _publicAliasMode = value),
                    ),
                    const SizedBox(height: 12),
                    Text('من التكوين',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                      controller: _origin,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'حمل أو ولادة أو بداية الملف',
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
                      child: const Text('حفظ الهوية'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('الدخول بحساب لايفكس في موقع آخر'),
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
                        title: const Text('معلومات الطوارئ'),
                        subtitle: const Text('جهات الثقة على هذا الجهاز'),
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
                        title: const Text('أفراد العائلة'),
                        subtitle:
                            const Text('ملفات مستقلة. الإشعارات باسم كل فرد'),
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
