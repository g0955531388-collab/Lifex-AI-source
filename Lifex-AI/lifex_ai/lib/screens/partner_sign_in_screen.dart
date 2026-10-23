/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: partner_sign_in_screen.dart
/// طلب الدخول بحساب لايفكس إلى موقع يختاره المستخدم، ما عدا الإباحي.
/// =============================================================
library lifex_ai.screens.partner_sign_in_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/outreach/partner_sign_in_policy.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../widgets/honesty_banner.dart';

class PartnerSignInScreen extends StatefulWidget {
  const PartnerSignInScreen({super.key});

  @override
  State<PartnerSignInScreen> createState() => _PartnerSignInScreenState();
}

class _PartnerSignInScreenState extends State<PartnerSignInScreen> {
  final _destination = TextEditingController();
  PartnerSignInDecision? _decision;

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  void _evaluate() {
    setState(() {
      _decision = const PartnerSignInPolicy().evaluate(_destination.text);
    });
  }

  String _accountCard(String? fullName, String? lifexId) {
    final profile = context.read<ActiveProfileController>().activeProfile;
    final identity = profile == null
        ? null
        : HealthIdentityManager.instance.getByProfileId(profile.profileId);
    String line(String label, String? value) {
      final text = value?.trim() ?? '';
      return '$label: ${text.isEmpty ? 'فارغ، يكتبه صاحب الحساب' : text}';
    }

    return [
      line('الاسم', fullName),
      line('البريد', identity?.email),
      line('الهاتف', identity?.phoneNumber),
      line('معرّف لايفكس', lifexId),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    final lifexId = profile == null
        ? null
        : HealthIdentityManager.instance.getByProfileId(profile.profileId)?.lifexId;

    return Scaffold(
      appBar: AppBar(title: const Text('الدخول بحساب لايفكس')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'حساب لايفكس الذي يملأه صاحب الحساب هو حساب التسجيل في أي موقع غير إباحي. '
                'الجلسة على الموقع تُفتح فقط إذا كان شريكاً. لا كلمة سر لموقع آخر، ولا ملف صحي.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(
              labelText: 'عنوان الموقع',
              hintText: 'مثال: chatgpt.com أو عيادة شريكة',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _evaluate(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _evaluate,
            child: const Text('التحقق من حق الدخول'),
          ),
          if (_decision != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_decision!.messageAr),
              ),
            ),
          ],
          if (_decision?.offersLocalAccount == true) ...[
            const SizedBox(height: 8),
            ListTile(
              title: const Text('حساب التسجيل'),
              subtitle: Text(_accountCard(profile?.fullName, lifexId)),
              trailing: IconButton(
                tooltip: 'نسخ حساب التسجيل',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: _accountCard(profile?.fullName, lifexId),
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نُسخ حساب التسجيل. بلا ملف صحي وبلا كلمة سر.'),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
