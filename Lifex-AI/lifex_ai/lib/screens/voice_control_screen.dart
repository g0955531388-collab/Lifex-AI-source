/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: voice_control_screen.dart
/// أوامر صوتية بالاتجاهين: استماع + رد + إشارات حالة.
/// =============================================================
library lifex_ai.screens.voice_control_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/permission_transparency.dart';
import '../features/emergency/emergency_phone_contacts_registry.dart';
import '../features/medications/medication_alarm_engine.dart';
import '../features/medications/medication_alarm_ledger.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/command_parser.dart';
import '../features/voice/conversation_manager.dart';
import '../features/voice/emergency_voice_handler.dart';
import '../features/voice/hardware_cue_bridge.dart';
import '../features/voice/hardware_cue_calibrator.dart';
import '../features/voice/language_detector.dart';
import '../features/voice/voice_engine.dart';
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
import 'health_profile_screen.dart';
import 'layered_lens_studio_screen.dart';
import 'live_sight_screen.dart';
import 'medication_alarm_screen.dart';
import 'medications_screen.dart';
import 'permission_transparency_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'project_box_hub_screen.dart';
import 'smart_health_questionnaire_screen.dart';
import 'system_search_screen.dart';
import 'thumbnail_manage_screen.dart';

class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({super.key, this.listenOnOpen = false});

  final bool listenOnOpen;

  static VoidCallback? _listenIfOpen;

  /// يستدعي الاستماع إن كانت الشاشة ظاهرة، دون تكديس صفحة ثانية.
  static bool requestListenIfOpen() {
    final listen = _listenIfOpen;
    if (listen == null) return false;
    listen();
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

  VoiceEngine get _engine => VoiceEngine.instance;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _engine.addStateListener(_onEngine);
    VoiceControlScreen._listenIfOpen = _cueListen;
    if (widget.listenOnOpen) {
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
    _privacy.screenEarEnabled = false;
    _engine.removeStateListener(_onEngine);
    _engine.stopListening();
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
    setState(() {});
  }

  Color _signalColor(BuildContext context) {
    switch (_engine.state) {
      case VoiceEngineState.listening:
        return Colors.red;
      case VoiceEngineState.speaking:
        return Colors.green;
      case VoiceEngineState.processing:
        return Colors.orange;
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
    if (_engine.state == VoiceEngineState.listening ||
        _engine.state == VoiceEngineState.speaking) {
      return;
    }
    _sessionBusy = true;
    try {
      do {
        if (!mounted) break;
        setState(() {
          _lastText = null;
        });
        HapticFeedback.mediumImpact();
        PermissionTransparencyManager.instance
            .useIfGranted(LifexSensitivePermission.microphone);
        final result = await _engine.startListening();
        if (!mounted) break;
        final heard = result.textResult?.trim() ?? '';
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
      } while (_privacy.screenEarEnabled && mounted);
    } finally {
      _sessionBusy = false;
    }
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
    final profiles = context.read<ActiveProfileController>();
    final detection = await LanguageDetector.instance.detect(text);
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
      final spoken = await _engine.speak(message);
      if (!mounted) return;
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
        final person = profiles.profileById(alarm.profileId);
        if (person != null) {
          MedicationAlarmLedger().replace(
            person,
            const MedicationAlarmEngine()
                .acknowledge(alarm, DateTime.now()),
          );
          profiles.saveActiveProfileChanges();
        }
        await reply(
          VoiceReply(
            ar: 'تم. سكت المنبّه حتى الجرعة التالية. ${alarm.personName} أخذ ${alarm.medicine}.',
            en: 'Taken. The reminder is quiet until the next dose.',
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
            ar: 'لا توجد نتيجة مخبرية مرتبطة بملفك حتى الآن.',
            en: 'No lab result is linked to your profile yet.',
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
            ar: 'سأفتح البحث',
            en: 'Opening search.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SystemSearchScreen()),
            );
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
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح البث الحي على الشاشة. أصف الإطار فقط إن وُجد محرك معتمد.',
            en: 'Opening on-screen live sight. I describe a frame only if a real engine is bound.',
          ),
          thenOpen: () {
            final id = profiles.activeProfileId;
            if (id == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LiveSightScreen(profileId: id)),
            );
          },
        );
        break;
      case VoiceCommandIntent.openLayeredLens:
        _conversation.clear();
        await reply(
          const VoiceReply(
            ar: 'سأفتح عدسة الشرائح. الزوم من العتاد. بلا ×200 ولا تعريض 20 ثانية مختلق.',
            en: 'Opening the slice studio. Zoom is hardware. No fake 200x or 20-second exposure.',
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
            ar: 'سأفتح المراقبة السريرية الظاهرة. بلا تصوير خفي وبلا حفظ صور.',
            en: 'Opening visible clinical watch. No hidden capture and no image archive.',
          ),
          thenOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClinicalWatchScreen()),
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
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.listConnectedSpoken();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.showWheelchair:
        {
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.attachSimulatedWheelchair();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairStatus:
        {
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.wheelchairStatusSpoken();
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairMoveForward:
        {
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('MOVE_FORWARD');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairStop:
        {
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('STOP');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairEmergencyStop:
        {
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('EMERGENCY_STOP');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.wheelchairReadBattery:
        {
          final runtime = context.read<LifexDeviceRuntime>();
          final o = await runtime.runWheelchairAction('READ_BATTERY');
          if (!mounted) return;
          await reply(VoiceReply(ar: o.spokenAr, en: o.spokenEn));
        }
        break;
      case VoiceCommandIntent.confirmDeviceMotion:
        {
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
          final profile =
              context.read<ActiveProfileController>().activeProfile;
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
          final profile =
              context.read<ActiveProfileController>().activeProfile;
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
          final balOutcome = await context
              .read<LioSensitiveActionEntry>()
              .readWalletBalances(
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
                ar:
                    'توقف عرض الرصيد عند LIO (${balOutcome.decision.wireDecision}).',
                en: 'Balance blocked by LIO.',
              ),
            );
            break;
          }
          final bal = balOutcome.value!;
          await reply(
            VoiceReply(
              ar:
                  'الرصيد المتاح ${(bal.availableMinor / 100).toStringAsFixed(2)} دولار. '
                  'المعلّق ${(bal.pendingMinor / 100).toStringAsFixed(2)}. '
                  'المزوّد Sandbox إن لم يُربط مزود إنتاجي.',
              en:
                  'Available ${(bal.availableMinor / 100).toStringAsFixed(2)}. '
                  'Pending ${(bal.pendingMinor / 100).toStringAsFixed(2)}.',
            ),
          );
        }
        break;
      case VoiceCommandIntent.unknown:
        await reply(
          const VoiceReply(
            ar: 'لم أفهم الأمر. قل ليفكس ثم: ملفي الصحي، أدويتي، مركز الأجهزة، أو أظهر الكرسي.',
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
    return Scaffold(
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
                    child: Text('سمعت: $_lastText',
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
              if (_replyAr != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('الرد: $_replyAr', textAlign: TextAlign.center),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
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
              FilledButton.icon(
                onPressed: listening || speaking ? null : _listen,
                icon: Icon(listening ? Icons.hearing : Icons.mic),
                label: Text(
                  listening
                      ? 'جارٍ الاستماع والتسجيل...'
                      : speaking
                          ? 'جارٍ الرد...'
                          : 'تحدث الآن',
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
                subtitle: const Text('لا يُحفظ مقطع صوتي. النص يظهر هنا فقط إن فعّلت هذا.'),
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
                            DropdownMenuItem(value: 3, child: Text('ثلاث مرات')),
                            DropdownMenuItem(value: 4, child: Text('أربع مرات')),
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
    );
  }
}
