/// زر الترجمة على كل صفحة، مع مراقبة المنبهات ما دام التطبيق مفتوحاً.
library lifex_ai.widgets.lifex_chrome;

import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../features/clock/speaking_alarm_book.dart';
import '../features/directory/directory_alarm.dart';
import '../screens/professional_directory_screen.dart';
import 'lifex_language_button.dart';

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
      ],
    );
  }
}
