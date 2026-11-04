import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifex_ai/core/app_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language choice is persisted for the next app launch', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppLocaleController.instance;

    await controller.initialize(preferences);
    final selected = controller.isArabic ? 'en' : 'ar';
    await controller.setLanguage(selected);

    expect(controller.languageCode, selected);
    expect(preferences.getString('lifex_app_language_v1'), selected);

    await controller.setLanguage('system');
    expect(controller.selection, 'system');
    expect(preferences.getString('lifex_app_language_v1'), 'system');
  });
}
