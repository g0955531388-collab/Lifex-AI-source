/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: privacy_settings_screen.dart
/// المسار: lib/screens/privacy_settings_screen.dart
/// الوصف: شاشة التحكم بمن يرى بيانات الملف الصحي النشط، مربوطة فعلياً
/// بـ ProfilePrivacyManager عبر ProfilePrivacyRegistry — تنفيذ بند
/// TODO #9 في التقرير المرجعي الموحّد.
/// =============================================================
library lifex_ai.screens.privacy_settings_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/profile/active_profile_controller.dart';
import '../features/profile/profile_privacy_manager.dart';
import '../widgets/lifex_text.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  int _dropdownResetToken = 0;
  static const Map<ViewerCategory, String> _categoryLabelsAr = {
    ViewerCategory.self: 'أنا (صاحب الملف)',
    ViewerCategory.family: 'العائلة',
    ViewerCategory.approvedDoctor: 'الطبيب المعتمد',
    ViewerCategory.hospital: 'المستشفى',
    ViewerCategory.pharmacy: 'الصيدلية',
    ViewerCategory.laboratory: 'المختبر',
    ViewerCategory.emergencyResponder: 'فرق الطوارئ',
    ViewerCategory.donor: 'المتبرعون',
    ViewerCategory.publicSearch: 'البحث العام على المنصة',
  };

  static const Map<DataVisibilityLevel, String> _levelLabelsAr = {
    DataVisibilityLevel.none: 'لا شيء',
    DataVisibilityLevel.aliasOnly: 'الاسم المستعار فقط',
    DataVisibilityLevel.basicInfo: 'معلومات عامة غير حساسة',
    DataVisibilityLevel.medicalSummary: 'ملخص طبي',
    DataVisibilityLevel.fullAccess: 'وصول كامل',
  };

  void _applyLevel(
    ProfilePrivacyManager manager,
    ViewerCategory category,
    DataVisibilityLevel level,
  ) {
    final accepted = manager.setVisibility(category, level);
    if (!accepted) {
      setState(() => _dropdownResetToken++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LifexText(
            'لا يمكن تخفيض صلاحية فرق الطوارئ عن الملخص الطبي، '
            'حمايةً لسلامتك.',
          ),
        ),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profileId =
        Provider.of<ActiveProfileController>(context).activeProfileId;

    if (profileId == null) {
      return Scaffold(
        appBar: AppBar(title: const LifexText('إعدادات الخصوصية')),
        body: const Center(
          child: LifexText('لا يوجد ملف صحي نشط لتعديل خصوصيته.'),
        ),
      );
    }

    final manager = ProfilePrivacyRegistry.instance.forProfile(profileId);
    final editableCategories = ViewerCategory.values
        .where((category) => category != ViewerCategory.self)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const LifexText('إعدادات الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: LifexText(
              'الوضع الافتراضي آمن: لا يرى أحد بياناتك الحساسة إلا بموافقة '
              'صريحة. فرق الطوارئ تحتفظ بملخص طبي أساسي لإنقاذ الحياة.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_person_outlined),
            title: LifexText(_categoryLabelsAr[ViewerCategory.self]!),
            subtitle: LifexText(_levelLabelsAr[DataVisibilityLevel.fullAccess]!),
          ),
          const Divider(),
          for (final category in editableCategories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LifexText(
                    _categoryLabelsAr[category]!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<DataVisibilityLevel>(
                    key: ValueKey(
                      '$_dropdownResetToken-${category.name}-${manager.visibilityFor(category).name}',
                    ),
                    value: manager.visibilityFor(category),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: DataVisibilityLevel.values
                        .map(
                          (level) => DropdownMenuItem(
                            value: level,
                            child: LifexText(_levelLabelsAr[level]!),
                          ),
                        )
                        .toList(),
                    onChanged: (level) {
                      if (level == null) return;
                      _applyLevel(manager, category, level);
                    },
                  ),
                  if (category == ViewerCategory.emergencyResponder)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: LifexText(
                        'لا يمكن تخفيضها عن الملخص الطبي',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
