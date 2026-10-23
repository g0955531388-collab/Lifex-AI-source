/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: voice_control_screen.dart
/// أوامر صوتية بالاتجاهين: استماع + رد + إشارات حالة.
/// =============================================================
library lifex_ai.screens.voice_control_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_navigator.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/permission_transparency.dart';
import '../features/energy/energy_manager.dart';
import '../features/energy/phone_battery_brief.dart';
import '../features/emergency/emergency_phone_contacts_registry.dart';
import '../features/medications/medication_alarm_engine.dart';
import '../features/medications/medication_alarm_ledger.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/accessibility/screen_voice_board.dart';
import '../features/device_guardian/lost_phone_desk.dart';
import '../features/accessibility/vision_model_update_desk.dart';
import '../features/search/external_search_catalog.dart';
import '../features/voice/command_parser.dart';
import '../features/voice/conversation_manager.dart';
import '../features/voice/emergency_voice_handler.dart';
import '../features/voice/hardware_cue_bridge.dart';
import '../features/voice/hardware_cue_calibrator.dart';
import '../features/voice/language_detector.dart';
import '../features/voice/voice_engine.dart';
import '../features/voice/voice_turn_desk.dart';
import '../features/voice/voice_locale_policy.dart';
import '../features/voice/voice_privacy_manager.dart';
import '../features/voice/voice_reply.dart';
import '../features/voice/wake_word_detector.dart';
import '../features/devices/lifex_device_runtime.dart';
import '../features/hospital/hospital_blood_bank.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../widgets/accessible_widgets.dart';
import 'blood_request_screen.dart';
import 'box_unit_screen.dart';
import 'device_center_screen.dart';
import 'donations_center_screen.dart';
import 'wallet_screen.dart';
import 'accessibility_assistant_screen.dart';
import 'appointments_screen.dart';
import 'camera_notes_screen.dart';
import 'clinical_watch_screen.dart';
import 'manual_vitals_screen.dart';
import 'optical_radar_screen.dart';
import 'doctor_diary_screen.dart';
import 'doctor_directory_screen.dart';
import 'empowerment_lab_screen.dart';
import 'child_rights_book_screen.dart';
import 'choice_mirror_screen.dart';
import 'knowledge_arcade_screen.dart';
import 'personal_shelf_screen.dart';
import 'royal_intelligence_screen.dart';
import 'youth_guide_screen.dart';
import 'health_guidance_screen.dart';
import 'epidemic_surveillance_screen.dart';
import 'health_profile_screen.dart';
import 'layered_lens_studio_screen.dart';
import '../features/voice/assistant_session.dart';
import '../features/voice/voice_action_router.dart';
import 'lifex_unified_web_portal_screen.dart';
import '../features/accessibility/live_vision_provider.dart';
import 'live_sight_screen.dart';
import 'messenger_screen.dart';
import 'medication_alarm_screen.dart';
import 'medications_screen.dart';
import 'permission_transparency_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'project_box_hub_screen.dart';
import 'smart_health_questionnaire_screen.dart';
import 'book_library_screen.dart';
import 'system_search_screen.dart';
import 'vision_resource_screen.dart';
import 'thumbnail_manage_screen.dart';

class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({
    super.key,
    this.listenOnOpen = false,
    this.seedText,
  });

  final bool listenOnOpen;
  final String? seedText;

  static VoidCallback? _listenIfOpen;
  static Future<void> Function(String text)? _handleIfOpen;

  /// يستدعي الاستماع إن كانت الشاشة ظاهرة، دون تكديس صفحة ثانية.
  static bool requestListenIfOpen() {
    final listen = _listenIfOpen;
    if (listen == null) return false;
    listen();
    return true;
  }

  /// يمرّر كلاماً مسموعاً إلى الشاشة المفتوحة. وإلا تُفتح شاشة جديدة.
  static bool offerHeardText(String text) {
    final handle = _handleIfOpen;
    if (handle == null || text.trim().isEmpty) return false;
    unawaited(handle(text.trim()));
    return true;
  }

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen>
    with SingleTickerProviderStateMixin {
  final _parser = CommandParser();
  final _wake = WakeWordDetector();
  final _conversation = ConversationManager();
  final _privacy = VoicePrivacyManager.instance;
  final _emergencyVoice = const EmergencyVoiceHandler();
  late final AnimationController _pulse;
  final _typed = TextEditingController();
  final _typedFocus = FocusNode();
  String? _lastText;
  String? _replyAr;
  bool _sessionBusy = false;
  bool _manualField = false;
  bool _stopEar = false;

  VoiceEngine get _engine => VoiceEngine.instance;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _engine.addStateListener(_onEngine);
    _typedFocus.addListener(() {
      if (_typedFocus.hasFocus) _manualField = true;
    });
    unawaited(_restoreSpeechPrefs());
    VoiceControlScreen._listenIfOpen = _cueListen;
    VoiceControlScreen._handleIfOpen = _handleText;
    if (widget.seedText != null && widget.seedText!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_handleText(widget.seedText!.trim()));
      });
    } else if (widget.listenOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cueListen();
      });
    }
  }

  void _cueListen() {
    if (!mounted) return;
    unawaited(_listen());
  }

  @override
  void dispose() {
    VoiceControlScreen._listenIfOpen = null;
    VoiceControlScreen._handleIfOpen = null;
    _privacy.screenEarEnabled = false;
    _engine.removeStateListener(_onEngine);
    unawaited(_engine.stopListening());
    unawaited(_engine.interruptIfSpeaking());
    _typed.dispose();
    _typedFocus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onEngine(VoiceEngineState state) {
    if (!mounted) return;
    if (state == VoiceEngineState.listening ||
        state == VoiceEngineState.speaking) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.reset();
    }
    final partial = _engine.partialTranscript?.trim() ?? '';
    if (state == VoiceEngineState.listening &&
        partial.isNotEmpty &&
        !_manualField) {
      _typed.value = TextEditingValue(
        text: partial,
        selection: TextSelection.collapsed(offset: partial.length),
      );
      _lastText = partial;
    }
    setState(() {});
  }

  Color _signalColor(BuildContext context) {
    switch (_engine.state) {
      case VoiceEngineState.listening:
        return Theme.of(context).colorScheme.error;
      case VoiceEngineState.speaking:
        return Theme.of(context).colorScheme.primary;
      case VoiceEngineState.processing:
        return Theme.of(context).colorScheme.secondary;
      case VoiceEngineState.error:
        return Theme.of(context).colorScheme.error;
      case VoiceEngineState.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _signalLabel() {
    switch (_engine.state) {
      case VoiceEngineState.listening:
        return 'يستمع ويسجّل';
      case VoiceEngineState.speaking:
        return 'يرد بالصوت';
      case VoiceEngineState.processing:
        return 'يعالج الكلام';
      case VoiceEngineState.error:
        return 'تعذّر الصوت';
      case VoiceEngineState.idle:
        return 'جاهز بالاتجاهين';
    }
  }

  Future<bool> _ensureMicConsent() async {
    if (PermissionTransparencyManager.instance
        .isGranted(LifexSensitivePermission.microphone)) {
      _privacy.microphoneAllowed = true;
      return true;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('المساعد الصوتي الصحي'),
        content: const Text(
          'الميكروفون للاستماع والرد وأنت على هذه الشاشة. '
          'ليس تسجيلاً بعد إغلاقها، ولا يُرسل مقطع صوتي لخادم. '
          'يمكنك إيقافه لاحقاً من شفافية الصلاحيات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('السماح بهذه الوظيفة'),
          ),
        ],
      ),
    );
    PermissionTransparencyManager.instance.decide(
      permission: LifexSensitivePermission.microphone,
      granted: ok == true,
    );
    _privacy.microphoneAllowed = ok == true;
    return ok == true;
  }

  Future<void> _listen() async {
    if (_sessionBusy) return;
    if (!await _ensureMicConsent()) {
      setState(() => _replyAr = 'بدون إذن الميكروفون لا أسمع ولا أسجّل.');
      return;
    }
    if (_engine.state == VoiceEngineState.speaking) {
      await _engine.stopSpeaking();
    }
    _sessionBusy = true;
    _stopEar = false;
    if (!_typedFocus.hasFocus) _manualField = false;
    try {
      do {
        if (!mounted) break;
        setState(() {
          _lastText = null;
        });
        HapticFeedback.mediumImpact();
        PermissionTransparencyManager.instance
            .useIfGranted(LifexSensitivePermission.microphone);
        final result = await _engine.listenFresh();
        if (!mounted) break;
        final heard = result.textResult?.trim() ?? '';
        if (heard.isNotEmpty && !_manualField) {
          _typed.value = TextEditingValue(
            text: heard,
            selection: TextSelection.collapsed(offset: heard.length),
          );
        }
        setState(() {
          _lastText = heard.isEmpty ? _engine.partialTranscript : heard;
        });
        if (heard.isNotEmpty) {
          final needsWake = _privacy.screenEarEnabled &&
              !_conversation.waitingForClarification;
          if (needsWake && !_wake.containsWakeWord(heard)) {
            _engine.signalAr('الأذن الرقمية تنتظر كلمة ليفكس أو Lifex.');
            continue;
          }
          await _handleText(heard);
        } else if (!_privacy.screenEarEnabled) {
          final message = result.errorMessageAr ?? _engine.lastSignalAr;
          setState(() => _replyAr = message);
          final spoken = await _engine.speak(message);
          if (!mounted) break;
          if (!spoken.success) {
            setState(() {
              _replyAr =
                  '${spoken.errorMessageAr ?? 'تعذّر الرد الصوتي.'}\n$message';
            });
          }
        }
      } while (_privacy.screenEarEnabled && mounted && !_stopEar);
    } finally {
      _sessionBusy = false;
    }
  }

  Future<void> _say(VoiceReply copy) async {
    if (!mounted) return;
    final code = Localizations.localeOf(context).languageCode;
    final message = copy.of(code);
    setState(() => _replyAr = message);
    final epoch = _engine.speechEpoch;
    final spoken = await _engine.speak(message);
    if (!mounted || epoch != _engine.speechEpoch) return;
    if (!spoken.success) {
      setState(() {
        _replyAr = '${spoken.errorMessageAr ?? 'تعذّر النطق.'}\n$message';
      });
    }
  }

  Future<void> _restoreSpeechPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble('lifex_speech_rate');
      final volume = prefs.getDouble('lifex_speech_volume');
      if (!mounted) return;
      if (rate != null) {
        AssistantSession.instance.speechRate = rate.clamp(0.2, 1.0);
      }
      if (volume != null) {
        AssistantSession.instance.outputVolume = volume.clamp(0.2, 1.0);
      }
    } catch (_) {}
  }

  Future<void> _storeSpeechPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        'lifex_speech_rate',
        AssistantSession.instance.speechRate,
      );
      await prefs.setDouble(
        'lifex_speech_volume',
        AssistantSession.instance.outputVolume,
      );
    } catch (_) {}
  }

  Future<void> _runVoiceTurn(VoiceTurn turn) async {
    switch (turn.kind) {
      case VoiceTurnKind.pass:
        return;
      case VoiceTurnKind.slower:
        AssistantSession.instance.slowSpeech();
        unawaited(_storeSpeechPrefs());
        await _say(VoiceReply(
          ar: 'أبطأت القراءة. السرعة ${AssistantSession.instance.speechRate.toStringAsFixed(1)}.',
          en: 'Reading is slower.',
        ));
        return;
      case VoiceTurnKind.faster:
        AssistantSession.instance.raiseSpeech();
        unawaited(_storeSpeechPrefs());
        await _say(VoiceReply(
          ar: 'رفعت سرعة القراءة. السرعة ${AssistantSession.instance.speechRate.toStringAsFixed(1)}.',
          en: 'Reading is faster.',
        ));
        return;
      case VoiceTurnKind.disableAuto:
        await _loadVisionUpdatePrefs();
        VisionModelUpdateDesk.instance.autoEnabled = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(VisionModelUpdateDesk.autoKey, false);
        } catch (_) {}
        if (!mounted) return;
        await _say(VoiceReply(ar: turn.messageAr, en: turn.messageAr));
        return;
      case VoiceTurnKind.updateModel:
        await _loadVisionUpdatePrefs();
        final report = await VisionModelUpdateDesk.instance.request(manual: true);
        if (!mounted) return;
        await _say(VoiceReply(ar: report.messageAr, en: report.messageAr));
        return;
      case VoiceTurnKind.findPhone:
        var ear = false;
        try {
          ear = await Permission.microphone.isGranted;
        } catch (_) {
          ear = false;
        }
        if (!mounted) return;
        await _say(VoiceReply(
          ar: LostPhoneDesk().nearbyReply(earAvailable: ear),
          en: LostPhoneDesk().nearbyReply(earAvailable: ear),
        ));
        return;
      case VoiceTurnKind.scene:
      case VoiceTurnKind.barcode:
      case VoiceTurnKind.openBlindCamera:
      case VoiceTurnKind.details:
      case VoiceTurnKind.readText:
      case VoiceTurnKind.pauseDescription:
      case VoiceTurnKind.resumeDescription:
      case VoiceTurnKind.frontCamera:
      case VoiceTurnKind.backCamera:
      case VoiceTurnKind.askCloud:
      case VoiceTurnKind.grantCloud:
      case VoiceTurnKind.revokeCloud:
        final sight = AssistantSession.instance.applySightTurn;
        if (sight != null) {
          await sight(turn);
          return;
        }
        if (!mounted) return;
        final profileId =
            context.read<ActiveProfileController>().activeProfileId ?? '';
        if (turn.messageAr.isNotEmpty) {
          await _say(VoiceReply(ar: turn.messageAr, en: turn.messageAr));
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveSightScreen(
              profileId: profileId,
              ask: turn.kind == VoiceTurnKind.readText
                  ? BlindCameraAsk.text
                  : BlindCameraAsk.scene,
              readBarcode: turn.kind == VoiceTurnKind.barcode,
              initialOrder: _sightOrder(turn.kind),
            ),
          ),
        );
        return;
      case VoiceTurnKind.openLens:
        final openLens = AssistantSession.instance.applySightTurn;
        if (openLens != null) {
          await openLens(turn);
          return;
        }
        final spoken = await const ExternalVisionHandoff().openEngine('lens');
        if (!mounted) return;
        await _say(VoiceReply(ar: spoken, en: spoken));
        return;
    }
  }

  BlindCameraOrder _sightOrder(VoiceTurnKind kind) {
    switch (kind) {
      case VoiceTurnKind.details:
        return BlindCameraOrder.details;
      case VoiceTurnKind.readText:
        return BlindCameraOrder.readText;
      case VoiceTurnKind.pauseDescription:
        return BlindCameraOrder.pause;
      case VoiceTurnKind.resumeDescription:
        return BlindCameraOrder.resume;
      case VoiceTurnKind.frontCamera:
        return BlindCameraOrder.front;
      case VoiceTurnKind.backCamera:
        return BlindCameraOrder.back;
      case VoiceTurnKind.askCloud:
        return BlindCameraOrder.cloud;
      case VoiceTurnKind.grantCloud:
        return BlindCameraOrder.grantCloud;
      case VoiceTurnKind.revokeCloud:
        return BlindCameraOrder.revokeCloud;
      case VoiceTurnKind.barcode:
        return BlindCameraOrder.barcode;
      default:
        return BlindCameraOrder.none;
    }
  }

  Future<void> _loadVisionUpdatePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      VisionModelUpdateDesk.instance.applyPrefs(
        auto: prefs.getBool(VisionModelUpdateDesk.autoKey) ?? true,
        wifi: prefs.getBool(VisionModelUpdateDesk.wifiKey) ?? true,
      );
    } catch (_) {}
  }

  String _operationStatusAr() {
    final signal = _engine.lastSignalAr.trim();
    final state = switch (_engine.state) {
      VoiceEngineState.idle => 'الانتظار',
      VoiceEngineState.listening => 'الاستماع',
      VoiceEngineState.processing => 'التعرف',
      VoiceEngineState.speaking => 'القراءة',
      VoiceEngineState.error => 'تعذر آخر خطوة',
    };
    final detail = signal.isEmpty ? 'لا إشارة أحدث من هذه.' : signal;
    return 'حالة العملية: $state. $detail';
  }

  Future<void> _stopReading() async {
    final shown = _replyAr?.trim() ?? '';
    AssistantSession.instance.holdForResume(shown);
    await _engine.stopSpeaking();
    if (!mounted) return;
    await _say(const VoiceReply(
      ar: 'أوقفت القراءة. قل: تابع القراءة.',
      en: 'Reading stopped. Say: continue reading.',
    ));
  }

  Future<void> _submitTyped() async {
    final text = _typed.text.trim();
    if (text.isEmpty || _sessionBusy) return;
    _typed.clear();
    _typedFocus.unfocus();
    setState(() => _lastText = text);
    await _handleText(text);
  }

  HardwareCueCalibrator get _cue => HardwareCueBridge.instance.calibrator;

  Future<void> _saveCue() async {
    await HardwareCueBridge.instance.save();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleText(String text) async {
    final folded = text.trim().toLowerCase();
    final turn = planVoiceTurn(text);
    if (turn.kind != VoiceTurnKind.pass) {
      await _runVoiceTurn(turn);
      return;
    }
    if (text.contains('كرر آخر') ||
        text.contains('كرر الرد') ||
        folded.contains('repeat that') ||
        folded.contains('repeat the reply')) {
      final last = _replyAr?.trim() ?? '';
      await _say(VoiceReply(
        ar: last.isEmpty ? 'لا رد مكتمل لأعيده.' : last,
        en: last.isEmpty ? 'There is no completed reply to repeat.' : last,
      ));
      return;
    }
    if (text.contains('أعد المحاولة') ||
        text.contains('اعد المحاولة') ||
        folded.contains('try again')) {
      await _say(
          const VoiceReply(ar: 'أعيد الاستماع.', en: 'Listening again.'));
      if (mounted) unawaited(_listen());
      return;
    }
    if (text.contains('ابدأ الاستماع') || folded.contains('start listening')) {
      if (mounted) unawaited(_listen());
      return;
    }
    if (text.contains('توقف عن الاستماع') ||
        folded.contains('stop listening')) {
      _stopEar = true;
      _privacy.screenEarEnabled = false;
      await _engine.stopListening();
      await _say(
          const VoiceReply(ar: 'أوقفت الاستماع.', en: 'Listening stopped.'));
      return;
    }
    if (text.contains('أعد القراءة') || folded.contains('read it again')) {
      final held = AssistantSession.instance.heldReading?.trim();
      final spoken = (held != null && held.isNotEmpty)
          ? held
          : ScreenVoiceBoard.instance.readingAr();
      await _say(VoiceReply(ar: spoken, en: spoken));
      return;
    }
    if (text.contains('تابع القراءة') ||
        text.contains('أكمل القراءة') ||
        folded.contains('continue reading') ||
        folded.contains('resume reading')) {
      final held = AssistantSession.instance.takeHeldReading();
      await _say(VoiceReply(
        ar: held ?? 'لا قراءة موقوفة. قل أمراً ثم أوقف القراءة إن أردت المتابعة.',
        en: held ?? 'There is no paused reading.',
      ));
      return;
    }
    if (text.contains('ما حالة هذه العملية') ||
        text.contains('حالة هذه العملية') ||
        folded.contains('operation status')) {
      await _say(VoiceReply(
        ar: _operationStatusAr(),
        en: _engine.lastSignalAr,
      ));
      return;
    }
    final profiles = context.read<ActiveProfileController>();
    final detection = await LanguageDetector.instance.detect(text);
    if (!mounted) return;
    final lang = detection.preciseLanguageCode ??
        LanguageDetector.instance.localeCodeFor(detection.language);
    _conversation.rememberLanguage(lang);
    final command = MedicationAlarmEngine.isTakenSpeech(text)
        ? ParsedVoiceCommand(
            intent: VoiceCommandIntent.confirmMedicationTaken,
            originalText: text,
          )
        : _parser.parse(text);
    Future<void> reply(VoiceReply copy, {VoidCallback? thenOpen}) async {
      final message = copy.of(lang);
      setState(() => _replyAr = message);
      final epoch = _engine.speechEpoch;
      final spoken = await _engine.speak(message);
      if (!mounted || epoch != _engine.speechEpoch) return;
      if (!spoken.success) {
        setState(() {
          _replyAr =
              '${spoken.errorMessageAr ?? 'ظهر النص لأن النطق تعذّر.'}\n$message';
        });
      }
      thenOpen?.call();
    }

    switch (command.intent) {
      case VoiceCommandIntent.confirmMedicationTaken:
        _conversation.clear();
        final due = const MedicationAlarmEngine().dueAlarms(
          MedicationAlarmLedger().household(profiles.allProfiles),
          DateTime.now(),
        );
        if (due.isEmpty) {
          await reply(
            const VoiceReply(
              ar: 'لا جرعة مستحقة الآن. المنبّه صامت.',
              en: 'No dose is due. The reminder is quiet.',
            ),
          );
          break;
        }
        final alarm = due.first;
        final name = alarm.personName.trim();
        if (name.isEmpty) {
          await reply(
            const VoiceReply(
              ar: 'اسم المريض فارغ. لن أسجّل التناول حتى يُكتب الاسم، منعاً للخلط.',
              en: 'The patient name is empty. The dose stays unmarked until the name is written.',
            ),
          );
          break;
        }
        final person = profiles.profileById(alarm.profileId);
        if (person != null) {
          MedicationAlarmLedger().replace(
            person,
            const MedicationAlarmEngine().acknowledge(alarm, DateTime.now()),
          );
          profiles.saveActiveProfileChanges();
        }
        await reply(
          VoiceReply(
            ar: 'تم. سكت المنبّه حتى الجرعة التالية. المريض $name أخذ ${alarm.medicine}.',
            en: 'Taken. Patient $name took ${alarm.medicine}. The reminder stays quiet until the next dose.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MedicationAlarmScreen(),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openHealthProfile:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح ملفك الصحي',
            en: 'Opening your health profile.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    HealthProfileScreen(profile: profiles.activeProfile),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openMedications:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح سجل أدويتك',
            en: 'Opening your medications.',
          ),
          thenOpen: () {
            final profileId = profiles.activeProfileId;
            if (profileId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicationsScreen(profileId: profileId),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openAppointments:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح مواعيدك',
            en: 'Opening your appointments.',
          ),
          thenOpen: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AppointmentsScreen()));
          },
        );
        break;
      case VoiceCommandIntent.callEmergency:
        _conversation.clear();
        final arabic = lang.startsWith('ar');
        await reply(VoiceReply(
          ar: _emergencyVoice.prompt(arabic: true),
          en: _emergencyVoice.prompt(arabic: false),
        ));
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('طلب طوارئ'),
            content: Text(_emergencyVoice.prompt(arabic: arabic)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('أنا بخير')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('سجّل محلياً')),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          final profileId = profiles.activeProfileId ?? 'unknown_profile';
          context.read<EmergencyPhoneContactsRegistry>().replaceForProfile(
                profileId,
                EmergencyPhoneContactsRegistry.phonesFromTrustedMaps(
                  profiles.activeProfile?.questionnaireData['trustedContacts'],
                ),
              );
          final outcome = await context
              .read<LioSensitiveActionEntry>()
              .triggerEmergencyLimited(
                gatewayRequest: LioGatewayRequest(
                  requestId:
                      'emg_voice_${profileId}_${DateTime.now().millisecondsSinceEpoch}',
                  correlationId: 'emg_voice_$profileId',
                  identityAccountId: profileId,
                  purpose: 'emergency_signal',
                  requestedAction: 'signal_trusted_contacts',
                  dataScope: 'emergency_contacts_min',
                  sensitivity: LioDataSensitivity.personal,
                  consent: const LioConsentContext(
                    consentGranted: true,
                    purposeAligned: true,
                  ),
                  riskLevel: LioActionRisk.high,
                  timestamp: DateTime.now().toUtc(),
                  authenticated: true,
                  authorized: true,
                  emergencyLimitedMode: true,
                  humanConfirmed: true,
                  minimumNecessarySatisfied: true,
                ),
                profileId: profileId,
                reasonAr: 'أمر صوتي مؤكَّد من شاشة التحكم الصوتي.',
              );
          if (!mounted) return;
          final msg = outcome.executed
              ? (outcome.value?.messageAr ?? 'أُرسلت إشارة الطوارئ المحدودة.')
              : 'توقفت الطوارئ عند LIO (${outcome.decision.wireDecision}).';
          announceForScreenReader(context, msg);
          await reply(VoiceReply(ar: msg, en: msg));
        } else if (confirmed != true && mounted) {
          await reply(VoiceReply(
            ar: _emergencyVoice.cancelAr(),
            en: 'Alert lifted locally. No video was captured and no message was sent.',
          ));
        }
        break;
      case VoiceCommandIntent.addSymptom:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سجّل العرض في الاستبيان الصحي الشامل',
            en: 'Open the health questionnaire to log the symptom.',
          ),
          thenOpen: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SmartHealthQuestionnaireScreen()));
          },
        );
        break;
      case VoiceCommandIntent.readLastLabResult:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'من المساعد الصوتي لا أفتح سجل الفحص المخزن. افتح الملف الصحي لترى النتيجة المسجّلة كما هي. لن أخترع نتيجة.',
            en: 'This voice path does not open the stored lab record. Open the health file to see the recorded result. No result is invented.',
          ),
        );
        break;
      case VoiceCommandIntent.switchProfile:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'يمكنك تبديل الملف من إعدادات الحساب.',
            en: 'Switch profiles from account settings.',
          ),
        );
        break;
      case VoiceCommandIntent.openProjectBox:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح صندوق المشروع',
            en: 'Opening the project box.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProjectBoxHubScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openSearch:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح البحث داخل Lifex-AI',
            en: 'Opening search inside Lifex-AI.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SystemSearchScreen(
                  initialQuery: ExternalSearchCatalog.phraseOf(text),
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openWebSearch:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'جهزت البحث الخارجي. اضغط فتح المتصفح ليُرسل نص البحث فقط، بلا ملفك الصحي.',
            en: 'Web search is ready. The button sends only the search phrase, not the health file.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SystemSearchScreen(
                  initialQuery: ExternalSearchCatalog.phraseOf(text),
                  startOnWeb: true,
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openLibrary:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح مكتبة الفهارس. الكتاب يُفتح عند الناشر إذا سمح مصدره.',
            en: 'Opening the catalog library. A book opens at its publisher when that source allows it.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookLibraryScreen(
                  initialPhrase: ExternalSearchCatalog.phraseOf(text),
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openVisionResources:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح دليل موارد الرؤية. الصفحات رسمية ولا يُثبَّت نموذج تلقائياً.',
            en: 'Opening the vision resource guide. The pages are official and no model is installed automatically.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisionResourceScreen(
                  profileId: profiles.activeProfileId ?? '',
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.goHome:
        _conversation.clear();
        final homeNav = LifexNavigator.key.currentState;
        await reply(
          const VoiceReply(
            ar: 'رجعت إلى الشاشة الرئيسية.',
            en: 'Back at the home screen.',
          ),
          thenOpen: () => homeNav?.popUntil((route) => route.isFirst),
        );
        break;
      case VoiceCommandIntent.goBack:
        _conversation.clear();
        final navigator = LifexNavigator.key.currentState;
        final canLeave = navigator?.canPop() ?? false;
        await reply(
          VoiceReply(
            ar: canLeave
                ? 'رجعت إلى الشاشة السابقة.'
                : 'لا شاشة سابقة. بقيت حيث أنت.',
            en: canLeave ? 'Went back.' : 'There is no previous screen.',
          ),
          thenOpen: () {
            if (canLeave) navigator?.pop();
          },
        );
        break;
      case VoiceCommandIntent.openPharmacy:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح الصيدلية',
            en: 'Opening the pharmacy.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PharmacyStockScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openDoctors:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح دليل الأطباء',
            en: 'Opening the doctor directory.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DoctorDirectoryScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openCamera:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح أرشيف الأوراق المصوّرة بعد موافقتك. البث المستمر أمر مستقل.',
            en: 'Opening the still-photo archive after consent. Live sight is a separate command.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraNotesScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openLiveSight:
      case VoiceCommandIntent.readVisibleText:
        _conversation.clear();
        final sight = const VoiceActionRouter().route(command.intent);
        await reply(
          VoiceReply(ar: sight.spokenAr, en: sight.spokenAr),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveSightScreen(
                  profileId: profiles.activeProfileId ?? '',
                  ask: command.intent == VoiceCommandIntent.readVisibleText
                      ? BlindCameraAsk.text
                      : BlindCameraAsk.both,
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.repeatScene:
        _conversation.clear();
        AssistantSession.instance.repeatSight?.call();
        await reply(
          VoiceReply(
            ar: AssistantSession.instance.repeatSight == null
                ? 'المساعد البصري غير مفتوح. قل: افتح الكاميرا.'
                : 'أعيد الوصف الأخير.',
            en: 'Repeating the last description.',
          ),
        );
        break;
      case VoiceCommandIntent.pauseScene:
        _conversation.clear();
        AssistantSession.instance.pauseSight?.call();
        await reply(
            const VoiceReply(ar: 'أوقفت الوصف.', en: 'Description paused.'));
        break;
      case VoiceCommandIntent.resumeScene:
        _conversation.clear();
        AssistantSession.instance.resumeSight?.call();
        await reply(
            const VoiceReply(ar: 'استأنفت الوصف.', en: 'Description resumed.'));
        break;
      case VoiceCommandIntent.stopReading:
        _conversation.clear();
        await _stopReading();
        break;
      case VoiceCommandIntent.readScreen:
        _conversation.clear();
        await reply(VoiceReply(
          ar: ScreenVoiceBoard.instance.readingAr(),
          en: ScreenVoiceBoard.instance.readingAr(),
        ));
        break;
      case VoiceCommandIntent.raiseVolume:
        _conversation.clear();
        AssistantSession.instance.raiseVolume();
        unawaited(_storeSpeechPrefs());
        await reply(
          VoiceReply(
            ar: 'مستوى الصوت ${AssistantSession.instance.outputVolume.toStringAsFixed(2)}.',
            en: 'Volume raised.',
          ),
        );
        break;
      case VoiceCommandIntent.openLayeredLens:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح تقريب العدسة. الزوم من العتاد. اللقطة للملف وليست تشخيص جلد.',
            en: 'Opening the close-up lens. Zoom follows the hardware. The shot is a file note, not a skin diagnosis.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LayeredLensStudioScreen(),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openThumbnail:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح إدارة الصورة المصغّرة.',
            en: 'Opening Manage the thumbnail.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ThumbnailManageScreen(),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openDoctorDiary:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح يوميات الطبيب. الحصص فارغة حتى تحجزها أنت.',
            en: 'Opening the doctor diary. Slots stay empty until you book them.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DoctorDiaryScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openEmpowermentLab:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح موسوعة التمكين. ليست استشارة مالية.',
            en: 'Opening the empowerment lab. This is not financial advice.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmpowermentLabScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openChildRights:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح كتاب حقوق الطفل من رواق المعرفة.',
            en: 'Opening the child-rights book in the knowledge arcade.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChildRightsBookScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openChoiceMirror:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح مرآة الاختيار بلغة الجهاز أو التطبيق. ليس علاجاً زوجياً.',
            en: 'Opening the choice-mirror book in the language in use. Not couples therapy.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChoiceMirrorScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openYouthGuide:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح دليل اليافعين. ليس علاجاً نفسياً.',
            en: 'Opening the youth guide. This is not therapy.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YouthGuideScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openRoyalIntelligence:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح المنصة الملكية. تمرين أنماط وليس مقياس ذكاء.',
            en: 'Opening the royal practice. Pattern drill, not a clinical IQ test.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RoyalIntelligenceScreen(),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openKnowledgeArcade:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح رواق المعرفة. مكتبات للقراءة ورفّ تنزيل.',
            en: 'Opening the knowledge arcade. Readable libraries and a download shelf.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KnowledgeArcadeScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openPersonalShelf:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح رفّ التحميل. التنزيل ينجح فقط بعد اتصال حقيقي.',
            en: 'Opening the personal shelf. Download succeeds only after a real connection.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonalShelfScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openClinicalWatch:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح الحماية الظاهرة في الخلفية. إشعار دائم، بلا تصوير خفي وبلا اتصال صامت.',
            en: 'Opening the visible background guard. A persistent notice, no hidden capture and no silent call.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClinicalWatchScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openMessenger:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح المسنجر. التراسل بالمعرّف على هذا الجهاز فقط.',
            en: 'Opening messenger. Messaging by ID stays on this device.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessengerScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openSite:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأشغّل بوابة الموقع داخل التطبيق. ليست موقعاً على الإنترنت.',
            en: 'Opening the in-app site. It is not a website on the internet.',
          ),
          thenOpen: () {
            final id = profiles.activeProfileId ?? '';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LifexUnifiedWebPortalScreen(profileId: id),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openManualVitals:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح القياسات اليدوية. الأرقام من جهازك، وليست من صورة ولا حرارة 37.8 مخترعة.',
            en: 'Opening manual vitals. Numbers come from your device, not from a photo or invented 37.8.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualVitalsScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openOpticalRadar:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح الرادار الضوئي. وميض الفلاش لا يُعلن أمتاراً بلا حسّاس زمن رحلة.',
            en: 'Opening the optical radar. Flash glow is not a meter reading without a time-of-flight sensor.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OpticalRadarScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.openAccessibility:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح المساعد البصري. الوصف المستمر يحتاج موافقة الكاميرا ومحركاً معتمداً.',
            en: 'Opening the visual assistant. Live description needs camera consent and a real engine.',
          ),
          thenOpen: () {
            final id = profiles.activeProfileId;
            if (id == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccessibilityAssistantScreen(profileId: id),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openNetworkUnit:
        _conversation.clear();
        final unitId = command.parameters['unitId'] ?? '';
        final boxId = command.parameters['boxUnitId'] ?? unitId;
        BloodTypeSimple? prefer;
        final typeName = command.parameters['bloodType'];
        if (typeName != null) {
          for (final value in BloodTypeSimple.values) {
            if (value.name == typeName) prefer = value;
          }
        }
        await reply(
          VoiceReply(
            ar: unitId == 'blood'
                ? 'أفتح بنك الدم. التنبيه للمتبرعين الموافقين فقط.'
                : 'أفتح وحدة $boxId من الصندوق. ليست وحدة جديدة.',
            en: unitId == 'blood'
                ? 'Opening the blood desk. Flash alerts only reach consenting donors.'
                : 'Opening the existing box seat, not a new module.',
          ),
          thenOpen: () {
            if (unitId == 'blood') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BloodRequestScreen(preferType: prefer),
                ),
              );
              return;
            }
            try {
              final unit = BoxUnitCatalog.byId(boxId);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BoxUnitScreen(unit: unit)),
              );
            } catch (_) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectBoxHubScreen()),
              );
            }
          },
        );
        break;
      case VoiceCommandIntent.clarifyHealthAspect:
        _conversation.askHealthAspect();
        await reply(
          const VoiceReply(
            ar: 'أي جانب تقصد؟ الأدوية، التحاليل، أم الملف الصحي؟',
            en: 'Which part: medications, lab results, or your health profile?',
          ),
        );
        break;
      case VoiceCommandIntent.openDeviceCenter:
        await reply(
          const VoiceReply(
            ar: 'أفتح مركز الأجهزة. الدعم الفعلي يعتمد على Adapter وإذن Android.',
            en: 'Opening the device center. Real support needs an adapter and Android permission.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceCenterScreen()),
            );
          },
        );
        break;
      case VoiceCommandIntent.listConnectedDevices:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.listConnectedSpoken();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.showWheelchair:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.attachSimulatedWheelchair();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairStatus:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.wheelchairStatusSpoken();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairMoveForward:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('MOVE_FORWARD');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairStop:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('STOP');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairEmergencyStop:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('EMERGENCY_STOP');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairReadBattery:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('READ_BATTERY');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.confirmDeviceMotion:
        {
          if (!mounted) return;
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.confirmPendingMotion();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.openDonations:
        await reply(
          const VoiceReply(
            ar: 'أفتح مركز التبرعات. البحث عام موافق فقط — ليس قائمة مرضى.',
            en: 'Opening donations. Public consented profiles only — not patient lists.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DonationsCenterScreen(),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.donateSearchCancer:
        await reply(
          const VoiceReply(
            ar: 'أبحث عن حملات ومستفيدين عامين لفئة السرطان. ثم اختر من القائمة.',
            en: 'Searching public cancer donation programs. Then pick from the list.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DonationsCenterScreen(
                  initialQuery: 'أريد التبرع لمرضى السرطان',
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.donateSearchHeart:
        await reply(
          const VoiceReply(
            ar: 'أبحث عن برامج دعم القلب العامة المتاحة للتبرع.',
            en: 'Searching public heart donation programs.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DonationsCenterScreen(
                  initialQuery: 'أريد التبرع لمرضى القلب',
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openWallet:
      case VoiceCommandIntent.walletTopUp:
        {
          if (!mounted) return;
          final profile = context.read<ActiveProfileController>().activeProfile;
          final pid = profile?.profileId ?? '';
          await reply(
            VoiceReply(
              ar: pid.isEmpty
                  ? 'لا يوجد ملف نشط. أنشئ ملفاً ثم افتح المحفظة.'
                  : (command.intent == VoiceCommandIntent.walletTopUp
                      ? 'أفتح المحفظة لشحن الرصيد. المسار: مبلغ ثم وسيلة ثم رسوم ثم تأكيد.'
                      : 'أفتح محفظتك.'),
              en: 'Opening wallet.',
            ),
            thenOpen: pid.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WalletScreen(profileId: pid),
                      ),
                    );
                  },
          );
        }
        break;
      case VoiceCommandIntent.walletBalance:
        {
          if (!mounted) return;
          final profile = context.read<ActiveProfileController>().activeProfile;
          final pid = profile?.profileId;
          if (pid == null) {
            await reply(
              const VoiceReply(
                ar: 'لا يوجد ملف نشط لعرض الرصيد.',
                en: 'No active profile for balance.',
              ),
            );
            break;
          }
          if (!mounted) return;
          final walletEntry = context.read<LioSensitiveActionEntry>();
          final balOutcome = await walletEntry.readWalletBalances(
                    gatewayRequest: LioGatewayRequest(
                      requestId:
                          'voice_bal_${pid}_${DateTime.now().millisecondsSinceEpoch}',
                      correlationId: 'voice_wallet_$pid',
                      identityAccountId: pid,
                      purpose: 'wallet_ops',
                      requestedAction: 'read_wallet_balances',
                      dataScope: 'wallet_balance_view',
                      sensitivity: LioDataSensitivity.personal,
                      consent: const LioConsentContext(
                        consentGranted: true,
                        purposeAligned: true,
                      ),
                      riskLevel: LioActionRisk.low,
                      timestamp: DateTime.now().toUtc(),
                      authenticated: true,
                      authorized: true,
                      minimumNecessarySatisfied: true,
                    ),
                    profileId: pid,
                  );
          if (!balOutcome.executed || balOutcome.value == null) {
            await reply(
              VoiceReply(
                ar: 'توقف عرض الرصيد عند LIO (${balOutcome.decision.wireDecision}).',
                en: 'Balance blocked by LIO.',
              ),
            );
            break;
          }
          final bal = balOutcome.value!;
          await reply(
            VoiceReply(
              ar: 'الرصيد المتاح ${(bal.availableMinor / 100).toStringAsFixed(2)} دولار. '
                  'المعلّق ${(bal.pendingMinor / 100).toStringAsFixed(2)}. '
                  'المزوّد Sandbox إن لم يُربط مزود إنتاجي.',
              en: 'Available ${(bal.availableMinor / 100).toStringAsFixed(2)}. '
                  'Pending ${(bal.pendingMinor / 100).toStringAsFixed(2)}.',
            ),
          );
        }
        break;
      case VoiceCommandIntent.openEpidemicDesk:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح رصد الأوبئة. العدد وحده ليس إعلاناً.',
            en: 'Opening epidemic watch. A raw count is not a declaration.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EpidemicSurveillanceScreen(
                  profileId: profiles.activeProfileId,
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.slowReading:
        _conversation.clear();
        AssistantSession.instance.slowSpeech();
        unawaited(_storeSpeechPrefs());
        await reply(VoiceReply(
          ar: 'أبطأت القراءة. السرعة ${AssistantSession.instance.speechRate.toStringAsFixed(1)}.',
          en: 'Reading is slower.',
        ));
        break;
      case VoiceCommandIntent.fasterReading:
        _conversation.clear();
        AssistantSession.instance.raiseSpeech();
        unawaited(_storeSpeechPrefs());
        await reply(VoiceReply(
          ar: 'رفعت سرعة القراءة. السرعة ${AssistantSession.instance.speechRate.toStringAsFixed(1)}.',
          en: 'Reading is faster.',
        ));
        break;
      case VoiceCommandIntent.updateCameraMind:
        _conversation.clear();
        await _loadVisionUpdatePrefs();
        final report = await VisionModelUpdateDesk.instance.request(manual: true);
        await reply(VoiceReply(ar: report.messageAr, en: report.messageAr));
        break;
      case VoiceCommandIntent.disableAutoModelUpdate:
        _conversation.clear();
        await _loadVisionUpdatePrefs();
        VisionModelUpdateDesk.instance.autoEnabled = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(VisionModelUpdateDesk.autoKey, false);
        await reply(const VoiceReply(
          ar: 'أوقفت التحديث التلقائي. لن يعود إلا إذا فعّلته أنت.',
          en: 'Automatic model updates stay off until you turn them on.',
        ));
        break;
      case VoiceCommandIntent.readBarcode:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح العدسة لقراءة الرمز. النص المقروء ليس تفسيراً لدواء.',
            en: 'Opening the lens for a barcode. The code is not a medication explanation.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveSightScreen(
                  profileId: profiles.activeProfileId ?? '',
                  readBarcode: true,
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.openHealthGuidance:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح الإرشاد الصحي. بلا تشخيص وبلا أجر على هذه الاستشارة.',
            en: 'Opening health guidance. No diagnosis, and this consult has no fee.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HealthGuidanceScreen(
                  profileId: profiles.activeProfileId,
                ),
              ),
            );
          },
        );
        break;
      case VoiceCommandIntent.phoneBattery:
        final speech = PhoneBatterySpeech.fromMonitor(
          context.read<EnergyManager>().batteryMonitor,
        );
        await reply(VoiceReply(ar: speech.arabic, en: speech.english));
        break;
      case VoiceCommandIntent.unknown:
        await reply(
          const VoiceReply(
            ar: 'لم أفهم الأمر. جرّب: افتح الكاميرا، ماذا أمامي، اقرأ هذا النص، أعد الوصف، أو أوقف القراءة.',
            en: 'I did not catch that. Say Lifex then: my health, medications, devices, or show wheelchair.',
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = _engine.activeLocaleId ??
        const VoiceLocalePolicy().preferredListenCode();
    final listening = _engine.state == VoiceEngineState.listening;
    final speaking = _engine.state == VoiceEngineState.speaking;
    return ScreenArrival(
      message: 'التحكم الصوتي',
      controls: const ['تحدث الآن', 'أوقف القراءة', 'اختبر النطق', 'اقرأ الشاشة'],
      body: _replyAr ?? _engine.lastSignalAr,
      child: Scaffold(
      appBar: AppBar(title: const Text('التحكم الصوتي')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.18).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: _signalColor(context).withOpacity(0.15),
                  child: Icon(
                    listening
                        ? Icons.mic
                        : speaking
                            ? Icons.volume_up
                            : Icons.hearing,
                    size: 64,
                    color: _signalColor(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Chip(
                avatar: Icon(
                  listening ? Icons.fiber_manual_record : Icons.sync,
                  color: _signalColor(context),
                  size: 16,
                ),
                label: Text(_signalLabel()),
              ),
              const SizedBox(height: 8),
              Text(
                'لغة الجهاز/المتحدث: $locale',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _engine.lastSignalAr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_engine.partialTranscript?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('مباشر: ${_engine.partialTranscript}',
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
              if (_lastText != null &&
                  (_privacy.storeTranscripts ||
                      !_privacy.screenEarEnabled)) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child:
                        Text('سمعت: $_lastText', textAlign: TextAlign.center),
                  ),
                ),
              ],
              if (_replyAr != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  label: 'الرد: $_replyAr',
                  child: Card(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          Text('الرد: $_replyAr', textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Semantics(
                textField: true,
                label: 'مربع الأمر. الكتابة والصوت يصلان إلى المسار نفسه.',
                child: TextField(
                  controller: _typed,
                  focusNode: _typedFocus,
                  textInputAction: TextInputAction.send,
                  enabled: !_sessionBusy,
                  decoration: const InputDecoration(
                    labelText: 'اكتب الأمر نفسه',
                    hintText: 'مثل: ملفي الصحي، بنك الدم، ما الموجود أمامي',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => unawaited(_submitTyped()),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _sessionBusy ? null : _submitTyped,
                  icon: const Icon(Icons.keyboard_return),
                  label: const Text('تنفيذ المكتوب'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الكتابة تستخدم نفس محلل الأوامر الصوتية. لا تحتاج ميكروفوناً.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              Semantics(
                button: true,
                label: speaking
                    ? 'أوقف القراءة'
                    : listening
                        ? 'أوقف الاستماع'
                        : 'تحدث الآن',
                child: FilledButton.icon(
                  onPressed: speaking
                      ? () => unawaited(_stopReading())
                      : listening
                          ? () {
                              _stopEar = true;
                              unawaited(_engine.stopListening());
                            }
                          : _listen,
                  icon: Icon(speaking
                      ? Icons.stop
                      : listening
                          ? Icons.stop_circle
                          : Icons.mic),
                  label: Text(
                    speaking
                        ? 'أوقف القراءة'
                        : listening
                            ? 'أوقف الاستماع'
                            : 'تحدث الآن',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'اختبر النطق',
                child: OutlinedButton.icon(
                  onPressed: speaking
                      ? null
                      : () => unawaited(_say(const VoiceReply(
                            ar: 'هذا اختبار النطق. إذا سمعت هذه الجملة فالمحرك يرد.',
                            en: 'This is a speech test. Hearing this sentence means the engine replied.',
                          ))),
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('اختبر النطق'),
                ),
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                title: const Text('أذن رقمية على هذه الشاشة'),
                subtitle: const Text(
                    'تستمع لكلمة ليفكس أو Lifex ما دامت الشاشة مفتوحة. ليست تجسساً بعد إغلاقها.'),
                value: _privacy.screenEarEnabled,
                onChanged: (value) {
                  setState(() => _privacy.screenEarEnabled = value);
                  if (value) {
                    _listen();
                  } else {
                    _engine.stopListening();
                  }
                },
              ),
              SwitchListTile(
                title: const Text('إبقاء نص الأوامر على الشاشة'),
                subtitle: const Text(
                    'لا يُحفظ مقطع صوتي. النص يظهر هنا فقط إن فعّلت هذا.'),
                value: _privacy.storeTranscripts,
                onChanged: (value) =>
                    setState(() => _privacy.storeTranscripts = value),
              ),
              ExpansionTile(
                leading: const Icon(Icons.touch_app_outlined),
                title: const Text('معايرة زر الاستماع'),
                subtitle: Text(_cue.kindLabelAr(_cue.kind)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_cue.honestyAr()),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<HardwareCueKind>(
                          value: _cue.kind,
                          decoration: const InputDecoration(
                            labelText: 'الزر',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final kind in HardwareCueKind.values)
                              DropdownMenuItem(
                                value: kind,
                                child: Text(_cue.kindLabelAr(kind)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _cue.kind = value);
                            unawaited(_saveCue());
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _cue.tapCount.clamp(2, 4),
                          decoration: const InputDecoration(
                            labelText: 'عدد الضغطات',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 2, child: Text('مرتين')),
                            DropdownMenuItem(
                                value: 3, child: Text('ثلاث مرات')),
                            DropdownMenuItem(
                                value: 4, child: Text('أربع مرات')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _cue.tapCount = value);
                            unawaited(_saveCue());
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<StartSignalKind>(
                          value: _cue.startSignal,
                          decoration: const InputDecoration(
                            labelText: 'إشارة البدء',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: StartSignalKind.tone,
                              child: Text('نغمة'),
                            ),
                            DropdownMenuItem(
                              value: StartSignalKind.voice,
                              child: Text('جملة نطق'),
                            ),
                            DropdownMenuItem(
                              value: StartSignalKind.both,
                              child: Text('نغمة ثم جملة'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _cue.startSignal = value);
                            unawaited(_saveCue());
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('مراقبة سريرية ظاهرة'),
                subtitle: const Text('إشعار دائم بموافقة. ليست تجسساً'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClinicalWatchScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('شفافية الميكروفون'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PermissionTransparencyScreen(),
                  ),
                ),
              ),
              const Text(
                'من ملف وحدة الصوت: استماع، فهم اللغة، تنفيذ، رد. '
                'قل: ليفكس، ذكرني بالدواء — Lifex, what is in front of me — '
                'ليفكس أنا لا أستطيع التنفس',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
