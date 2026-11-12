/// زر الترجمة على كل صفحة، مع مراقبة المنبهات ما دام التطبيق مفتوحاً.
library lifex_ai.widgets.lifex_chrome;

import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../core/app_config.dart';
import '../features/clock/speaking_alarm_book.dart';
import '../features/directory/directory_alarm.dart';
import '../screens/professional_directory_screen.dart';
import 'lifex_language_button.dart';
import 'lifex_text.dart';

class LifexChrome extends StatefulWidget {
  const LifexChrome({super.key, required this.child});

  final Widget child;

  @override
  State<LifexChrome> createState() => _LifexChromeState();
}

class _LifexChromeState extends State<LifexChrome> {
  @override
  void initState() {
    super.initState();
    SpeakingAlarmWatch.instance.start();
    DirectoryAlarmWatch.instance.onSearch = (alarm) {
      final nav = LifexNavigator.key.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ProfessionalDirectoryScreen(
            initialQuery: alarm.targetNameOrKeyword,
            highlightReason: alarm.reason,
          ),
        ),
      );
    };
    DirectoryAlarmWatch.instance.start();
  }

  @override
  void dispose() {
    SpeakingAlarmWatch.instance.stop();
    DirectoryAlarmWatch.instance.onSearch = null;
    DirectoryAlarmWatch.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const PositionedDirectional(
          top: 0,
          end: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(6),
              child: LifexLanguageButton(),
            ),
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: SpeakingAlarmWatch.instance.ringing,
          builder: (context, name, _) {
            if (name == null) return const SizedBox.shrink();
            return PositionedDirectional(
              start: 12,
              end: 12,
              bottom: 12,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFFB00020),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LifexText(
                            name,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFB00020),
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: SpeakingAlarmWatch.instance.stopRinging,
                          icon: const Icon(Icons.stop),
                          label: LifexText(
                            lifexUi('إيقاف التنبيه', 'Stop alarm'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
