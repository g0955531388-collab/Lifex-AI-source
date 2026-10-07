/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: health_chat_screen.dart
/// قناة صحية بأسلوب المراسلة: نص ومرفقات، فلتر عام، عيادة مستثناة طبياً.
/// =============================================================
library lifex_ai.screens.health_chat_screen;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
import '../core/lasting_search_index.dart';
import '../core/local_knowledge.dart';
import '../core/trial_manager.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/messaging/conversation_type_router.dart';
import '../features/messaging/health_thread_ledger.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/health_profile.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';

class HealthChatScreen extends StatelessWidget {
  const HealthChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final me = controller.activeProfile;
        if (me == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('القناة الصحية')),
            body: const Center(child: Text('لا يوجد ملف نشط.')),
          );
        }
        final others = controller.allProfiles
            .where((item) => item.profileId != me.profileId)
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('القناة الصحية')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'مثل أسلوب واتساب للتنظيم الصحي على هذا الجهاز: تسليم فوري هنا فقط. '
                    'العامة بلا إباحي ولا نابية. الأطباء والوحدات قد يرسلون ملفاً طبياً حرجاً. '
                    'المشترك يرفق قواعد أكبر من جيغا محلياً دون رفع سحابي.',
              ),
              if (others.isEmpty)
                const Text('أضيفي ملفاً آخر من العائلة لتبدأ محادثة ثنائية.'),
              for (final other in others)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat),
                    title: Text(other.fullName),
                    subtitle: Text(
                      other.billingSeat == 'hospital' ||
                              other.billingSeat == 'healthUnit'
                          ? 'محادثة سريرية — مرفقات طبية مسموحة'
                          : 'محادثة عامة — فلتر أدب',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ThreadPage(me: me, other: other),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadPage extends StatefulWidget {
  const _ThreadPage({required this.me, required this.other});

  final HealthProfile me;
  final HealthProfile other;

  @override
  State<_ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<_ThreadPage> {
  final _input = TextEditingController();
  String? _fileName;
  int _sizeBytes = 0;
  String? _statusAr;

  ConversationType get _type {
    if (widget.me.billingSeat == 'hospital' ||
        widget.me.billingSeat == 'healthUnit' ||
        widget.other.billingSeat == 'hospital' ||
        widget.other.billingSeat == 'healthUnit') {
      return ConversationType.medical;
    }
    return ConversationType.direct;
  }

  bool get _subscriber {
    final trial = context.read<TrialManager>();
    final exempt = const BillingExemptionPolicy().evaluate(widget.me).isExempt;
    final identity =
        HealthIdentityManager.instance.getByProfileId(widget.me.profileId);
    final adminAccess = identity != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
    return trial.phase(feeExempt: exempt, adminAccess: adminAccess) ==
        TrialPhase.subscribed;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.length();
    setState(() {
      _fileName = picked.name;
      _sizeBytes = bytes;
    });
  }

  Future<void> _send() async {
    final controller = context.read<ActiveProfileController>();
    final result = HealthThreadLedger().send(
      from: widget.me,
      to: widget.other,
      type: _type,
      text: _input.text,
      fileName: _fileName ?? '',
      sizeBytes: _sizeBytes,
      subscriber: _subscriber,
    );
    setState(() => _statusAr = result.messageAr);
    if (!result.ok) return;
    _input.clear();
    _fileName = null;
    _sizeBytes = 0;
    controller.saveActiveProfileChanges();
    try {
      final engine = InternalSearchEngine(
        knowledge: context.read<LocalKnowledge>(),
        lasting: context.read<LastingSearchIndex>(),
      );
      final hits = engine.search(result.post?.text ?? '');
      if (hits.isNotEmpty) {
        await VoiceEngine.instance.speak(
          '${hits.first.titleAr}. مرجع توعية فقط.',
        );
      }
    } catch (_) {}
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final posts = HealthThreadLedger().posts(
      widget.me,
      HealthThreadLedger.threadId(widget.me.profileId, widget.other.profileId),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.other.fullName)),
      body: Column(
        children: [
          if (_statusAr != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_statusAr!),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              itemBuilder: (_, index) {
                final post = posts[index];
                final mine = post.fromId == widget.me.profileId;
                return Align(
                  alignment:
                      mine ? Alignment.centerLeft : Alignment.centerRight,
                  child: Card(
                    color: mine ? Colors.green.withOpacity(0.12) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.text.isEmpty ? '(مرفق)' : post.text),
                          if (post.fileName.isNotEmpty)
                            Text(
                              '📎 ${post.fileName} (${post.sizeBytes} بايت)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            post.read ? 'قُرئت' : 'وُصلت على هذا الجهاز',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إرفاق صورة أو ملف من المعرض',
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _fileName == null
                            ? 'رسالة صحية…'
                            : 'مرفق: $_fileName',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'إرسال',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
