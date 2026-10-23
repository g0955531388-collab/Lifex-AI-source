/// مسنجر Lifex على هذا الجهاز. لغة الواجهة من لغة الهاتف.
library lifex_ai.screens.messenger_screen;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
import '../core/admin/admin_permissions.dart';
import '../core/trial_manager.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/emergency/device_emergency_sms_handoff.dart';
import '../features/messaging/messenger_desk.dart';
import '../features/messaging/messenger_phrases.dart';
import '../features/messaging/phone_messenger_desk.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import 'blood_request_screen.dart';
import 'health_chat_screen.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  static const _desk = MessengerDesk();
  static const _phones = PhoneMessengerDesk();
  static final _sms = DeviceEmergencySmsHandoff();
  int _tab = 0;
  String _notice = '';
  final _announce = TextEditingController();
  final _blood = TextEditingController();
  final _peerId = TextEditingController();
  final _phone = TextEditingController();
  final _smsBody = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab;
    _tab = tab < 0 ? 0 : (tab > 3 ? 3 : tab);
  }

  @override
  void dispose() {
    _announce.dispose();
    _blood.dispose();
    _peerId.dispose();
    _phone.dispose();
    _smsBody.dispose();
    super.dispose();
  }

  String _language(BuildContext context) =>
      View.of(context).platformDispatcher.locale.languageCode;

  String _t(BuildContext context, String key) =>
      MessengerPhrases.line(_language(context), key).text;

  bool _mayAnnounce(HealthProfile me) {
    final id = me.questionnaireData['accountLifexId'];
    if (id is! String || id.trim().isEmpty) return false;
    return GlobalAdminManager.instance.hasPermission(
      id.trim(),
      GlobalAdminPermission.moderateContent,
    );
  }

  bool _subscriber(HealthProfile me) {
    final trial = context.read<TrialManager>();
    final exempt = const BillingExemptionPolicy().evaluate(me).isExempt;
    return trial.phase(feeExempt: exempt) == TrialPhase.subscribed;
  }

  void _show(BuildContext context, MessengerAction action) {
    setState(() => _notice = _t(context, action.phraseKey));
  }

  void _showPlan(BuildContext context, MessengerPhonePlan plan) {
    setState(() => _notice = _t(context, plan.phraseKey));
  }

  Future<void> _routePhone(
    BuildContext context,
    HealthProfile me,
    List<HealthProfile> others,
    MessengerPhonePath path,
  ) async {
    final body = _smsBody.text.trim();
    if (path == MessengerPhonePath.sms && body.isEmpty) {
      setState(() => _notice = _t(context, 'empty'));
      return;
    }
    var draft = false;
    if (path == MessengerPhonePath.sms) {
      final digits = PhoneMessengerDesk.digitsOf(_phone.text);
      if (digits.isEmpty) {
        setState(() => _notice = _t(context, 'phoneShort'));
        return;
      }
      draft = await _sms.openDraft(phoneNumber: digits, messageAr: body);
      if (!mounted) return;
    }
    final plan = _phones.plan(
      me: me,
      peers: others,
      rawPhone: _phone.text,
      path: path,
      smsDraftOpened: draft,
    );
    setState(() => _notice = _t(this.context, plan.phraseKey));
    if (!plan.ok || plan.profileId == null || path != MessengerPhonePath.onDevice) {
      return;
    }
    HealthProfile? peer;
    for (final other in others) {
      if (other.profileId == plan.profileId) peer = other;
    }
    if (peer == null || !mounted) return;
    final guest = peer;
    await Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (_) => HealthThreadPage(me: me, other: guest),
      ),
    );
  }

  Future<void> _newGroup(
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) async {
    final title = TextEditingController();
    final selected = <String>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(_t(context, 'newGroup')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: _t(context, 'nameHint')),
                ),
                for (final other in others)
                  CheckboxListTile(
                    value: selected.contains(other.profileId),
                    title: Text(other.fullName),
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
              child: Text(_t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t(context, 'create')),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final members = others.where((item) => selected.contains(item.profileId));
    final action = _desk.createGroup(
      creator: me,
      members: members.toList(),
      title: title.text,
    );
    title.dispose();
    if (!mounted) return;
    if (action.ok) controller.saveActiveProfileChanges();
    _show(context, action);
  }

  Future<void> _openRoom(
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
    String threadId,
    String title,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupRoom(
          me: me,
          others: others,
          threadId: threadId,
          title: title,
          languageCode: _language(context),
          subscriber: _subscriber(me),
        ),
      ),
    );
    if (mounted) controller.saveActiveProfileChanges();
  }

  @override
  Widget build(BuildContext context) {
    final code = _language(context);
    final sample = MessengerPhrases.line(code, 'title');
    return Directionality(
      textDirection:
          MessengerPhrases.rtl(sample.usedCode) ? TextDirection.rtl : TextDirection.ltr,
      child: Consumer<ActiveProfileController>(
        builder: (context, controller, _) {
          final me = controller.activeProfile;
          if (me == null) {
            return Scaffold(
              appBar: AppBar(title: Text(sample.text)),
              body: Center(child: Text(_t(context, 'noPeers'))),
            );
          }
          final others = controller.allProfiles
              .where((item) => item.profileId != me.profileId)
              .toList();
          return Scaffold(
            appBar: AppBar(title: Text(sample.text)),
            body: Column(
              children: [
                if (sample.fallback)
                  MaterialBanner(
                    content: Text(MessengerPhrases.line(code, 'fallbackNote').text),
                    actions: const [SizedBox.shrink()],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(_t(context, 'localOnly')),
                ),
                if (_notice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_notice),
                  ),
                Expanded(child: _page(context, controller, me, others)),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() => _tab = value),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.chat_outlined),
                  label: _t(context, 'chats'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups_outlined),
                  label: _t(context, 'groups'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.call_outlined),
                  label: _t(context, 'calls'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: _t(context, 'meetings'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _page(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) {
    switch (_tab) {
      case 1:
        return _groups(context, controller, me, others);
      case 2:
        return _calls(context, controller, me, others);
      case 3:
        return _meetings(context, controller, me, others);
      default:
        return _chats(context, controller, me, others);
    }
  }

  Widget _chats(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) {
    final notes = _desk.bloodNotesFor(me);
    final announcements = _desk.announcementsFor(me);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${_t(context, 'myId')}: ${MessengerDesk.lifexIdOf(me)}'),
        Text(
          '${_t(context, 'myPhone')}: ${PhoneMessengerDesk.phoneOf(me).isEmpty ? _t(context, 'noPhone') : PhoneMessengerDesk.phoneOf(me)}',
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: _t(context, 'phoneHint')),
        ),
        TextField(
          controller: _smsBody,
          decoration: InputDecoration(labelText: _t(context, 'phoneMessage')),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => _routePhone(
                context,
                me,
                others,
                MessengerPhonePath.onDevice,
              ),
              child: Text(_t(context, 'chats')),
            ),
            FilledButton.tonal(
              onPressed: () => _routePhone(
                context,
                me,
                others,
                MessengerPhonePath.sms,
              ),
              child: Text(_t(context, 'phoneMessage')),
            ),
            OutlinedButton(
              onPressed: () => _routePhone(
                context,
                me,
                others,
                MessengerPhonePath.wifi,
              ),
              child: const Text('Wi-Fi'),
            ),
            OutlinedButton(
              onPressed: () => _routePhone(
                context,
                me,
                others,
                MessengerPhonePath.bluetooth,
              ),
              child: const Text('Bluetooth'),
            ),
          ],
        ),
        const Divider(),
        TextField(
          controller: _peerId,
          decoration: InputDecoration(labelText: _t(context, 'idHint')),
        ),
        FilledButton.icon(
          onPressed: () {
            final typed = _peerId.text.trim();
            if (typed.isNotEmpty && typed == MessengerDesk.lifexIdOf(me)) {
              setState(() => _notice = _t(context, 'idSelf'));
              return;
            }
            final peer = _desk.findPeerByLifexId(
              me: me,
              peers: others,
              rawId: typed,
            );
            if (peer == null) {
              setState(() => _notice = _t(context, 'idMissing'));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HealthThreadPage(me: me, other: peer),
              ),
            );
          },
          icon: const Icon(Icons.badge_outlined),
          label: Text(_t(context, 'openById')),
        ),
        const Divider(),
        TextField(
          controller: _announce,
          decoration: InputDecoration(labelText: _t(context, 'adminCompose')),
        ),
        FilledButton(
          onPressed: () {
            final action = _desk.announce(
              mayAnnounce: _mayAnnounce(me),
              from: me,
              audience: others,
              text: _announce.text,
              subscriber: _subscriber(me),
            );
            if (action.ok) {
              _announce.clear();
              controller.saveActiveProfileChanges();
            }
            _show(context, action);
          },
          child: Text(_t(context, 'announcements')),
        ),
        for (final item in announcements.reversed.take(3))
          ListTile(title: Text(item['text']?.toString() ?? '')),
        const Divider(),
        TextField(
          controller: _blood,
          decoration: InputDecoration(labelText: _t(context, 'urgentBlood')),
        ),
        FilledButton.tonal(
          onPressed: () {
            final action = _desk.urgentBloodNote(
              from: me,
              audience: others,
              text: _blood.text,
              subscriber: _subscriber(me),
            );
            if (action.ok) {
              _blood.clear();
              controller.saveActiveProfileChanges();
            }
            _show(context, action);
          },
          child: Text(_t(context, 'blood')),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BloodRequestScreen()),
          ),
          child: Text(_t(context, 'bloodDesk')),
        ),
        for (final item in notes.reversed.take(3))
          ListTile(title: Text(item['text']?.toString() ?? '')),
        const Divider(),
        if (others.isEmpty) Text(_t(context, 'noPeers')),
        for (final other in others)
          ListTile(
            leading: const Icon(Icons.chat),
            title: Text(other.fullName),
            subtitle: Text(_t(context, 'deliveredHere')),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HealthThreadPage(me: me, other: other),
              ),
            ),
          ),
      ],
    );
  }

  Widget _groups(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) {
    final groups = _desk.groupsFor(me);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _newGroup(controller, me, others),
          icon: const Icon(Icons.group_add_outlined),
          label: Text(_t(context, 'newGroup')),
        ),
        for (final group in groups.reversed)
          ListTile(
            leading: const Icon(Icons.groups),
            title: Text(group['title']?.toString() ?? ''),
            subtitle: Text(_t(context, 'deliveredHere')),
            onTap: () => _openRoom(
              controller,
              me,
              others,
              group['id']?.toString() ?? '',
              group['title']?.toString() ?? '',
            ),
          ),
      ],
    );
  }

  Widget _calls(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) {
    final calls = _desk.callsFor(me);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_t(context, 'callNotBridged')),
        if (others.isEmpty) Text(_t(context, 'noPeers')),
        for (final other in others)
          ListTile(
            title: Text(other.fullName),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _t(context, 'voice'),
                  onPressed: () {
                    final action = _desk.placeCall(
                      host: me,
                      peer: other,
                      kind: 'voice',
                    );
                    controller.saveActiveProfileChanges();
                    _show(context, action);
                  },
                  icon: const Icon(Icons.call),
                ),
                IconButton(
                  tooltip: _t(context, 'video'),
                  onPressed: () {
                    final action = _desk.placeCall(
                      host: me,
                      peer: other,
                      kind: 'video',
                    );
                    controller.saveActiveProfileChanges();
                    _show(context, action);
                  },
                  icon: const Icon(Icons.videocam_outlined),
                ),
              ],
            ),
          ),
        for (final call in calls.reversed.take(8))
          ListTile(
            title: Text('${call['kind']} · ${call['state']}'),
            subtitle: Text(_t(context, 'callNotBridged')),
          ),
      ],
    );
  }

  Widget _meetings(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile me,
    List<HealthProfile> others,
  ) {
    final rooms = ProfileBoxStoreRooms.of(me);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_t(context, 'meetingNotZoom')),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: _t(context, 'phoneHint')),
        ),
        FilledButton(
          onPressed: () {
            final plan = _phones.plan(
              me: me,
              peers: others,
              rawPhone: _phone.text,
              path: MessengerPhonePath.onDevice,
            );
            if (!plan.ok || plan.profileId == null) {
              _showPlan(context, plan);
              return;
            }
            final invited = others
                .where((item) => item.profileId == plan.profileId)
                .toList();
            final action = _desk.openMeeting(host: me, members: invited);
            if (action.ok) controller.saveActiveProfileChanges();
            _show(context, action);
          },
          child: Text(_t(context, 'inviteByPhone')),
        ),
        FilledButton(
          onPressed: others.isEmpty
              ? null
              : () {
                  final action = _desk.openMeeting(host: me, members: others);
                  if (action.ok) controller.saveActiveProfileChanges();
                  _show(context, action);
                },
          child: Text(_t(context, 'meetings')),
        ),
        for (final room in rooms.reversed)
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(room['conversationId']?.toString() ?? ''),
            subtitle: Text(_t(context, 'meetingNotZoom')),
            onTap: () => _openRoom(
              controller,
              me,
              others,
              room['conversationId']?.toString() ?? '',
              _t(context, 'meetings'),
            ),
          ),
      ],
    );
  }
}

class ProfileBoxStoreRooms {
  static List<Map<String, dynamic>> of(HealthProfile me) {
    return List<Map<String, dynamic>>.from(
      me.questionnaireData['localMeetingRooms'] is List
          ? (me.questionnaireData['localMeetingRooms'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
          : const [],
    );
  }
}

class _GroupRoom extends StatefulWidget {
  const _GroupRoom({
    required this.me,
    required this.others,
    required this.threadId,
    required this.title,
    required this.languageCode,
    required this.subscriber,
  });

  final HealthProfile me;
  final List<HealthProfile> others;
  final String threadId;
  final String title;
  final String languageCode;
  final bool subscriber;

  @override
  State<_GroupRoom> createState() => _GroupRoomState();
}

class _GroupRoomState extends State<_GroupRoom> {
  static const _desk = MessengerDesk();
  final _input = TextEditingController();
  String _fileName = '';
  int _sizeBytes = 0;
  String _status = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _t(String key) => MessengerPhrases.line(widget.languageCode, key).text;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.length();
    if (!mounted) return;
    setState(() {
      _fileName = picked.name;
      _sizeBytes = bytes;
    });
  }

  void _send() {
    final action = _desk.post(
      from: widget.me,
      audience: widget.others,
      threadId: widget.threadId,
      text: _input.text,
      fileName: _fileName,
      sizeBytes: _sizeBytes,
      subscriber: widget.subscriber,
    );
    setState(() => _status = _t(action.phraseKey));
    if (!action.ok) return;
    _input.clear();
    _fileName = '';
    _sizeBytes = 0;
  }

  @override
  Widget build(BuildContext context) {
    final posts = _desk.posts(widget.me, widget.threadId);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(_status)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final post in posts)
                  ListTile(
                    title: Text(
                      (post['text'] as String?)?.isNotEmpty == true
                          ? post['text'].toString()
                          : _t('attach'),
                    ),
                    subtitle: Text(
                      post['fileName']?.toString().isNotEmpty == true
                          ? post['fileName'].toString()
                          : _t('deliveredHere'),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _t('attach'),
                    onPressed: _pick,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: _fileName.isEmpty ? _t('hint') : _fileName,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: _t('send'),
                    onPressed: _send,
                    icon: const Icon(Icons.send),
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
