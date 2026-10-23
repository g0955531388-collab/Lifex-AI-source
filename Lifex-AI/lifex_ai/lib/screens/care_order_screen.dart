/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: care_order_screen.dart
/// طلب مخبر أو أشعة ثم نتيجة للطبيب. ليست قراءة آلية.
/// =============================================================
library lifex_ai.screens.care_order_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health_event_manager.dart';
import '../features/location/unit_exchange_desk.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';

class CareOrderScreen extends StatefulWidget {
  const CareOrderScreen({
    super.key,
    required this.titleAr,
    required this.unitType,
    required this.introAr,
    required this.event,
  });

  final String titleAr;
  final String unitType;
  final String introAr;
  final HealthEventType event;

  factory CareOrderScreen.lab() => const CareOrderScreen(
        titleAr: 'المخابر',
        unitType: 'lab',
        introAr:
            'طلب إلكتروني من الطبيب إلى المخبر ثم النتيجة تعود للطبيب. المريض يحضر مرة واحدة.',
        event: HealthEventType.labResultReceived,
      );

  factory CareOrderScreen.imaging() => const CareOrderScreen(
        titleAr: 'الأشعة',
        unitType: 'imaging',
        introAr:
            'أرشيف المريض على نفس الخيط. ليست قراءة إشعاعية من Lifex. التفسير للطبيب.',
        event: HealthEventType.imagingResultReceived,
      );

  @override
  State<CareOrderScreen> createState() => _CareOrderScreenState();
}

class _CareOrderScreenState extends State<CareOrderScreen> {
  final _summary = TextEditingController();
  final _result = TextEditingController();
  final _reply = TextEditingController();
  final _query = TextEditingController();
  bool _share = false;
  String? _selectedId;
  String _exchangeAr = '';

  @override
  void dispose() {
    _summary.dispose();
    _result.dispose();
    _reply.dispose();
    _query.dispose();
    super.dispose();
  }

  String get _purpose {
    switch (widget.unitType) {
      case 'lab':
        return 'lab';
      case 'imaging':
        return 'imaging';
      default:
        return 'doctorRequest';
    }
  }

  List<Map<String, dynamic>> _incoming(
    ProfileBoxStore store,
    HealthProfile profile,
  ) {
    return store.list(BoxKeys.unitExchange).where((item) {
      return item['toId'] == profile.profileId && item['purpose'] == _purpose;
    }).toList();
  }

  UnitRecipient? _pending(
    HealthProfile profile,
    List<HealthProfile> profiles,
  ) {
    const desk = UnitExchangeDesk();
    final ranked = desk.findRecipients(
      from: profile,
      profiles: profiles,
      purpose: _purpose,
      query: _query.text,
    );
    final picked = _selectedId;
    if (picked != null) {
      for (final row in ranked) {
        if (row.profile.profileId == picked) return row;
      }
    }
    if (_query.text.trim().isNotEmpty) {
      return ranked.length == 1 ? ranked.single : null;
    }
    return desk.nearestSpecialist(
      from: profile,
      profiles: profiles,
      purpose: _purpose,
    );
  }

  Future<void> _hearRecipient() async {
    final heard = await VoiceEngine.instance.listenFresh();
    if (!mounted) return;
    if (!heard.success) {
      setState(() {
        _exchangeAr = heard.errorMessageAr ?? 'البحث الصوتي غير جاهز.';
      });
      return;
    }
    final text = heard.textResult?.trim() ?? '';
    setState(() {
      _selectedId = null;
      _query.text = text;
      _exchangeAr = text.isEmpty ? 'لم أسمع اسماً أو معرّفاً.' : 'سمعت: $text';
    });
  }

  void _createOrder(
    ActiveProfileController controller,
    HealthProfile profile,
    ProfileBoxStore store,
  ) {
    final text = _summary.text.trim();
    if (text.isEmpty) return;
    store.add(BoxKeys.careOrders, {
      'title': text,
      'detail': 'requested',
      'unitType': widget.unitType,
      'status': 'requested',
      'resultAr': '',
    });
    var line = 'حُفظ الطلب في هذا الملف.';
    if (_share) {
      final target = _pending(profile, controller.allProfiles);
      if (target == null) {
        final hint = const UnitExchangeDesk().nearestSpecialist(
          from: profile,
          profiles: controller.allProfiles,
          purpose: _purpose,
        );
        line = hint == null
            ? 'حُفظ الطلب هنا. لا توجد جهة مختصة بهذا الطلب على هذا الجهاز.'
            : 'حُفظ الطلب هنا. اختر الجهة بالاسم أو المعرّف. الأقرب المختص: ${hint.profile.fullName}.';
      } else {
        final sent = const UnitExchangeDesk().send(
          from: profile,
          to: target.profile,
          purpose: _purpose,
          text: text,
          patientAllowsShare: true,
          patientProfileId: profile.profileId,
        );
        line = sent.messageAr;
      }
    }
    controller.saveActiveProfileChanges();
    setState(() => _exchangeAr = line);
    _summary.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.titleAr)),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final orders = store
            .list(BoxKeys.careOrders)
            .where((item) => item['unitType'] == widget.unitType)
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text(widget.titleAr)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HonestyBanner(messageAr: widget.introAr),
              TextField(
                controller: _summary,
                decoration:
                    const InputDecoration(labelText: 'نص الطلب من الطبيب'),
              ),
              CheckboxListTile(
                value: _share,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'أوافق على إرسال نص الطلب فقط إلى الجهة التي أختارها على هذا الجهاز',
                ),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() => _share = value == true),
              ),
              if (_share) ..._recipientPicker(controller, profile),
              if (_exchangeAr.isNotEmpty) Text(_exchangeAr),
              FilledButton(
                onPressed: () => _createOrder(controller, profile, store),
                child: const Text('إنشاء طلب'),
              ),
              const SizedBox(height: 12),
              Text(
                'طلبات وصلت إلى هذه الوحدة',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final packet in _incoming(store, profile))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(packet['text']?.toString() ?? ''),
                        Text('الغرض: ${packet['purpose']}'),
                        Text(
                          packet['distanceKm'] == null
                              ? 'بلا مسافة محسوبة'
                              : '${(packet['distanceKm'] as num).toStringAsFixed(1)} كم',
                        ),
                        if ((packet['resultNote'] as String?)?.isNotEmpty ==
                            true)
                          Text('رد الوحدة: ${packet['resultNote']}'),
                        if (packet['status'] != 'answered') ...[
                          TextField(
                            controller: _reply,
                            decoration: const InputDecoration(
                              labelText: 'رد الوحدة على نص الطلب',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              final result = const UnitExchangeDesk().answer(
                                unit: profile,
                                profiles: controller.allProfiles,
                                packetId: packet['id']?.toString() ?? '',
                                note: _reply.text,
                              );
                              setState(() => _exchangeAr = result.messageAr);
                              if (!result.ok) return;
                              controller.saveActiveProfileChanges();
                              _reply.clear();
                            },
                            child: const Text('حفظ رد الوحدة'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              for (var i = 0; i < orders.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(orders[i]['title']?.toString() ?? ''),
                        Text('الحالة: ${orders[i]['status']}'),
                        if ((orders[i]['resultAr'] as String?)?.isNotEmpty ==
                            true)
                          Text(orders[i]['resultAr'].toString()),
                        if (orders[i]['status'] != 'ready') ...[
                          TextField(
                            controller: _result,
                            decoration: const InputDecoration(
                                labelText: 'النتيجة للطبيب'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              final all = store.list(BoxKeys.careOrders);
                              final index = all.indexWhere((item) =>
                                  item['id'] == orders[i]['id']);
                              if (index < 0) return;
                              all[index]['status'] = 'ready';
                              all[index]['resultAr'] = _result.text.trim();
                              all[index]['detail'] = _result.text.trim();
                              store.setList(BoxKeys.careOrders, all);
                              controller.saveActiveProfileChanges();
                              HealthEventManager.instance.emitQuick(
                                widget.event,
                                sourceModule: 'care_order_screen',
                                profileId: profile.profileId,
                              );
                              _result.clear();
                            },
                            child: const Text('حفظ النتيجة'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _recipientPicker(
    ActiveProfileController controller,
    HealthProfile profile,
  ) {
    const desk = UnitExchangeDesk();
    final profiles = controller.allProfiles;
    final suggestion = desk.nearestSpecialist(
      from: profile,
      profiles: profiles,
      purpose: _purpose,
    );
    final ranked = desk.findRecipients(
      from: profile,
      profiles: profiles,
      purpose: _purpose,
      query: _query.text,
    );
    final pending = _pending(profile, profiles);
    final distance = suggestion?.distanceKm;
    final suggestionLine = suggestion == null
        ? 'لا توجد جهة مختصة بهذا الطلب ولها موقع وحدة على هذا الجهاز.'
        : distance == null
            ? 'الأقرب المختص بالاسم: ${suggestion.profile.fullName}، والمعرّف ${suggestion.profile.profileId}. المسافة غير محسوبة لأن أحد الملفين بلا إحداثيات.'
            : 'الأقرب المختص حسب موقع الوحدة: ${suggestion.profile.fullName}، والمعرّف ${suggestion.profile.profileId}، على بعد ${distance.toStringAsFixed(1)} كم.';
    final pendingLine = pending == null
        ? 'لم يُحدد مرسل إليه. اكتب الاسم أو المعرّف، أو ابحث بالصوت.'
        : 'سيُرسل النص إلى ${pending.profile.fullName} (${pending.profile.profileId}).';
    return [
      Text(suggestionLine),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _query,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'اسم الوحدة أو معرّفها',
              ),
              onChanged: (_) => setState(() => _selectedId = null),
            ),
          ),
          IconButton(
            tooltip: 'بحث صوتي عن الوحدة',
            onPressed: _hearRecipient,
            icon: const Icon(Icons.mic_none),
          ),
        ],
      ),
      Text(pendingLine),
      for (final row in ranked.take(8))
        RadioListTile<String>(
          value: row.profile.profileId,
          groupValue: pending?.profile.profileId,
          title: Text(row.profile.fullName),
          subtitle: Text(
            row.distanceKm == null
                ? '${row.profile.profileId} · بلا مسافة محسوبة'
                : '${row.profile.profileId} · ${row.distanceKm!.toStringAsFixed(1)} كم',
          ),
          onChanged: (value) => setState(() => _selectedId = value),
        ),
    ];
  }
}
