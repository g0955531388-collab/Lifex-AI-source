/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: personal_shelf_screen.dart
/// تنزيل كتاب نصي إلى الجهاز، قراءته، إبقاؤه أو حذفه.
/// =============================================================
library lifex_ai.screens.personal_shelf_screen;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/education/personal_shelf.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';

class PersonalShelfScreen extends StatefulWidget {
  const PersonalShelfScreen({super.key});

  @override
  State<PersonalShelfScreen> createState() => _PersonalShelfScreenState();
}

class _PersonalShelfScreenState extends State<PersonalShelfScreen> {
  final _url = TextEditingController();
  final _downloader = PersonalShelfDownloader();
  bool _busy = false;
  String? _statusAr;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  PersonalShelfStore? _store() {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return null;
    return PersonalShelfStore(profile);
  }

  Future<void> _fetch({String? rawUrl}) async {
    final store = _store();
    final controller = context.read<ActiveProfileController>();
    if (store == null) {
      setState(() => _statusAr = 'افتح ملفاً صحياً أولاً.');
      return;
    }
    final text = (rawUrl ?? _url.text).trim();
    final uri = Uri.tryParse(text);
    if (uri == null) {
      setState(() => _statusAr = 'الرابط غير صالح.');
      return;
    }
    setState(() {
      _busy = true;
      _statusAr = 'يتصل الآن…';
    });
    final result = await _downloader.fetch(uri);
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _busy = false;
        _statusAr = result.errorAr;
      });
      return;
    }
    try {
      await store.keep(
        sourceUrl: uri.toString(),
        titleAr: result.titleAr,
        body: result.body,
        bytes: result.bytes,
      );
      controller.saveActiveProfileChanges();
      setState(() {
        _busy = false;
        _statusAr =
            'حُفظ على الجهاز (${result.bytes} بايت). يبقى في مكتبتك حتى تحذفه.';
      });
    } catch (error) {
      setState(() {
        _busy = false;
        _statusAr = error.toString();
      });
    }
  }

  Future<void> _open(ShelfVolumeRecord record) async {
    final store = _store();
    if (store == null) return;
    final body = await store.readBody(record);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShelfReaderScreen(titleAr: record.titleAr, body: body),
      ),
    );
  }

  Future<void> _drop(ShelfVolumeRecord record) async {
    final store = _store();
    final controller = context.read<ActiveProfileController>();
    if (store == null) return;
    final profileId = controller.activeProfileId ?? 'local';
    final entry = context.read<LioSensitiveActionEntry>();
    final outcome = await entry.authorizeThenRun<void>(
      request: LioGatewayRequest(
        requestId:
            'shelf_del_${record.id}_${DateTime.now().millisecondsSinceEpoch}',
        correlationId: 'shelf_$profileId',
        identityAccountId: profileId,
        purpose: 'education',
        requestedAction: 'delete_personal_shelf_item',
        dataScope: 'profile_basic',
        sensitivity: LioDataSensitivity.personal,
        consent: const LioConsentContext(
          consentGranted: true,
          purposeAligned: true,
        ),
        riskLevel: LioActionRisk.medium,
        timestamp: DateTime.now().toUtc(),
        authenticated: true,
        authorized: true,
        minimumNecessarySatisfied: true,
      ),
      run: () async {
        await store.drop(record.id);
      },
    );
    if (!outcome.executed || !mounted) return;
    controller.saveActiveProfileChanges();
    setState(() => _statusAr = 'حُذف من الجهاز ومن الرف.');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    final kept =
        profile == null ? const <ShelfVolumeRecord>[] : PersonalShelfStore(profile).kept();
    return Scaffold(
      appBar: AppBar(title: const Text('رفّ التحميل الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppConstants.studioBannerCredit,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const HonestyBanner(
            messageAr:
                'التنزيل يحفظ نصاً بعد ردّ حقيقي من https. الكتب المدمجة في الرواق لا تُحذف لأنها جزء من التطبيق. ما تنزّله أنت يُحذف بطلبك. على الويب يُحفظ النص داخل الملف إن كان صغيراً.',
          ),
          if (kIsWeb)
            const HonestyBanner(
              messageAr: 'المتصفح لا يفتح مجلد المستندات. استخدم تطبيقاً على الجهاز للملفات الكبيرة.',
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'رابط https لصفحة نصية أو HTML',
              hintText: 'https://…',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : () => _fetch(),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(_busy ? 'ينزّل…' : 'تنزيل إلى الجهاز'),
          ),
          if (_statusAr != null) ...[
            const SizedBox(height: 8),
            Text(_statusAr!),
          ],
          const SizedBox(height: 16),
          Text('مقترحات ملكية عامة للتجربة',
              style: Theme.of(context).textTheme.titleMedium),
          for (final hint in ShelfDownloadPolicy.hints)
            Card(
              child: ListTile(
                title: Text(hint.titleAr),
                subtitle: Text(hint.noteAr),
                trailing: const Icon(Icons.download_outlined),
                onTap: _busy
                    ? null
                    : () {
                        _url.text = hint.url;
                        _fetch(rawUrl: hint.url);
                      },
              ),
            ),
          const SizedBox(height: 16),
          Text('في مكتبتك (${kept.length})',
              style: Theme.of(context).textTheme.titleMedium),
          if (kept.isEmpty)
            const Text('لا كتب منزّلة بعد. الكتب المدمجة تُقرأ من رواق المعرفة.'),
          for (final record in kept)
            Card(
              child: ListTile(
                title: Text(record.titleAr),
                subtitle: Text(
                  '${record.bytes} بايت\n${record.sourceUrl}',
                ),
                isThreeLine: true,
                onTap: () => _open(record),
                trailing: IconButton(
                  tooltip: 'حذف من الجهاز',
                  onPressed: () => _drop(record),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ShelfReaderScreen extends StatelessWidget {
  const ShelfReaderScreen({
    super.key,
    required this.titleAr,
    required this.body,
  });

  final String titleAr;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titleAr),
        actions: [
          IconButton(
            tooltip: 'قراءة',
            onPressed: () => VoiceEngine.instance.speak(
              body.length > 1200 ? body.substring(0, 1200) : body,
            ),
            icon: const Icon(Icons.volume_up_outlined),
          ),
          IconButton(
            tooltip: 'إيقاف',
            onPressed: () => VoiceEngine.instance.stopListening(),
            icon: const Icon(Icons.stop),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'نص حفظته أنت على الجهاز. ليس محتوى طبياً لليفكس ما لم يكن كذلك أصلاً.',
          ),
          const SizedBox(height: 12),
          Text(body),
        ],
      ),
    );
  }
}
