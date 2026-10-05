/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: ai_hub_screen.dart
/// ربط حسابات AI الخارجية يمر عبر LioSensitiveActionEntry → LIO فقط.
/// =============================================================
library lifex_ai.screens.ai_hub_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/ai/unified_ai_hub_gateway.dart';
import 'ai_agent_screen.dart';
import 'partner_sign_in_screen.dart';

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  bool _isConnecting = false;
  String? _statusMessageAr;
  List<ConnectedAiAccount> _connected = const [];

  static const Map<ExternalAiProvider, String> _providerLabelsAr = {
    ExternalAiProvider.gemini: 'Gemini',
    ExternalAiProvider.chatgpt: 'ChatGPT',
    ExternalAiProvider.claude: 'Claude',
    ExternalAiProvider.custom: 'محرك آخر',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshConnected());
  }

  LioGatewayRequest _req({
    required String action,
    LioActionRisk risk = LioActionRisk.medium,
  }) {
    return LioGatewayRequest(
      requestId: 'hub_${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}',
      correlationId: 'hub_${widget.profileId}',
      identityAccountId: widget.profileId,
      purpose: 'settings',
      requestedAction: action,
      dataScope: 'settings_local',
      sensitivity: LioDataSensitivity.operational,
      consent: const LioConsentContext(
        consentGranted: true,
        purposeAligned: true,
      ),
      riskLevel: risk,
      timestamp: DateTime.now().toUtc(),
      authenticated: true,
      authorized: true,
      minimumNecessarySatisfied: true,
    );
  }

  Future<void> _refreshConnected() async {
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.listConnectedAiAccounts(
      gatewayRequest: _req(action: 'ai_hub_list_accounts', risk: LioActionRisk.low),
      profileId: widget.profileId,
    );
    if (!mounted) return;
    if (!outcome.executed) {
      setState(() {
        _statusMessageAr =
            'توقف عرض الحسابات عند LIO (${outcome.decision.wireDecision}).';
        _connected = const [];
      });
      return;
    }
    setState(() => _connected = outcome.value ?? const []);
  }

  Future<void> _showConnectDialog(ExternalAiProvider provider) async {
    final keyController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ربط حساب ${_providerLabelsAr[provider]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل مفتاح API الخاص بك. يُحفظ على هذا الجهاز فقط. '
              'لن أختبره مع ${_providerLabelsAr[provider]} حتى يوجد اتصال حقيقي بالمحرك.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'مفتاح API',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ربط الحساب'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    if (keyController.text.trim().isEmpty) {
      setState(() => _statusMessageAr = 'يُرجى إدخال مفتاح صالح.');
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessageAr = null;
    });

    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.connectExternalAiAccount(
      gatewayRequest: _req(action: 'ai_hub_connect_account'),
      profileId: widget.profileId,
      provider: provider,
      accountLabel: 'حسابي الشخصي',
      apiKeyOrToken: keyController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      if (!outcome.executed) {
        _statusMessageAr =
            'توقف الربط عند LIO (${outcome.decision.wireDecision}): ${outcome.decision.reasonAr}';
      } else if (outcome.value == true) {
        _statusMessageAr =
            'حُفظ مفتاح ${_providerLabelsAr[provider]} على هذا الجهاز. '
            'لم يُختبر مع المحرك بعد. التخزين الحالي في الذاكرة وليس خزنة مشفّرة.';
      } else {
        _statusMessageAr = 'تعذّر حفظ المفتاح على هذا الجهاز.';
      }
    });
    await _refreshConnected();
  }

  Future<void> _disconnect(ExternalAiProvider provider) async {
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.disconnectExternalAiAccount(
      gatewayRequest: _req(action: 'ai_hub_disconnect_account'),
      profileId: widget.profileId,
      provider: provider,
    );
    if (!mounted) return;
    setState(() {
      _statusMessageAr = outcome.executed
          ? 'تم فصل حساب ${_providerLabelsAr[provider]}.'
          : 'توقف الفصل عند LIO (${outcome.decision.wireDecision}).';
    });
    await _refreshConnected();
  }

  @override
  Widget build(BuildContext context) {
    final connectedProviders = _connected.map((a) => a.provider).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('مركز الذكاء الاصطناعي')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'حساب لايفكس لا يسجّل دخولاً نيابة عنك في Gemini أو ChatGPT أو غيرها. '
              'إن حفظت مفتاحك فهو على هذا الجهاز فقط، ولم يُختبر مع المحرك حتى يوجد اتصال حقيقي. '
              'طلب الدخول بأي موقع غير إباحي حقّك؛ التنفيذ للشركاء فقط.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PartnerSignInScreen(),
                  ),
                );
              },
              child: const Text('طلب الدخول بحساب لايفكس لموقع تختاره'),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('الوكيل الذكي'),
                subtitle: const Text(
                  'محادثة مباشرة أو تخطيط متعدد الخطوات فوق المعرفة الطبية',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AiAgentScreen(profileId: widget.profileId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_statusMessageAr != null) ...[
              Text(_statusMessageAr!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],
            for (final provider in [
              ExternalAiProvider.gemini,
              ExternalAiProvider.chatgpt,
              ExternalAiProvider.claude,
            ])
              Card(
                child: ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text(_providerLabelsAr[provider]!),
                  subtitle: Text(
                    connectedProviders.contains(provider) ? 'متصل' : 'غير متصل',
                    style: TextStyle(
                      color: connectedProviders.contains(provider)
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  trailing: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : connectedProviders.contains(provider)
                          ? OutlinedButton(
                              onPressed: () => _disconnect(provider),
                              child: const Text('فصل'),
                            )
                          : FilledButton(
                              onPressed: () => _showConnectDialog(provider),
                              child: const Text('ربط'),
                            ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
