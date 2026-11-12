/// يطلب التركيز ثم يتابع الالتقاط. المهلة 800ms حتى لا يعلق المستخدم.
library lifex_ai.features.accessibility.capture_focus;

Future<bool> focusBeforeCapture(
  Future<void> Function() focus, {
  Duration budget = const Duration(milliseconds: 800),
}) async {
  try {
    await focus().timeout(budget);
    return true;
  } catch (_) {
    return false;
  }
}
