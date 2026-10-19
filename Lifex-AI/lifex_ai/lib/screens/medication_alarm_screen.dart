/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: medication_alarm_screen.dart
/// منبّه أدوية لعدة أفراد: اسم حقيقي + دواء + ساعة، كتابة ونطق، ثم صمت بعد التناول.
/// =============================================================
library lifex_ai.screens.medication_alarm_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health_event_manager.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/medications/medication_alarm_engine.dart';
import '../features/medications/medication_alarm_ledger.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/voice_fill_button.dart';

class MedicationAlarmScreen extends StatefulWidget {
  const MedicationAlarmScreen({super.key});

  @override
  State<MedicationAlarmScreen> createState() => _MedicationAlarmScreenState();
}

class _MedicationAlarmScreenState extends State<MedicationAlarmScreen> {
  static const _engine = MedicationAlarmEngine();
  final _ledger = MedicationAlarmLedger();
  final _medicine = TextEditingController();
  TimeOfDay _clock = const TimeOfDay(hour: 8, minute: 0);
  String? _forProfileId;
  Timer? _tick;
  String? _lastSpokenId;
  DateTime? _lastSpokenAt;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _pulse());
    WidgetsBinding.instance.addPostFrameCallback((_) => _pulse());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _medicine.dispose();
    super.dispose();
  }

  List<MedicationAlarm> _all(ActiveProfileController controller) =>
      _ledger.household(controller.allProfiles);

  Future<void> _pulse() async {
    if (!mounted) return;
    final controller = context.read<ActiveProfileController>();
    final due = _engine.dueAlarms(_all(controller), DateTime.now());
    setState(() {});
    if (due.isEmpty) return;
    final first = due.first;
    final now = DateTime.now();
    final recently = _lastSpokenId == first.id &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < const Duration(seconds: 50);
    if (recently) return;
    _lastSpokenId = first.id;
    _lastSpokenAt = now;
    final cue = _engine.cue(first);
    await VoiceEngine.instance.speak(cue.spokenAr);
  }

  Future<void> _take(MedicationAlarm alarm) async {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.profileById(alarm.profileId);
    if (profile == null) return;
    final now = DateTime.now();
    _ledger.replace(profile, _engine.acknowledge(alarm, now));
    controller.saveActiveProfileChanges();
    HealthEventManager.instance.emitQuick(
      HealthEventType.medicationTaken,
      sourceModule: 'medication_alarm',
      profileId: alarm.profileId,
      data: {'medicine': alarm.medicine, 'clock': alarm.clock},
    );
    _lastSpokenId = null;
    final next = _engine.nextAfterTake(_all(controller), alarm, now);
    final silence = next == null
        ? 'تم. سكت المنبّه حتى لا جرعة تالية مسجّلة.'
        : 'تم. سكت المنبّه حتى ${next.personName} — ${next.medicine} الساعة ${next.clock}.';
    setState(() {});
    await VoiceEngine.instance.speak(silence);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        _forProfileId ??= controller.activeProfileId;
        final people = controller.allProfiles;
        final alarms = _all(controller);
        final due = _engine.dueAlarms(alarms, DateTime.now());
        return Scaffold(
          appBar: AppBar(title: const Text('منبّه الأدوية الذكي')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'ينبّه كل فرد باسمه الحقيقي واسم الدواء والساعة، كتابة ونطقاً، والشاشة مفتوحة. '
                    'ليس منبّهاً خفياً بعد إغلاق التطبيق. Lifex لا يصف الجرعة.',
              ),
              if (people.isEmpty)
                const Text('أضف ملفاً في الحساب أولاً.')
              else
                DropdownButtonFormField<String>(
                  value: people.any((item) => item.profileId == _forProfileId)
                      ? _forProfileId
                      : people.first.profileId,
                  items: [
                    for (final person in people)
                      DropdownMenuItem(
                        value: person.profileId,
                        child: Text(person.fullName),
                      ),
                  ],
                  onChanged: (value) => setState(() => _forProfileId = value),
                  decoration: const InputDecoration(
                    labelText: 'الشخص (اسمه الحقيقي)',
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _medicine,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدواء كما في الوصفة',
                        hintText: 'مثال: أومنتين',
                      ),
                    ),
                  ),
                  VoiceFillButton(
                    onText: (text) =>
                        _medicine.text = _medicine.text.isEmpty
                            ? text
                            : '${_medicine.text} $text',
                  ),
                ],
              ),
              ListTile(
                title: Text('ساعة الدواء: ${_clock.format(context)}'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _clock,
                  );
                  if (picked != null) setState(() => _clock = picked);
                },
              ),
              FilledButton(
                onPressed: () {
                  final id = _forProfileId;
                  final person = id == null ? null : controller.profileById(id);
                  if (person == null || _medicine.text.trim().isEmpty) return;
                  _ledger.add(
                    profile: person,
                    medicine: _medicine.text,
                    hour: _clock.hour,
                    minute: _clock.minute,
                  );
                  controller.saveActiveProfileChanges();
                  _medicine.clear();
                  setState(() {});
                },
                child: const Text('حفظ المنبّه لهذا الشخص'),
              ),
              const SizedBox(height: 16),
              Text('مستحق الآن', style: Theme.of(context).textTheme.titleMedium),
              if (due.isEmpty)
                const Text('لا جرعة مستحقة. المنبّه صامت.')
              else
                for (final alarm in due)
                  Card(
                    color: Colors.orange.withOpacity(0.12),
                    child: ListTile(
                      title: Text(_engine.cue(alarm).writtenAr),
                      subtitle: const Text('قل «لقد تناولت الدواء» أو «تم» أو اضغط.'),
                      trailing: FilledButton(
                        onPressed: () => _take(alarm),
                        child: const Text('لقد تناولت الدواء'),
                      ),
                    ),
                  ),
              VoiceFillButton(
                onText: (text) {
                  if (!MedicationAlarmEngine.isTakenSpeech(text)) return;
                  final first = due.isEmpty ? null : due.first;
                  if (first != null) _take(first);
                },
              ),
              const SizedBox(height: 12),
              Text('كل المنبّهات في الحساب',
                  style: Theme.of(context).textTheme.titleMedium),
              for (final alarm in alarms)
                ListTile(
                  title: Text('${alarm.personName} — ${alarm.medicine}'),
                  subtitle: Text(alarm.clock),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final person = controller.profileById(alarm.profileId);
                      if (person == null) return;
                      final profileId = controller.activeProfileId ??
                          alarm.profileId;
                      final entry =
                          context.read<LioSensitiveActionEntry>();
                      final outcome = await entry.authorizeThenRun<void>(
                        request: LioGatewayRequest(
                          requestId:
                              'alarm_del_${alarm.id}_${DateTime.now().millisecondsSinceEpoch}',
                          correlationId: 'alarm_$profileId',
                          identityAccountId: profileId,
                          purpose: 'care_support',
                          requestedAction: 'delete_medication_alarm',
                          dataScope: 'profile_basic',
                          sensitivity: LioDataSensitivity.personal,
                          consent: const LioConsentContext(
                            consentGranted: true,
                            purposeAligned: true,
                          ),
                          riskLevel: LioActionRisk.medium,
                          timestamp: DateTime.now().toUtc(),
                          authenticated: true,
                          authorized: true,
                          minimumNecessarySatisfied: true,
                        ),
                        run: () async {
                          _ledger.remove(person, alarm.id);
                        },
                      );
                      if (!outcome.executed || !mounted) return;
                      controller.saveActiveProfileChanges();
                      setState(() {});
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
