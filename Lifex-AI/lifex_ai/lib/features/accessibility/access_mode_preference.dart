/// وضع الوصول يُحفظ على الجهاز. لا يمنح أذونات Android ولا يشغّل TalkBack.
library lifex_ai.features.accessibility.access_mode_preference;

import 'package:shared_preferences/shared_preferences.dart';

class AccessModeDecision {
  const AccessModeDecision({
    required this.enabled,
    required this.userChose,
  });

  final bool enabled;
  final bool userChose;
}

class AccessModePreference {
  const AccessModePreference._();

  static const enabledKey = 'lifex_access_mode_enabled_v1';
  static const userChoseKey = 'lifex_access_mode_user_chose_v1';

  /// الملف الحالي يجمع المكفوف وضعف البصر الشديد في [HealthProfile.isBlind].
  static bool profileNeedsAccess({required bool isBlind}) => isBlind;

  static const requestsPlatformPermissions = false;
  static const enablesTalkBackSilently = false;

  static AccessModeDecision decide({
    required bool profileNeedsAccess,
    required bool? storedEnabled,
    required bool userChose,
  }) {
    if (userChose && storedEnabled != null) {
      return AccessModeDecision(enabled: storedEnabled, userChose: true);
    }
    if (profileNeedsAccess) {
      return const AccessModeDecision(enabled: true, userChose: false);
    }
    return AccessModeDecision(
      enabled: storedEnabled ?? false,
      userChose: false,
    );
  }

  static String title({required bool english}) =>
      english ? 'Accessibility mode' : 'وضع الوصول';

  static String subtitle({required bool english}) => english
      ? 'Stays on until you change it. It does not grant camera or microphone permission and does not turn TalkBack on.'
      : 'يبقى مفعّلاً حتى تغيّره. لا يمنح إذن الكاميرا أو الميكروفون ولا يشغّل TalkBack.';
}

class AccessModeMemory {
  bool? enabled;
  bool userChose = false;

  AccessModeDecision load({required bool profileNeedsAccess}) {
    return AccessModePreference.decide(
      profileNeedsAccess: profileNeedsAccess,
      storedEnabled: enabled,
      userChose: userChose,
    );
  }

  AccessModeDecision saveUserChoice(bool enabled) {
    this.enabled = enabled;
    userChose = true;
    return AccessModeDecision(enabled: enabled, userChose: true);
  }

  Future<void> writePrefs(SharedPreferences prefs) async {
    if (enabled == null) {
      await prefs.remove(AccessModePreference.enabledKey);
    } else {
      await prefs.setBool(AccessModePreference.enabledKey, enabled!);
    }
    await prefs.setBool(AccessModePreference.userChoseKey, userChose);
  }

  void readPrefs(SharedPreferences prefs) {
    enabled = prefs.getBool(AccessModePreference.enabledKey);
    userChose = prefs.getBool(AccessModePreference.userChoseKey) ?? false;
  }
}
