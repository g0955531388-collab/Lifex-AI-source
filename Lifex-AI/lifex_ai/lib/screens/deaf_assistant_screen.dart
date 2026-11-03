/// Lifex-AI — مساعد الصم وضعاف السمع.
/// يعرض الكلام الذي يلتقطه التعرف الصوتي كنص حي على الجهاز.
/// لا يحفظ الصوت أو النص تلقائياً ولا يعمل في الخلفية.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class DeafAssistantScreen extends StatefulWidget {
  const DeafAssistantScreen({super.key});

  @override
  State<DeafAssistantScreen> createState() => _DeafAssistantScreenState();
}

class _DeafAssistantScreenState extends State<DeafAssistantScreen> {
  final SpeechToText _speech = SpeechToText();
  final StringBuffer _transcript = StringBuffer();
  String _partial = '';
  String _status = 'اضغط بدء الاستماع لتحويل الكلام إلى كتابة.';
  String? _localeId;
  bool _initialized = false;
  bool _listening = false;
  bool _keepListening = false;
  bool _restartQueued = false;
  bool _busy = false;

  String get _visibleText {
    final completed = _transcript.toString().trim();
    if (_partial.trim().isEmpty) return completed;
    return completed.isEmpty ? _partial : '$completed\n$_partial';
  }

  @override
  void dispose() {
    _keepListening = false;
    unawaited(_speech.stop());
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _listening) return;
    _busy = true;
    try {
      final permission = await Permission.microphone.request();
      if (!mounted) return;
      if (!permission.isGranted) {
        setState(() => _status = 'إذن الميكروفون غير متاح. فعّله من إعدادات الجهاز.');
        return;
      }

      if (!_initialized) {
        _initialized = await _speech.initialize(
          onStatus: _onStatus,
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _status = 'تعذّر التعرف على الكلام: ${error.errorMsg}';
              _listening = false;
            });
            if (_keepListening && !error.permanent) _queueRestart();
          },
        );
      }
      if (!_initialized) {
        setState(() => _status = 'خدمة تحويل الكلام إلى نص غير متاحة على هذا الجهاز.');
        return;
      }

      _localeId ??= await _chooseLocale();
      _keepListening = true;
      await _listenSession();
    } catch (error) {
      if (mounted) setState(() => _status = 'تعذّر بدء الاستماع: $error');
    } finally {
      _busy = false;
    }
  }

  Future<String?> _chooseLocale() async {
    final locales = await _speech.locales();
    final preferred = Localizations.localeOf(context).languageCode.toLowerCase();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('$preferred-') ||
          locale.localeId.toLowerCase() == preferred) {
        return locale.localeId;
      }
    }
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('ar-')) return locale.localeId;
    }
    return _speech.systemLocale()?.localeId ??
        (locales.isEmpty ? null : locales.first.localeId);
  }

  Future<void> _listenSession() async {
    if (!mounted || !_keepListening || _listening) return;
    setState(() {
      _listening = true;
      _status = 'أستمع الآن — سيظهر الكلام كنص على الشاشة.';
    });
    await _speech.listen(
      localeId: _localeId,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _partial = result.recognizedWords;
          if (result.finalResult && _partial.trim().isNotEmpty) {
            final next = _partial.trim();
            final current = _transcript.toString();
            if (current.isEmpty || !current.endsWith(next)) {
              if (current.isNotEmpty) _transcript.write('\n');
              _transcript.write(next);
            }
            _partial = '';
          }
        });
      },
    );
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == 'listening') {
      setState(() {
        _listening = true;
        _status = 'الاستماع نشط — الكلام يظهر هنا مباشرة.';
      });
    } else if (status == 'done' || status == 'notListening') {
      setState(() => _listening = false);
      if (_keepListening) _queueRestart();
      else setState(() => _status = 'توقف الاستماع.');
    }
  }

  void _queueRestart() {
    if (_restartQueued || !_keepListening || !mounted) return;
    _restartQueued = true;
    unawaited(Future<void>.delayed(const Duration(milliseconds: 350), () async {
      _restartQueued = false;
      if (!mounted || !_keepListening || _listening || _busy) return;
      try {
        await _listenSession();
      } catch (error) {
        if (mounted) {
          setState(() {
            _keepListening = false;
            _status = 'توقف الاستماع بسبب خطأ: $error';
          });
        }
      }
    }));
  }

  Future<void> _stop() async {
    _keepListening = false;
    _restartQueued = false;
    await _speech.stop();
    if (mounted) {
      setState(() {
        _listening = false;
        _status = 'توقف الاستماع. النص الظاهر لم يُحفظ في ملف.';
      });
    }
  }

  void _clear() {
    _transcript.clear();
    setState(() => _partial = '');
  }

  Future<void> _copy() async {
    final text = _visibleText.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ النص.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _visibleText;
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد الصم وضعاف السمع')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(_status, style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _listening || _busy ? null : _start,
                      icon: const Icon(Icons.mic),
                      label: const Text('بدء الاستماع'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _listening || _keepListening ? _stop : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('إيقاف'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: text.trim().isEmpty ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ النص'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: text.isEmpty ? null : _clear,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('مسح النص'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text.isEmpty ? 'سيظهر الكلام المسموع هنا...' : text,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'يُستخدم الميكروفون أثناء فتح هذه الشاشة وبعد ضغطك على بدء الاستماع فقط. لا يُسجّل التطبيق ملفاً صوتياً ولا يحفظ النص تلقائياً. دقة التفريغ تعتمد على خدمة التعرف في الجهاز.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
