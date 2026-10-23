/// =============================================================
/// Lifex-AI — رصد الأوبئة
/// بطاقة يملأها المستخدم. الخانة الفارغة تبقى فارغة.
/// =============================================================
library lifex_ai.screens.epidemic_surveillance_screen;

import 'package:flutter/material.dart';

import '../core/health_event_manager.dart';
import '../features/epidemic/epidemic_surveillance_engine.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/voice_or_type_field.dart';
import 'health_guidance_screen.dart';

class EpidemicSurveillanceScreen extends StatefulWidget {
  const EpidemicSurveillanceScreen({super.key, this.profileId});

  final String? profileId;

  @override
  State<EpidemicSurveillanceScreen> createState() =>
      _EpidemicSurveillanceScreenState();
}

class _EpidemicSurveillanceScreenState
    extends State<EpidemicSurveillanceScreen> {
  final _engine = const EpidemicAssessmentEngine();
  final _ledger = EpidemicAlertLedger();
  final _disease = TextEditingController();
  final _region = TextEditingController();
  final _population = TextEditingController();
  final _baseline = TextEditingController();
  final _cases = TextEditingController();
  final _source = TextEditingController();
  bool _definition = false;
  bool _delay = false;
  bool _official = false;
  EpidemicAssessment? _result;
  String _status = 'أدخل المرض والمنطقة وعدد الفترة. لن أملأ الخانات.';

  @override
  void dispose() {
    _disease.dispose();
    _region.dispose();
    _population.dispose();
    _baseline.dispose();
    _cases.dispose();
    _source.dispose();
    super.dispose();
  }

  int? _intOf(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  double? _doubleOf(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _assess() async {
    final cases = _intOf(_cases);
    if (_cases.text.trim().isNotEmpty && cases == null) {
      setState(() => _status = 'عدد الحالات ليس رقماً. لن أخمّن.');
      await VoiceEngine.instance.speak(_status);
      return;
    }
    final assessment = _engine.assess(
      EpidemicObservation(
        diseaseKey: _disease.text,
        regionKey: _region.text,
        population: _intOf(_population),
        baselineNewCases: _doubleOf(_baseline),
        caseDefinitionPresent: _definition,
        reportingDelayNoted: _delay,
        officialAuthorityConfirmed: _official,
        sourceLabel: _source.text,
        sourceUpdatedAt: null,
        periods: cases == null
            ? const []
            : [
                EpidemicPeriod(
                  periodKey: 'current',
                  newCases: cases,
                  reportedAt: DateTime.now(),
                ),
              ],
      ),
    );
    final notify = _ledger.shouldNotify(
      assessment: assessment,
      diseaseKey: _disease.text,
      regionKey: _region.text,
    );
    if (notify) {
      HealthEventManager.instance.emitQuick(
        HealthEventType.epidemicSignalUpdated,
        sourceModule: 'epidemic_surveillance',
        profileId: widget.profileId,
        data: {
          'level': assessment.level?.name,
          'officialDeclaration': assessment.officialDeclaration,
          'statementAr': assessment.statementAr,
        },
      );
    }
    final spoken = notify
        ? 'تغيّر مستوى الإشارة. ${assessment.statementAr}'
        : assessment.statementAr;
    setState(() {
      _result = assessment;
      _status = spoken;
    });
    await VoiceEngine.instance.speak(spoken);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return ScreenArrival(
      message: 'رصد الأوبئة. أدخل الأرقام. العدد وحده ليس إعلاناً.',
      child: Scaffold(
        appBar: AppBar(title: const Text('رصد الأوبئة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'المستوى إشارة للتحقيق. التأكيد الرسمي علم تضعه أنت من جهة مختصة، '
              'ولا يستنتجه النظام من العدد.',
            ),
            const SizedBox(height: 12),
            VoiceOrTypeField(controller: _disease, label: 'المرض'),
            VoiceOrTypeField(controller: _region, label: 'المنطقة'),
            VoiceOrTypeField(
              controller: _population,
              label: 'عدد السكان إن عُرف',
              keyboardType: TextInputType.number,
            ),
            VoiceOrTypeField(
              controller: _baseline,
              label: 'خط الأساس للحالات في فترة مماثلة',
              keyboardType: TextInputType.number,
            ),
            VoiceOrTypeField(
              controller: _cases,
              label: 'حالات هذه الفترة',
              keyboardType: TextInputType.number,
            ),
            VoiceOrTypeField(controller: _source, label: 'مصدر الرقم'),
            SwitchListTile(
              title: const Text('تعريف الحالة مسجّل'),
              value: _definition,
              onChanged: (value) => setState(() => _definition = value),
            ),
            SwitchListTile(
              title: const Text('تأخر إبلاغ مذكور'),
              value: _delay,
              onChanged: (value) => setState(() => _delay = value),
            ),
            SwitchListTile(
              title: const Text('جهة مختصة أكّدت في هذه البطاقة'),
              subtitle: const Text('لا يُفعَّل من العدد'),
              value: _official,
              onChanged: (value) => setState(() => _official = value),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _assess,
              child: const Text('قيّم الإشارة'),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_status),
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              for (final line in result.limitsAr) Text('• $line'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HealthGuidanceScreen(
                        profileId: widget.profileId,
                        seedQuestion: _disease.text.trim().isEmpty
                            ? 'وقاية'
                            : _disease.text.trim(),
                        signalNoteAr: result.statementAr,
                      ),
                    ),
                  );
                },
                child: const Text('افتح الإرشاد المرتبط بهذه الإشارة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
