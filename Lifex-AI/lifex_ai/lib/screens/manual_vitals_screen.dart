/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: manual_vitals_screen.dart
/// قياسات يدوية ونغمة نبض وملاحظة لون بول. بلا OCR وبلا قيم مخترعة.
/// =============================================================
library lifex_ai.screens.manual_vitals_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/license_manager.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/vitals/manual_vital_board.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';

class ManualVitalsScreen extends StatefulWidget {
  const ManualVitalsScreen({super.key});

  @override
  State<ManualVitalsScreen> createState() => _ManualVitalsScreenState();
}

class _ManualVitalsScreenState extends State<ManualVitalsScreen> {
  static const _policy = ManualVitalPolicy();
  static const _midi = MidiPulseCue();

  final _temp = TextEditingController();
  final _oxygen = TextEditingController();
  final _pulse = TextEditingController();
  final _bp = TextEditingController();
  final _foam = TextEditingController();
  final _clarity = TextEditingController();
  String _urine = UrineColorNote.none;
  String _status = 'أدخل أرقام جهازك. لن تُملأ قيم افتراضية.';

  @override
  void dispose() {
    _temp.dispose();
    _oxygen.dispose();
    _pulse.dispose();
    _bp.dispose();
    _foam.dispose();
    _clarity.dispose();
    super.dispose();
  }

  ManualVitalDraft _draft() {
    return ManualVitalDraft(
      tempC: double.tryParse(_temp.text.trim().replaceAll(',', '.')),
      oxygenPercent: int.tryParse(_oxygen.text.trim()),
      pulseBpm: int.tryParse(_pulse.text.trim()),
      bloodPressure: _bp.text.trim(),
      urineColorNote: _urine,
      urineFoamNote: _foam.text,
      urineClarityNote: _clarity.text,
    );
  }

  Future<void> _review({required bool save}) async {
    final draft = _draft();
    final scored = _policy.score(draft);
    var line = scored.messageAr;
    if (draft.pulseBpm != null && draft.pulseBpm! > 0) {
      line = '$line ${_midi.lineAr(draft.pulseBpm!)}';
    }
    line = LicenseManager.instance.appendAr(line);

    if (save && scored.completeEnough) {
      final profile =
          context.read<ActiveProfileController>().activeProfile;
      if (profile == null) {
        setState(() => _status = 'افتح ملفاً صحياً أولاً.');
        return;
      }
      ProfileBoxStore(profile).add(BoxKeys.biometrics, {
        'title': scored.statusAr,
        'detail': line,
        'source': 'يدوي على هذا الجهاز',
      });
      context.read<ActiveProfileController>().saveActiveProfileChanges();
      line = 'حُفظ في قياساتك على هذا الجهاز. $line';
    }

    setState(() => _status = line);
    await VoiceEngine.instance.speak(line);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('القياسات اليدوية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(messageAr: ManualVitalPolicy.refuseBitmapAnalysisAr),
          const SizedBox(height: 8),
          const HonestyBanner(messageAr: ManualVitalPolicy.neverInventAr),
          const SizedBox(height: 8),
          const HonestyBanner(messageAr: UrineColorNote.honestyAr),
          const SizedBox(height: 8),
          HonestyBanner.medical(),
          const SizedBox(height: 16),
          TextField(
            controller: _temp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الحرارة (°م) إن قستها',
            ),
          ),
          TextField(
            controller: _oxygen,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'الأكسجين (%) إن قسته',
            ),
          ),
          TextField(
            controller: _pulse,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'النبض (ضربة/دقيقة) إن قسته',
            ),
          ),
          TextField(
            controller: _bp,
            decoration: const InputDecoration(
              labelText: 'الضغط كما قرأته (مثل 120/80)',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _urine,
            decoration: const InputDecoration(labelText: 'ملاحظة لون البول'),
            items: [
              for (final option in UrineColorNote.options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _urine = value);
            },
          ),
          TextField(
            controller: _foam,
            decoration: const InputDecoration(
              labelText: 'ملاحظة الرغوة، إن كتبتها',
            ),
          ),
          TextField(
            controller: _clarity,
            decoration: const InputDecoration(
              labelText: 'ملاحظة الوضوح، إن كتبتها',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _review(save: false),
            icon: const Icon(Icons.rule),
            label: const Text('مراجعة الأرقام دون حفظ'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _review(save: true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ في القياسات اليدوية'),
          ),
          const SizedBox(height: 16),
          Text(_status),
        ],
      ),
    );
  }
}
