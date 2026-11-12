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
import '../features/accessibility/boot_access_preference.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/hardware_cue_bridge.dart';
import '../features/profile/health_profile.dart';
import '../features/profile/inventor_owner_profile.dart';
import '../services/cloud/cloud_sync_manager.dart';
import '../widgets/accessible_widgets.dart';
import 'home_screen.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

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
  bool _bootAccess = false;
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
    final boot = prefs.getBool(BootAccessPreference.key) ?? false;
    if (!mounted) return;
    setState(() {
      _accessEnabled = decision.enabled;
      _accessUserChose = decision.userChose;
      _bootAccess = boot;
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
    await prefs.setBool(BootAccessPreference.key, _bootAccess);
    await HardwareCueBridge.instance.refreshBlindArm();
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

  Future<void> _createInventorOwnerFile() async {
    setState(() => _errorMessageAr = null);
    final draft = InventorOwnerProfileDraft.official();
    final controller = Provider.of<ActiveProfileController>(
      context,
      listen: false,
    );
    final result = controller.createInitialProfile(
      draft.profile,
      email: draft.email,
      phoneNumber: draft.phone,
    );
    if (!result.success) {
      setState(() {
        _errorMessageAr = result.errorMessage ??
            lifexUi(
              'تعذّر إنشاء ملف المخترع.',
              'The inventor profile could not be created.',
            );
      });
      return;
    }
    await _persistAccessMode();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessageAr = null);

    if (!_formKey.currentState!.validate()) return;
    final ageYears = int.parse(_ageController.text.trim());

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
      statedAgeYears: ageYears,
      dateOfBirth: _dateOfBirth,
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
        _errorMessageAr = result.errorMessage ??
            lifexUi(
              'تعذّر إنشاء الملف الصحي.',
              'The health profile could not be created.',
            );
      });
      return;
    }

    if (sync.isEndpointConfigured) {
      sync.enqueue(
        entityType: SyncEntityType.healthProfile,
        entityId: profile.profileId,
        payload: {
          'profileId': profile.profileId,
          'fullName': profile.fullName,
        },
      );
      unawaited(sync.syncPendingOperations());
    }

    await _persistAccessMode();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudioThemeController.instance,
      builder: (context, _) {
        return ScreenArrival(
      message: BlindNavigationCopy.profileArrivalText,
      child: Scaffold(
        appBar: AppBar(
          title: LifexText(lifexUi('إنشاء ملفك الصحي', 'Create your health profile')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LifexText(
                    lifexUi(
                      'مرحباً بك في Lifex-AI. لنبدأ بإنشاء ملفك الصحي '
                          'الأساسي. يمكنك إضافة أفراد عائلتك لاحقاً من الإعدادات.',
                      'Welcome to Lifex-AI. Start by creating your basic health profile. You can add family members later from settings.',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _createInventorOwnerFile,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: LifexText(lifexUi(
                          'ملف شخص للمخترع والأدمن: غازي سليم بكفلاوي',
                          'A person file for the inventor and admin: غازي سليم بكفلاوي',
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LifexText(
                    lifexUi(
                      'يستخدم البريد والهاتف المعتمدين. لا يُكتب عمر ولا فصيلة دم. الاسم وحده لا يفتح الصلاحية.',
                      'Uses the approved email and phone. Age and blood type are not written. The name alone does not open access.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lifexUi('الاسم الكامل', 'Full name'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return lifexUi('يُرجى إدخال الاسم.', 'Enter the name.');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lifexUi('العمر بعدد السنوات', 'Age in years'),
                      border: const OutlineInputBorder(),
                      helperText: lifexUi(
                        'اكتب العمر رقماً، مثل 34',
                        'Write the age as a number, such as 34',
                      ),
                    ),
                    validator: (value) {
                      final years = int.tryParse(value?.trim() ?? '');
                      if (years == null) {
                        return lifexUi(
                          'يُرجى كتابة العمر بعدد السنوات.',
                          'Write the age as a number of years.',
                        );
                      }
                      if (years < 0 || years > 130) {
                        return lifexUi(
                          'اكتب عمراً بين 0 و 130 سنة.',
                          'Write an age from 0 to 130 years.',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: tr(_dateOfBirth == null
                        ? lifexUi('تاريخ الميلاد اختياري', 'Date of birth is optional')
                        : lifexUi(
                            'تاريخ الميلاد ${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                            'Date of birth ${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                          )),
                    hint: lifexUi(
                      'يفتح اختيار التاريخ، ويمكن تركه فارغاً',
                      'Opens the date picker, and it can be left empty',
                    ),
                    onTap: _pickDateOfBirth,
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: _pickDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: lifexUi(
                              'تاريخ الميلاد (اختياري)',
                              'Date of birth (optional)',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          child: LifexText(
                            _dateOfBirth == null
                                ? lifexUi('يمكن تركه فارغاً', 'It can be left empty')
                                : '${_dateOfBirth!.year}/${_dateOfBirth!.month}/${_dateOfBirth!.day}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BiologicalSex>(
                    value: _sex,
                    decoration: InputDecoration(
                      labelText: lifexUi(
                        'الجنس البيولوجي (لأغراض طبية بحتة)',
                        'Biological sex (for the medical record only)',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: BiologicalSex.unspecified,
                        child: LifexText(lifexUi('تفضّل عدم التحديد', 'Prefer not to say')),
                      ),
                      DropdownMenuItem(
                        value: BiologicalSex.male,
                        child: LifexText(lifexUi('ذكر', 'Male')),
                      ),
                      DropdownMenuItem(
                        value: BiologicalSex.female,
                        child: LifexText(lifexUi('أنثى', 'Female')),
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
                    decoration: InputDecoration(
                      labelText: lifexUi('البريد الإلكتروني (اختياري)', 'Email (optional)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lifexUi('رقم الهاتف (اختياري)', 'Phone (optional)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: LifexText(lifexUi(
                      'أنا من ذوي الهمم / الإعاقة',
                      'I am a person with a disability',
                    )),
                    subtitle: LifexText(lifexUi(
                      'التثبيت لاحقاً في وحدة المعاقين ببطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه.',
                      'Later fixation in the disability unit uses a disability card or a permanent-patient card from the registered country.',
                    )),
                    value: _isPersonOfDetermination,
                    onChanged: (value) =>
                        setState(() => _isPersonOfDetermination = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: LifexText(lifexUi(
                      'مكفوف / ضعف بصر شديد في هذه الفئة',
                      'Blind or severe low vision in this group',
                    )),
                    subtitle: LifexText(lifexUi(
                      'الإعفاء يتبع بطاقة الإعاقة في وحدة المعاقين، من البلد المسجّل فيه.',
                      'The exemption follows the disability card in the disability unit, from the registered country.',
                    )),
                    value: _isBlind,
                    onChanged: (value) => setState(() {
                      _isBlind = value;
                      if (value && !_accessUserChose) _accessEnabled = true;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: LifexText(AccessModePreference.title(english: _english)),
                    subtitle: LifexText(
                      AccessModePreference.subtitle(english: _english),
                    ),
                    value: _accessEnabled,
                    onChanged: (value) => setState(() {
                      _accessEnabled = value;
                      _accessUserChose = true;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: LifexText(_english
                        ? 'Resume accessibility after phone boot'
                        : 'استئناف وضع الوصول بعد إقلاع الهاتف'),
                    subtitle: LifexText(
                      BootAccessPreference.decide(
                        userEnabled: _bootAccess,
                        english: _english,
                      ).speech,
                    ),
                    value: _bootAccess,
                    onChanged: (value) => setState(() => _bootAccess = value),
                  ),
                  TextFormField(
                    controller: _accountCountryController,
                    decoration: InputDecoration(
                      labelText: lifexUi('بلد صاحب الحساب', 'Account holder country'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: LifexText(lifexUi(
                      'استقبال طلبات التبرع بالدم',
                      'Receive blood donation requests',
                    )),
                    subtitle: LifexText(lifexUi(
                      'إن أوقفت هذا الخيار لن يصلك فلاش أو تنبيه تبرع.',
                      'If you turn this off, a donation flash or alert will not reach you.',
                    )),
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
                      label: lifexUi('إنشاء الملف والمتابعة', 'Create the profile and continue'),
                      hint: lifexUi(
                        'يحفظ الملف وينتقل للرئيسية',
                        'Saves the profile and opens home',
                      ),
                      onTap: _submit,
                      child: ExcludeSemantics(
                        child: FilledButton(
                          onPressed: _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: LifexText(lifexUi(
                              'إنشاء الملف والمتابعة',
                              'Create the profile and continue',
                            )),
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
      ),
    );
      },
    );
  }
}
