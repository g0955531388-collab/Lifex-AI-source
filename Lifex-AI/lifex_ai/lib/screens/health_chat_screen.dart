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
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/health_profile.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class HealthChatScreen extends StatelessWidget {
  const HealthChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final me = controller.activeProfile;
        if (me == null) {
          return Scaffold(
            appBar: AppBar(title: const LifexText('القناة الصحية')),
            body: const Center(child: LifexText('لا يوجد ملف نشط.')),
          );
        }
        final others = controller.allProfiles
            .where((item) => item.profileId != me.profileId)
            .toList();
        return Scaffold(
          appBar: AppBar(title: const LifexText('القناة الصحية')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'مثل أسلوب واتساب للتنظيم الصحي على هذا الجهاز: تسليم فوري هنا فقط. '
                    'العامة بلا إباحي ولا نابية. الأطباء والوحدات قد يرسلون ملفاً طبياً حرجاً. '
                    'المشترك يرفق قواعد أكبر من جيغا محلياً دون رفع سحابي. '
                    'غرفة الاجتماع سجل محلي للحضور، وليست مكالمة فيديو.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: others.isEmpty
                    ? null
                    : () => _openLocalMeeting(context, controller, me, others),
                icon: const Icon(Icons.groups_outlined),
                label: const LifexText('غرفة اجتماع محلية'),
              ),
              for (final room
                  in ProfileBoxStore(me).list(BoxKeys.meetingRooms))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: LifexText(room['conversationId'] as String? ?? 'غرفة'),
                  subtitle: LifexText(
                    'حضور: ${(room['participantLifexIds'] as List?)?.length ?? 0}',
                  ),
                ),
              if (others.isEmpty)
                const LifexText('أضيفي ملفاً آخر من العائلة لتبدأ محادثة ثنائية.'),
              for (final other in others)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat),
                    title: LifexText(other.fullName),
                    subtitle: LifexText(
                      other.billingSeat == 'hospital' ||
                              other.billingSeat == 'healthUnit'
                          ? 'محادثة سريرية — مرفقات طبية مسموحة'
                          : 'محادثة عامة — فلتر أدب',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HealthThreadPage(me: me, other: other),
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

  Future<void> _openLocalMeeting(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) async {
    final selected = <String>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const LifexText('غرفة اجتماع محلية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LifexText('تُحفظ أسماء الحضور على هذا الجهاز. لا تبدأ مكالمة.'),
                for (final other in others)
                  CheckboxListTile(
                    value: selected.contains(other.profileId),
                    title: LifexText(other.fullName),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setLocal(() {
                        if (value == true) {
                          selected.add(other.profileId);
                        } else {
                          selected.remove(other.profileId);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const LifexText('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const LifexText('فتح السجل'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final room = ConversationTypeRouter().openMeetingRoom(
      participantLifexIds: [me.profileId, ...selected],
    );
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LifexText('اختر مشاركاً واحداً على الأقل معك.')),
      );
      return;
    }
    ProfileBoxStore(me).add(BoxKeys.meetingRooms, {
      'conversationId': room.conversationId,
      'type': room.type.name,
      'participantLifexIds': room.participantLifexIds,
      'createdAt': room.createdAt.toIso8601String(),
    });
    controller.saveActiveProfileChanges();
  }
}

class HealthThreadPage extends StatefulWidget {
  const HealthThreadPage({super.key, required this.me, required this.other});

  final HealthProfile me;
  final HealthProfile other;

  @override
  State<HealthThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<HealthThreadPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
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
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
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
    _scrollToEnd();
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
      appBar: AppBar(title: LifexText(widget.other.fullName)),
      body: Column(
        children: [
          if (_statusAr != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: LifexText(_statusAr!),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              itemBuilder: (_, index) {
                final post = posts[index];
                final mine = post.fromId == widget.me.profileId;
                return Align(
                  alignment:
                      mine ? Alignment.centerLeft : Alignment.centerRight,
                  child: Card(
                    color: mine
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.16)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LifexText(post.text.isEmpty ? '(مرفق)' : post.text),
                          if (post.fileName.isNotEmpty)
                            LifexText(
                              '📎 ${post.fileName} (${post.sizeBytes} بايت)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          LifexText(
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
                    tooltip: tr('إرفاق صورة أو ملف من المعرض'),
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: tr(_fileName == null
                            ? 'رسالة صحية…'
                            : 'مرفق: $_fileName'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    tooltip: tr('إرسال'),
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
