import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/ai/ai_service_router.dart';
import 'package:lifex_ai/features/ai/unified_ai_hub_gateway.dart';

class _MemoryStore implements SecureCredentialStore {
  final saved = <String, String>{};

  @override
  Future<void> deleteCredential(String key) async {
    saved.remove(key);
  }

  @override
  Future<String?> readCredential(String key) async => saved[key];

  @override
  Future<void> saveCredential(String key, String value) async {
    saved[key] = value;
  }
}

void main() {
  test('اختيار نموذج توليد ويتجاهل التضمين', () {
    expect(
      chooseGeminiModelName(const [
        {
          'name': 'models/embedding-001',
          'supportedGenerationMethods': ['embedContent'],
        },
        {
          'name': 'models/gemini-2.5-flash',
          'supportedGenerationMethods': ['generateContent'],
        },
      ]),
      'models/gemini-2.5-flash',
    );
    expect(
      chooseOpenAiModelId(const [
        {'id': 'whisper-1'},
        {'id': 'gpt-4o-mini'},
      ]),
      'gpt-4o-mini',
    );
  });

  test('إعادة التشغيل تعيد الربط وفشل الحذف يبقيه', () async {
    final store = _MemoryStore();
    final hub = UnifiedAiHubGateway(credentialStore: store);
    final saved = await hub.connectAccount(
      profileId: 'profile-1',
      provider: ExternalAiProvider.gemini,
      accountLabel: 'حسابي الشخصي',
      apiKeyOrToken: 'live-key',
    );
    expect(saved, isTrue);

    final restored = UnifiedAiHubGateway(credentialStore: store);
    await restored.restoreLinkedAccounts();
    expect(restored.connectedAccountsFor('profile-1'), hasLength(1));
    expect(
      await restored.credentialFor(
        profileId: 'profile-1',
        provider: ExternalAiProvider.gemini,
      ),
      'live-key',
    );
  });
}
