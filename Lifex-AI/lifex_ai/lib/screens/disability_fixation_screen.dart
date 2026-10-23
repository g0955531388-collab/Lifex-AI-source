/// =============================================================
/// Lifex-AI — وحدة المعاقين
/// التثبيت ببطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه.
/// التصريح والنسبة ليسا تثبيتاً. ليست مطابقة حكومية عبر شبكة.
/// =============================================================
library lifex_ai.screens.disability_fixation_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/profile/active_profile_controller.dart';
import '../features/profile/determination_credential_policy.dart';
import '../widgets/accessible_widgets.dart';

class DisabilityFixationScreen extends StatefulWidget {
  const DisabilityFixationScreen({super.key});

  @override
  State<DisabilityFixationScreen> createState() =>
      _DisabilityFixationScreenState();
}

class _DisabilityFixationScreenState extends State<DisabilityFixationScreen> {
  final _policy = const DeterminationCredentialPolicy();
  late final TextEditingController _accountCountry;
  late final TextEditingController _cardCountry;
  late final TextEditingController _cardRef;
  DeterminationCardKind _kind = DeterminationCardKind.disabilityCard;
  String _status = '';

  @override
  void initState() {
    super.initState();
    final profile =
        context.read<ActiveProfileController>().activeProfile;
    _accountCountry = TextEditingController(text: profile?.accountCountry ?? '');
    _cardCountry = TextEditingController(
      text: profile?.determinationCardCountry ?? '',
    );
    _cardRef = TextEditingController(text: profile?.determinationCardRef ?? '');
    _kind = _policy.parseKind(profile?.determinationCardKind) ??
        DeterminationCardKind.disabilityCard;
    if (_kind == DeterminationCardKind.nationalId) {
      _kind = DeterminationCardKind.disabilityCard;
    }
    _status = profile == null
        ? 'لا يوجد ملف صحي نشط.'
        : _policy.evaluate(profile).messageAr;
  }

  @override
  void dispose() {
    _accountCountry.dispose();
    _cardCountry.dispose();
    _cardRef.dispose();
    super.dispose();
  }

  void _save() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) {
      setState(() => _status = 'لا يوجد ملف صحي نشط.');
      return;
    }
    profile.accountCountry = _accountCountry.text.trim();
    profile.isPersonOfDetermination = true;
    profile.determinationCardKind = _kind.name;
    profile.determinationCardCountry = _cardCountry.text.trim().isEmpty
        ? profile.accountCountry
        : _cardCountry.text.trim();
    profile.determinationCardRef = _cardRef.text.trim();
    controller.saveActiveProfileChanges();
    final check = _policy.evaluate(profile);
    setState(() => _status = check.messageAr);
    announceForScreenReader(context, check.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    final kinds = [
      DeterminationCardKind.disabilityCard,
      DeterminationCardKind.chronicIllnessCard,
    ];
    return ScreenArrival(
      message:
          'وحدة المعاقين. التثبيت ببطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه.',
      child: Scaffold(
        appBar: AppBar(title: const Text('تثبيت وحدة المعاقين')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'المعاق ومريض المرض المستعصي يُثبَّتان هنا. البطاقة من البلد المسجّل فيه صاحب الحساب.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountCountry,
              decoration: const InputDecoration(
                labelText: 'البلد المسجّل فيه صاحب الحساب',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeterminationCardKind>(
              value: _kind,
              decoration: const InputDecoration(
                labelText: 'نوع البطاقة',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final kind in kinds)
                  DropdownMenuItem(value: kind, child: Text(kind.labelAr)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardCountry,
              decoration: const InputDecoration(
                labelText: 'بلد إصدار البطاقة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardRef,
              decoration: const InputDecoration(
                labelText: 'رقم أو مرجع البطاقة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('تثبيت'),
              ),
            ),
            const SizedBox(height: 16),
            LiveAnnouncingText(
              message: _status,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
