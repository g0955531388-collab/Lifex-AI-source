import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'blind_camera.dart';

class SmartPage extends StatefulWidget {
  const SmartPage({Key? key}) : super(key: key);

  @override
  State<SmartPage> createState() => _SmartPageState();
}

class _SmartPageState extends State<SmartPage> {
  late WebSocketChannel channel;
  final TextEditingController _controller = TextEditingController();
  final List<String> _syncMessages = [];

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(
      Uri.parse('wss://echo.websocket.events'),
    );

    channel.stream.listen((message) {
      setState(() {
        _syncMessages.add(message.toString());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة التحكم الذكية'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('فتح كاميرا المساعد الذكي'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BlindCameraPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _syncMessages.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_syncMessages[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _controller.dispose();
    super.dispose();
  }
}