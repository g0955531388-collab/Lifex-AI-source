/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: box_unit_screen.dart
/// مساحة عمل لأي وحدة: فروع السيناريو ثم السجلات، وليست قائمة مسطحة.
/// =============================================================
library lifex_ai.screens.box_unit_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/finance/billing_exemption_policy.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/network_box/unit_branch_catalog.dart';
import '../features/network_box/unit_membership_desk.dart';
import '../features/network_box/unit_work_agent_desk.dart';
import '../features/network_box/unit_slot_board.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';
import 'health_profile_screen.dart';
import 'unit_branch_navigator.dart';

class BoxUnitScreen extends StatelessWidget {
  const BoxUnitScreen({super.key, required this.unit});

  final BoxUnit unit;

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(unit.titleAr)),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final branches = UnitBranchCatalog.forUnit(unit.id);
        return Scaffold(
          appBar: AppBar(title: Text(unit.titleAr)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(unit.subtitleAr,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              HonestyBanner.localAndServer(),
              HonestyBanner.medical(),
              const SizedBox(height: 12),
              _UnitMembershipBar(
                unitId: unit.id,
                store: store,
                controller: controller,
              ),
              const SizedBox(height: 12),
              _UnitAgentCard(unit: unit),
                const SizedBox(height: 12),
              _UnitBookingCard(
                unitId: unit.id,
                store: store,
                controller: controller,
              ),
              if (unit.id == 'chronicPlans') ...[
                const SizedBox(height: 12),
                _ExemptionCard(),
              ],
              const SizedBox(height: 16),
              Text('أقسام الوحدة',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (branches.isEmpty)
                const Text('لا فروع معرفة لهذه الوحدة بعد.')
              else
                for (final branch in branches)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(branch.icon)),
                      title: Text(branch.titleAr),
                      subtitle: Text(
                        _branchSubtitle(store, branch),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => UnitBranchNavigator.open(
                        context,
                        branch,
                        profileId: profile.profileId,
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  String _branchSubtitle(ProfileBoxStore store, UnitBranch branch) {
    final extra = branch.needsServer ? 'ينتظر خادماً للتأكيد الخارجي. ' : '';
    if (!branch.isRecords) {
      return '$extra${branch.subtitleAr}';
    }
    final count = store.list(branch.storageKey!).length;
    return '$extra${branch.subtitleAr}\nسجلات هذا الفرع: $count';
  }
}

class _UnitMembershipBar extends StatelessWidget {
  const _UnitMembershipBar({
    required this.unitId,
    required this.store,
    required this.controller,
  });

  final String unitId;
  final ProfileBoxStore store;
  final ActiveProfileController controller;

  static const _desk = UnitMembershipDesk();

  @override
  Widget build(BuildContext context) {
    final profile = controller.activeProfile;
    final profileId = profile?.profileId ?? '';
    final following = _desk.isFollowing(store, unitId, profileId);
    final member = _desk.isMember(store, unitId, profileId);
    final count = _desk.followers(store, unitId).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المتابعون الخارجيون على هذا الجهاز: $count',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              member
                  ? 'صفتك: عضو. يحق لهذه الوحدة فحص ملفك الصحي على هذا الجهاز.'
                  : 'صفتك: زائر. اعتماد الوحدة يجعلك عضواً ويسمح لها بفحص ملفك.',
            ),
            const SizedBox(height: 4),
            const Text(
              'المتابعة الخارجية تُبقيك زائراً ولا تمنح حق الفحص. '
              'الاعتماد ليس ترخيصاً وطنياً ولا يكشف ملفات الآخرين.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: profile == null
                      ? null
                      : () {
                          final added = _desk.follow(
                            store: store,
                            unitId: unitId,
                            profileId: profileId,
                            displayName: profile.fullName,
                          );
                    controller.saveActiveProfileChanges();
                          _showFollowers(
                            context,
                            added
                                ? 'سُجّلت متابعة خارجية. بلا أسرار عمل.'
                                : 'المتابعة الخارجية مسجّلة من قبل.',
                          );
                        },
                  child: Text(
                    following ? 'متابع خارجي' : 'متابعون خارجيون',
                  ),
                ),
                FilledButton(
                  onPressed: profile == null
                      ? null
                      : () {
                          if (member) {
                            _desk.leave(
                              store: store,
                              unitId: unitId,
                              profileId: profileId,
                            );
                            const UnitWorkAgentDesk().release(
                              store: store,
                              unitId: unitId,
                            );
                          } else {
                            _desk.accredit(
                              store: store,
                              unitId: unitId,
                              profileId: profileId,
                              displayName: profile.fullName,
                            );
                          }
                    controller.saveActiveProfileChanges();
                  },
                  child:
                      Text(member ? 'عضو — إلغاء الاعتماد' : 'اعتماد الوحدة'),
                ),
                if (profile != null &&
                    _desk.mayExamineHealthFile(store, unitId, profileId))
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HealthProfileScreen(
                          profile: profile,
                          preferThisProfile: true,
                        ),
                      ),
                    ),
                    child: const Text('فحص الملف الصحي'),
                  ),
              ],
            ),
            if (_desk.notices(store, unitId).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'إشعارات الوحدة',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final notice
                  in _desk.notices(store, unitId).reversed.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(notice['title']?.toString() ?? ''),
                  subtitle: Text(notice['detail']?.toString() ?? ''),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFollowers(BuildContext context, String lead) {
    final names = [
      for (final item in _desk.followers(store, unitId))
        item['name']?.toString() ?? '',
    ].where((name) => name.isNotEmpty).toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('متابعون خارجيون'),
        content: Text(
          names.isEmpty
              ? '$lead\nلا متابع مسجّل على هذا الجهاز.'
              : '$lead\n${names.join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _UnitBookingCard extends StatefulWidget {
  const _UnitBookingCard({
    required this.unitId,
    required this.store,
    required this.controller,
  });

  final String unitId;
  final ProfileBoxStore store;
  final ActiveProfileController controller;

  @override
  State<_UnitBookingCard> createState() => _UnitBookingCardState();
}

class _UnitBookingCardState extends State<_UnitBookingCard> {
  static const _board = UnitSlotBoard();
  final _prepaid = TextEditingController();
  DateTime _day = DateTime.now();
  String _period = 'all';
  String? _statusAr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  @override
  void dispose() {
    _prepaid.dispose();
    super.dispose();
  }

  void _settle() {
    if (!mounted) return;
    final count = _board.settleNoShows(
      store: widget.store,
      unitId: widget.unitId,
      day: _day,
    );
    if (count == 0 || !mounted) return;
    widget.controller.saveActiveProfileChanges();
    setState(() {
      _statusAr =
          'انتهت حصة بلا حضور. سقط حق المبلغ المدفوع للوحدة. لم يُنقل مبلغ.';
    });
  }

  bool _inPeriod(String clock) {
    final hour = int.tryParse(clock.split(':').first) ?? 0;
    if (_period == 'am') return hour < 15;
    if (_period == 'pm') return hour >= 15;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.activeProfile;
    final slots = _board
        .publicSlots(widget.store, widget.unitId, _day)
        .where((slot) => _inPeriod(slot['time'].toString()));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حجز حصة', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text(
              'مثل حجز الطبيب: الحصة الفارغة تُحجز على هذا الجهاز، '
              'والمأخوذة تبقى محجوزة. قبل الحصة اضغط حصتك لإلغائها، '
              'فيُطلب استرداد المبلغ بعد عمولة النظام 5٪. '
              'خلال الحصة اضغط «حضرت». إذا انتهت بلا حضور يسقط حق المبلغ المدفوع للوحدة. '
              'لا تُحفظ بيانات بطاقة، ولا يُنقل مزود مرخّص المبلغ.',
            ),
            TextField(
              controller: _prepaid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'دفع مسبق بالوحدة الصغرى',
                helperText: 'اتركه فارغاً للحجز بلا دفع.',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(UnitSlotBoard.dayKey(_day)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) {
                  setState(() => _day = picked);
                  _settle();
                }
              },
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('الفترتان')),
                ButtonSegment(value: 'am', label: Text('صباحي')),
                ButtonSegment(value: 'pm', label: Text('مسائي')),
              ],
              selected: {_period},
              onSelectionChanged: (value) =>
                  setState(() => _period = value.first),
            ),
            if (_statusAr != null) ...[
              const SizedBox(height: 8),
              Text(_statusAr!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in slots)
                  Builder(
                    builder: (context) {
                      final holder = profile;
                      final time = slot['time'].toString();
                      final booked = slot['booked'] == true;
                      final mine = holder != null &&
                          _board.heldBy(
                            store: widget.store,
                            unitId: widget.unitId,
                            day: _day,
                            time: time,
                            profileId: holder.profileId,
                          );
                      final now = DateTime.now();
                      final before =
                          mine && now.isBefore(_board.slotStart(_day, time));
                      final during = mine &&
                          !now.isBefore(_board.slotStart(_day, time)) &&
                          now.isBefore(_board.slotEnd(_day, time));
                      final attended = holder != null &&
                          mine &&
                          _board.attendedBy(
                            store: widget.store,
                            unitId: widget.unitId,
                            day: _day,
                            time: time,
                            profileId: holder.profileId,
                          );
                      final label = !booked
                          ? time
                          : (!mine
                              ? '$time محجوز'
                              : (attended
                                  ? '$time حضرتُ'
                                  : (before
                                      ? '$time إلغاء'
                                      : (during
                                          ? '$time حضرت'
                                          : '$time محجوز'))));
                      return ActionChip(
                        label: Text(label),
                        onPressed: holder == null ||
                                (booked &&
                                    (!mine || attended || (!before && !during)))
                            ? null
                            : () {
                                final person = holder;
                                if (booked && during) {
                                  final error = _board.markAttended(
                                    store: widget.store,
                                    unitId: widget.unitId,
                                    patient: person,
                                    day: _day,
                                    time: time,
                                  );
                                  widget.controller.saveActiveProfileChanges();
                                  setState(() {
                                    _statusAr = error ??
                                        'سُجّل حضورك في $time على هذا الجهاز.';
                                  });
                                  return;
                                }
                                if (booked && before) {
                                  final result = _board.cancel(
                                    store: widget.store,
                                    unitId: widget.unitId,
                                    patient: person,
                                    day: _day,
                                    time: time,
                                  );
                                  widget.controller.saveActiveProfileChanges();
                                  setState(() {
                                    _statusAr = result.errorAr ??
                                        (result.forfeited
                                            ? 'سقط حق المبلغ المدفوع للوحدة لأن الحضور لم يُسجَّل. لم يُنقل مبلغ.'
                                            : (result.prepaidMinor > 0
                                                ? 'أُلغي $time. طُلب استرداد ${result.refundMinor}. عمولة النظام ${result.commissionMinor} تبقى. لم يُرجع مزود مرخّص المبلغ.'
                                                : 'أُلغي $time وأُعلمت الوحدة على هذا الجهاز.'));
                                  });
                                  return;
                                }
                                final raw = _prepaid.text.trim();
                                final prepaid =
                                    raw.isEmpty ? 0 : int.tryParse(raw);
                                if (prepaid == null) {
                                  setState(() => _statusAr =
                                      'مبلغ الدفع المسبق يُكتب رقماً صحيحاً بالوحدة الصغرى.');
                                  return;
                                }
                                final error = _board.book(
                                  store: widget.store,
                                  unitId: widget.unitId,
                                  patient: person,
                                  day: _day,
                                  time: time,
                                  prepaidMinor: prepaid,
                                );
                                widget.controller.saveActiveProfileChanges();
                                setState(() {
                                  _statusAr = error ??
                                      (prepaid > 0
                                          ? 'حُجزت $time مع دفع مسبق معلّق. الإلغاء قبل الحصة يسترد بعد العمولة، والغياب يُسقط مبلغ الوحدة.'
                                          : 'حُجزت $time وأُعلمت الوحدة على هذا الجهاز.');
                                });
                              },
                      );
                    },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExemptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    if (profile == null) return const SizedBox.shrink();
    final result = const BillingExemptionPolicy().evaluate(profile);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.verified_outlined),
        title: const Text('الإعفاء الإنساني'),
        subtitle: Text(
          result.isExempt
              ? result.reasonAr!
              : 'التثبيت في فرع المعاقين: بطاقة إعاقة أو بطاقة مريض دائم من البلد المسجّل فيه صاحب الحساب.',
        ),
      ),
    );
  }
}

class _UnitAgentCard extends StatefulWidget {
  const _UnitAgentCard({required this.unit});

  final BoxUnit unit;

  @override
  State<_UnitAgentCard> createState() => _UnitAgentCardState();
}

class _UnitAgentCardState extends State<_UnitAgentCard> {
  static const _agent = UnitWorkAgentDesk();
  static const _membership = UnitMembershipDesk();
  final _fileName = TextEditingController();
  final _note = TextEditingController();
  String? _targetId;
  String _status = '';

  @override
  void dispose() {
    _fileName.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return const SizedBox.shrink();
    final store = ProfileBoxStore(profile);
    final member = _membership.isMember(store, widget.unit.id, profile.profileId);
    final enabled = _agent.isEnabled(store, widget.unit.id);
    final targets = [
      for (final unit in BoxUnitCatalog.recordUnits)
        if (unit.id != widget.unit.id) unit,
    ];
    final inbox = _agent.inbox(store, widget.unit.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('وكيل الوحدة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              member
                  ? 'أنت مدير هذه الوحدة على هذا الجهاز. الوكيل لا يعمل إلا إذا فعّلته.'
                  : 'الوكيل متوقف. مدير الوحدة المعتمد فقط يستطيع تشغيله.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تشغيل الوكيل لإدارة نقل الملفات'),
              value: enabled,
              onChanged: member
                  ? (value) {
                      final result = _agent.setEnabled(
                        store: store,
                        unitId: widget.unit.id,
                        managerProfileId: profile.profileId,
                        enabled: value,
                      );
                      controller.saveActiveProfileChanges();
                      setState(() => _status = result.messageAr);
                    }
                  : null,
            ),
            DropdownButtonFormField<String>(
              value: _targetId,
              items: [
                for (final unit in targets)
                  DropdownMenuItem(value: unit.id, child: Text(unit.titleAr)),
              ],
              onChanged: enabled
                  ? (value) => setState(() => _targetId = value)
                  : null,
              decoration: const InputDecoration(labelText: 'الوحدة المستقبلة'),
            ),
            TextField(
              controller: _fileName,
              enabled: enabled,
              decoration: const InputDecoration(labelText: 'اسم الملف'),
            ),
            TextField(
              controller: _note,
              enabled: enabled,
              decoration: const InputDecoration(labelText: 'ملاحظة النقل'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: !enabled || _targetId == null
                  ? null
                  : () {
                      final result = _agent.exchangeFile(
                        store: store,
                        fromUnitId: widget.unit.id,
                        toUnitId: _targetId!,
                        actorProfileId: profile.profileId,
                        fileName: _fileName.text,
                        note: _note.text,
                      );
                      if (result.ok) {
                        _fileName.clear();
                        _note.clear();
                      }
                      controller.saveActiveProfileChanges();
                      setState(() => _status = result.messageAr);
                    },
              child: const Text('نقل الملف إلى الوحدة'),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_status),
            ],
            if (inbox.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملفات هذه الوحدة على الجهاز: ${inbox.length}'),
              for (final item in inbox.reversed.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['fileName']?.toString() ?? ''),
                  subtitle: Text(
                    '${item['fromUnitId']} → ${item['toUnitId']} · ${item['status']}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
