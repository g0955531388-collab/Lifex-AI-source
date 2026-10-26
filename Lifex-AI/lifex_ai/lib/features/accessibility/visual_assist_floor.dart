/// أرضية واحدة للمساعد البصري. النظام القديم وSPOT لا يعملان معاً.
/// أخذ الأرضية يُغلق الصفحة الأخرى في الإطار التالي.
library lifex_ai.features.accessibility.visual_assist_floor;

import 'package:flutter/widgets.dart';

enum VisualAssistFloor { legacy, spot }

class VisualAssistFloorSwitch {
  VisualAssistFloorSwitch._();

  static VisualAssistFloor? active;
  static Widget Function(String profileId)? legacyPage;
  static Widget Function()? spotPage;

  static final List<void Function(VisualAssistFloor floor)> _listeners = [];

  static void bind({
    required Widget Function(String profileId) legacyPage,
    required Widget Function() spotPage,
  }) {
    VisualAssistFloorSwitch.legacyPage = legacyPage;
    VisualAssistFloorSwitch.spotPage = spotPage;
  }

  static void listen(void Function(VisualAssistFloor floor) listener) {
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);
  }

  static void unlisten(void Function(VisualAssistFloor floor) listener) {
    _listeners.remove(listener);
  }

  static void take(VisualAssistFloor floor) {
    active = floor;
    final copy = List<void Function(VisualAssistFloor)>.of(_listeners);
    for (final listener in copy) {
      listener(floor);
    }
  }

  static void debugReset() {
    active = null;
    legacyPage = null;
    spotPage = null;
    _listeners.clear();
  }
}

/// يزيل مسار الصفحة التي خسرت الأرضية دون لمس الصفحة التي أصبحت الحالية.
void handOffVisualAssist(
  BuildContext context, {
  required bool Function() mounted,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted() || !context.mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  });
}
