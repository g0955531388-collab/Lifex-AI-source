import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SoundSystemPage extends StatefulWidget {
  const SoundSystemPage({Key? key}) : super(key: key);

  @override
  State<SoundSystemPage> createState() => _SoundSystemPageState();
}

class _SoundSystemPageState extends State<SoundSystemPage> {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('ar');
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _speak() async {
    if (_textEditingController.text.isNotEmpty) {
      await _flutterTts.speak(_textEditingController.text);
    }
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام التحكم الصوتي الذكي'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textEditingController,
              decoration: const InputDecoration(
                labelText: 'أدخل النص',
                hintText: 'اكتب هنا ليتم تحويله إلى صوت...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSpeaking ? _stop : _speak,
                  icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                  label: Text(_isSpeaking ? 'إيقاف الصوت' : 'تشغيل الصوت'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}