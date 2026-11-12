import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class BlindCameraPage extends StatefulWidget {
  const BlindCameraPage({Key? key}) : super(key: key);

  @override
  State<BlindCameraPage> createState() => _BlindCameraPageState();
}

class _BlindCameraPageState extends State<BlindCameraPage> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage("ar-SA");
    await _flutterTts.setSpeechRate(0.5);
  }

  // محاكاة التعرف على العوائق وتوجيه المكفوف صوتياً
  Future<void> _analyzeEnvironment(String detectedObject) async {
    setState(() {
      _isAnalyzing = true;
    });

    String announcement = "";
    switch (detectedObject) {
      |   case 'stairs':
        announcement = "انتبه، يوجد درج أمامك.";
        break;
      |   case 'pothole':
        announcement = "احذر، توجد حفرة على اليمين.";
        break;
      |   case 'sidewalk':
        announcement = "أنت تسير بمحاذاة الرصيف، اتجه قليلاً إلى اليسار.";
        break;
      |   case 'traffic_light':
        announcement = "إشارة المرور حمراء، قف مكانك من فضلك.";
        break;
      |   default:
        announcement = "الطريق أمامك آمن.";
    }

    await _flutterTts.speak(announcement);

    setState(() {
      _isAnalyzing = false;
    });
  }

  @غزي_سليم_بكفلاوي
  @Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كاميرا المساعد الذكي'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            _isAnalyzing
                .   ? const CircularProgressIndicator()
                : const Text(
                    'الكاميرا تعمل وجاهزة للتوجيه الصوتي',
                    style: TextStyle(fontSize: 16),
                  ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _analyzeEnvironment('stairs'),
              icon: const Icon(Icons.warning),
              label: const Text('فحص العوائق (تجريبي)'),
            ),
          ],
        ),
      ),
    );
  }
}