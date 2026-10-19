/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: profile_setup_screen.dart
/// المسار: lib/screens/profile_setup_screen.dart
/// الوصف: شاشة الإعداد الأولي — أول شيء يراه المستخدم بعد الشاشة
/// الافتتاحية إذا لم يكن لديه أي ملف صحي بعد. تنشئ الملف الأول فعلياً
/// عبر ActiveProfileController، بدلاً من ترك التطبيق يعمل بمعرّف وهمي
/// ثابت كما كان الحال قبل إضافة هذه الشاشة.
/// =============================================================
library lifex_ai.screens.profile_setup_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../features/accessibility/access_mode_preference.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import '../widgets/accessible_widgets.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountCountryController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _dateOfBirth;
  BiologicalSex _sex = BiologicalSex.unspecified;
  bool _isPersonOfDetermination = false;
  bool _isBlind = false;
  bool _accessEnabled = false;
  bool _accessUserChose = false;
  bool _acceptsBloodDonationAlerts = false;
  String? _errorMessageAr;

  bool get _english =>
      AppConfig.instance.defaultLanguage == AppLanguage.english;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccessMode());
  }

  Future<void> _loadAccessMode() async {
    final prefs = await SharedPreferences.getInstance();
    final memory = AccessModeMemory()..readPrefs(prefs);
    final decision = memory.load(profileNeedsAccess: _isBlind);
    if (!mounted) return;
    setState(() {
      _accessEnabled = decision.enabled;
      _accessUserChose = decision.userChose;
    });
  }

  Future<void> _persistAccessMode() async {
    final memory = AccessModeMemory();
    if (_accessUserChose) {
      memory.saveUserChoice(_accessEnabled);
    } else {
      final decision = AccessModePreference.decide(
        profileNeedsAccess: AccessModePreference.profileNeedsAccess(
          isBlind: _isBlind,
        ),
        storedEnabled: _accessEnabled,
        userChose: false,
      );
      memory.enabled = decision.enabled;
      memory.userChose = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await memory.writePrefs(prefs);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _accountCountryController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
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
    final ageYears = int.parse(_ageController.text.trim());
    final now = DateTime.now();

    final controller = Provider.of<ActiveProfileController>(
      context,
      listen: false,
    );

    final profile = HealthProfile(
      // معرّف بسيط ومحلي كافٍ لهذه المرحلة؛ يُستبدل لاحقاً بمعرّف صادر
      // من خادم Lifex-AI الخلفي عند ربط الحساب بمصادقة حقيقية.
      profileId: 'local-${now.millisecondsSinceEpoch}',
      fullName: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth ?? DateTime(now.year - ageYears, now.month, now.day),
      biologicalSex: _sex,
      isPersonOfDetermination: _isPersonOfDetermination,
      accountCountry: _accountCountryController.text.trim(),
      isBlind: _isBlind,
      acceptsBloodDonationAlerts: _acceptsBloodDonationAlerts,
    );

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final result = controller.createInitialProfile(
      profile,
      email: email.isEmpty ? null : email,
      phoneNumber: phone.isEmpty ? null : phone,
    );

    if (!result.success) {
      setState(() {
        _errorMessageAr = result.errorMessage ?? 'تعذّر إنشاء الملف الصحي.';
      });
      return;
    }

    await _persistAccessMode();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('إنشاء ملفك الصحي')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً بك في Lifex-AI. لنبدأ بإنشاء ملفك الصحي '
                    'الأساسي. يمكنك إضافة أفراد عائلتك لاحقاً من الإعدادات.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
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
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'العمر بعدد السنوات',
                      border: OutlineInputBorder(),
                      helperText: 'اكتب العمر رقماً، مثل 34',
                    ),
                    validator: (value) {
                      final years = int.tryParse(value?.trim() ?? '');
                      if (years == null) {
                        return 'يُرجى كتابة العمر بعدد السنوات.';
                      }
                      if (years < 0 || years > 130) {
                        return 'اكتب عمراً بين 0 و 130 سنة.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: _dateOfBirth == null
                        ? 'تاريخ الميلاد اختياري'
                        : 'تاريخ الميلاد ${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                    hint: 'يفتح اختيار التاريخ، ويمكن تركه فارغاً',
                    onTap: _pickDateOfBirth,
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: _pickDateOfBirth,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الميلاد (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _dateOfBirth == null
                                ? 'يمكن تركه فارغاً'
                                : '${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                          ),
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('أنا من ذوي الهمم / الإعاقة'),
                    subtitle: const Text(
                      'التثبيت لاحقاً في وحدة المعاقين ببطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه.',
                    ),
                    value: _isPersonOfDetermination,
                    onChanged: (value) =>
                        setState(() => _isPersonOfDetermination = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('مكفوف / ضعف بصر شديد في هذه الفئة'),
                    subtitle: const Text(
                      'الإعفاء يتبع بطاقة الإعاقة في وحدة المعاقين، من البلد المسجّل فيه.',
                    ),
                    value: _isBlind,
                    onChanged: (value) => setState(() {
                      _isBlind = value;
                      if (value && !_accessUserChose) _accessEnabled = true;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AccessModePreference.title(english: _english)),
                    subtitle: Text(
                      AccessModePreference.subtitle(english: _english),
                    ),
                    value: _accessEnabled,
                    onChanged: (value) => setState(() {
                      _accessEnabled = value;
                      _accessUserChose = true;
                    }),
                  ),
                  TextFormField(
                    controller: _accountCountryController,
                    decoration: const InputDecoration(
                      labelText: 'بلد صاحب الحساب',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('استقبال طلبات التبرع بالدم'),
                    subtitle: const Text(
                      'إن أوقفت هذا الخيار لن يصلك فلاش أو تنبيه تبرع.',
                    ),
                    value: _acceptsBloodDonationAlerts,
                    onChanged: (value) =>
                        setState(() => _acceptsBloodDonationAlerts = value),
                  ),
                  if (_errorMessageAr != null) ...[
                    const SizedBox(height: 12),
                    LiveAnnouncingText(
                      message: _errorMessageAr!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      button: true,
                      label: 'إنشاء الملف والمتابعة',
                      hint: 'يحفظ الملف وينتقل للرئيسية',
                      onTap: _submit,
                      child: ExcludeSemantics(
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('إنشاء الملف والمتابعة'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
