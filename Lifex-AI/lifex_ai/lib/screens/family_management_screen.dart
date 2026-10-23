/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: family_management_screen.dart
/// المسار: lib/screens/family_management_screen.dart
/// الوصف: شاشة إدارة أفراد العائلة — تبديل الملف النشط وإضافة فرد جديد
/// عبر ActiveProfileController.addFamilyMember، تنفيذ بند TODO #10 في
/// التقرير المرجعي الموحّد. المنطق كان جاهزاً؛ هذه الواجهة تربطه.
/// =============================================================
library lifex_ai.screens.family_management_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/family/genetics_signal_engine.dart';
import '../features/network_box/unit_branch_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import '../features/profile/multi_profile_engine.dart';
import '../services/cloud/cloud_sync_manager.dart';
import 'unit_branch_navigator.dart';
import 'marriage_request_screen.dart';

class FamilyManagementScreen extends StatelessWidget {
  const FamilyManagementScreen({super.key});

  static const Map<ProfileRole, String> _roleLabelsAr = {
    ProfileRole.primaryOwner: 'صاحب الحساب',
    ProfileRole.spouse: 'زوج / زوجة',
    ProfileRole.child: 'ابن / ابنة',
    ProfileRole.parent: 'والد / والدة',
    ProfileRole.otherRelative: 'قريب آخر',
    ProfileRole.dependent: 'تحت الرعاية',
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final links = controller.familyLinks;

        return Scaffold(
          appBar: AppBar(title: const Text('إدارة أفراد العائلة')),
          floatingActionButton: controller.remainingFamilySlots <= 0
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openAddMemberSheet(context),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('إضافة فرد'),
                ),
          body: links.isEmpty
              ? const Center(
                  child: Text('لا يوجد أي ملف صحي في هذا الحساب بعد.'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    Text(
                      'المقاعد المتبقية: ${controller.remainingFamilySlots}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_tree_outlined),
                        title: const Text('التاريخ العائلي'),
                        subtitle: const Text(
                            'ملاحظات وراثية على هذا الملف فقط. لا تُفتح ملفات الآخرين'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvFamilyHistory',
                          ),
                          profileId: controller.activeProfileId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_outlined),
                        title: const Text('رواق المعرفة'),
                        subtitle: const Text(
                            'مكتبة الأسرة واليافعين، ورفّ تنزيل إلى الجهاز'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvArcade',
                          ),
                          profileId: controller.activeProfileId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('كتاب حقوق الطفل'),
                        subtitle: const Text('قراءة محلية. ليس قانون دولة'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvChildRights',
                          ),
                          profileId: controller.activeProfileId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.favorite_outline),
                        title: const Text('مَرآةُ الاختيار'),
                        subtitle: const Text(
                          'نضج الشراكة. لغة الجهاز أو التطبيق تلقائياً',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvChoiceMirror',
                          ),
                          profileId: controller.activeProfileId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_stories_outlined),
                        title: const Text('دليل اليافعين'),
                        subtitle: const Text('توعوي. ليس علاجاً نفسياً'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          UnitBranchCatalog.healthCv.firstWhere(
                            (branch) => branch.id == 'cvYouthGuide',
                          ),
                          profileId: controller.activeProfileId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.favorite_outline),
                        title: const Text('طلب زواج وتوافق صحي'),
                        subtitle: const Text(
                            'طلب لفلانة على الجهاز. الحساب الصحي بعد موافقتها فقط'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MarriageRequestScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...GeneticsSignalEngine()
                        .estimate(controller.allProfiles)
                        .map((signal) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.family_restroom_outlined),
                                title: Text(signal.messageAr),
                              ),
                            )),
                    const SizedBox(height: 8),
                    for (final link in links)
                      _FamilyMemberTile(
                        link: link,
                        profile: controller.profileById(link.profileId),
                        isActive: link.profileId == controller.activeProfileId,
                        roleLabelAr:
                            _roleLabelsAr[link.role] ?? link.role.name,
                        onSelect: () {
                          final switched = controller.switchTo(link.profileId);
                          if (!switched) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'أصبح الملف النشط: '
                                '${controller.activeProfile?.fullName ?? link.profileId}',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openAddMemberSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddFamilyMemberSheet(),
    );
  }
}

class _FamilyMemberTile extends StatelessWidget {
  const _FamilyMemberTile({
    required this.link,
    required this.profile,
    required this.isActive,
    required this.roleLabelAr,
    required this.onSelect,
  });

  final FamilyProfileLink link;
  final HealthProfile? profile;
  final bool isActive;
  final String roleLabelAr;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName ?? link.profileId;
    final ageLabel = profile == null ? '' : ' — ${profile!.ageInYears} سنة';

    return Card(
      child: ListTile(
        leading: Icon(
          isActive ? Icons.person : Icons.person_outline,
          color: isActive ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(name),
        subtitle: Text('$roleLabelAr$ageLabel'),
        trailing: isActive
            ? const Chip(label: Text('نشط'))
            : TextButton(
                onPressed: onSelect,
                child: const Text('تبديل'),
              ),
        selected: isActive,
        onTap: isActive ? null : onSelect,
      ),
    );
  }
}

class _AddFamilyMemberSheet extends StatefulWidget {
  const _AddFamilyMemberSheet();

  @override
  State<_AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

class _AddFamilyMemberSheetState extends State<_AddFamilyMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  BiologicalSex _sex = BiologicalSex.unspecified;
  ProfileRole _role = ProfileRole.child;
  String? _errorMessageAr;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessageAr = null);
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _errorMessageAr = 'يُرجى تحديد تاريخ الميلاد.');
      return;
    }

    final controller = Provider.of<ActiveProfileController>(
      context,
      listen: false,
    );
    final fullName = _nameController.text.trim();
    final sync = Provider.of<CloudSyncManager>(context, listen: false);
    final serverProfileId =
        await sync.requestServerProfileId(displayName: fullName);
    if (!mounted) return;

    final profile = HealthProfile(
      profileId: serverProfileId ??
          'local-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      dateOfBirth: _dateOfBirth!,
      biologicalSex: _sex,
    );

    final result = controller.addFamilyMember(profile, role: _role);
    if (result.success && sync.isEndpointConfigured) {
      sync.enqueue(
        entityType: SyncEntityType.healthProfile,
        entityId: profile.profileId,
        payload: {
          'profileId': profile.profileId,
          'fullName': profile.fullName,
        },
      );
      await sync.syncPendingOperations();
    }
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _errorMessageAr = result.errorMessage ?? 'تعذّر إضافة فرد العائلة.';
      });
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت إضافة ${profile.fullName}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إضافة فرد من العائلة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يُرجى إدخال الاسم.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الميلاد',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? 'اضغط لاختيار التاريخ'
                        : '${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProfileRole>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'صلة القرابة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ProfileRole.spouse,
                    child: Text('زوج / زوجة'),
                  ),
                  DropdownMenuItem(
                    value: ProfileRole.child,
                    child: Text('ابن / ابنة'),
                  ),
                  DropdownMenuItem(
                    value: ProfileRole.parent,
                    child: Text('والد / والدة'),
                  ),
                  DropdownMenuItem(
                    value: ProfileRole.otherRelative,
                    child: Text('قريب آخر'),
                  ),
                  DropdownMenuItem(
                    value: ProfileRole.dependent,
                    child: Text('تحت الرعاية'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BiologicalSex>(
                value: _sex,
                decoration: const InputDecoration(
                  labelText: 'الجنس البيولوجي (لأغراض طبية بحتة)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: BiologicalSex.unspecified,
                    child: Text('تفضّل عدم التحديد'),
                  ),
                  DropdownMenuItem(
                    value: BiologicalSex.male,
                    child: Text('ذكر'),
                  ),
                  DropdownMenuItem(
                    value: BiologicalSex.female,
                    child: Text('أنثى'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sex = value);
                },
              ),
              if (_errorMessageAr != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessageAr!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('حفظ الفرد'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
