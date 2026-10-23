/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: device_text_to_speech_provider.dart
/// نطق حقيقي عبر محرّك الجهاز. بلا صوت وهمي عند الفشل.
/// =============================================================
library lifex_ai.features.voice.device_text_to_speech_provider;

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'assistant_session.dart';
import 'text_to_speech_manager.dart';
import 'voice_engine.dart';
import 'voice_locale_policy.dart';

bool ttsCallSpoke(Object? result) {
  if (result == 1 || result == true) return true;
  final text = result?.toString();
  return text == '1';
}

class DeviceTextToSpeechProvider implements TextToSpeechProvider {
  DeviceTextToSpeechProvider({
    FlutterTts? tts,
    VoiceLocalePolicy localePolicy = const VoiceLocalePolicy(),
  })  : _tts = tts ?? FlutterTts(),
        _localePolicy = localePolicy;

  final FlutterTts _tts;
  final VoiceLocalePolicy _localePolicy;
  List<String> _cachedLanguages = const [];
  String? _lastBlockAr;

  @override
  String? get lastBlockAr => _lastBlockAr;

  @override
  Future<bool> get isLanguageSupported async {
    try {
      await _languages();
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> speak(String text, SpeechSettings settings) async {
    final spoken = text.trim();
    _lastBlockAr = null;
    if (spoken.isEmpty) return false;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(AssistantSession.instance.outputVolume.clamp(0.2, 1.0));
      final languages = await _languages();
      final locale = languages.isEmpty
          ? _localePolicy.preferredListenCode()
          : _localePolicy.speakCodeForText(
              text: spoken,
              recognizedLocaleId: VoiceEngine.instance.activeLocaleId,
              availableTts: languages,
            );
      final wantsArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(spoken);
      final hasArabicVoice = languages.any(
        (item) => item.toLowerCase().replaceAll('_', '-').startsWith('ar'),
      );
      if (wantsArabic && languages.isNotEmpty && !hasArabicVoice) {
        _lastBlockAr =
            'بيانات النطق العربي غير مثبتة على هذا الجهاز. النص ظاهر على الشاشة، ولم أختلق سماعاً.';
        return false;
      }
      VoiceEngine.instance.activeLocaleId = locale;
      VoiceEngine.instance.signalAr('أردّ بالصوت — $locale');
      await _applyLocale(locale, languages);
      await _tts.setSpeechRate(settings.speechRate.clamp(0.2, 1.0));
      await _tts.setPitch(settings.pitch.clamp(0.5, 2.0));
      final result = await _tts
          .speak(spoken, focus: true)
          .timeout(const Duration(seconds: 45), onTimeout: () => 0);
      return ttsCallSpoke(result);
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyLocale(String locale, List<String> languages) async {
    final primary = locale.replaceAll('_', '-');
    final applied = await _tts.setLanguage(primary);
    if (applied == 1) return;
    final lang = primary.split('-').first;
    for (final item in languages) {
      if (item.toLowerCase().startsWith(lang.toLowerCase())) {
        await _tts.setLanguage(item.replaceAll('_', '-'));
        return;
      }
    }
    await _tts.setLanguage(lang);
  }

  @override
  Future<void> stop() => _tts.stop();

  Future<List<String>> _languages() async {
    if (_cachedLanguages.isNotEmpty) return _cachedLanguages;
    try {
      final raw = await _tts.getLanguages;
      if (raw is List) {
        _cachedLanguages = raw.map((item) => item.toString()).toList();
      }
    } catch (_) {
      _cachedLanguages = const [];
    }
    return _cachedLanguages;
  }
}
