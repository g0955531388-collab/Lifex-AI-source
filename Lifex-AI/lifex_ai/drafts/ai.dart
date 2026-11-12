import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class AiEngine {
  WebSocketChannel? _channel;

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen((message) {
      handleMessage(message);
    });
  }

  void sendFrame(List<int> frameBytes) {
    // إرسال إطارات الفيديو كمرفقات Base64 أو بيانات ثنائية إلى نموذج Gemini Live API
    _channel?.sink.add(base64Encode(frameBytes));
  }

  void handleMessage(dynamic message) {
    // تحليل الردود والتعليمات الواردة من النموذج
  }

  void dispose() {
    _channel?.sink.close();
  }
}