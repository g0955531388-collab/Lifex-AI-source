/// =============================================================
/// Lifex-AI — مركز التبرعات الصحية
/// الملف: donations_center_screen.dart
/// بحث عام موافق ≠ عرض مرضى. تبرع مالي عبر المحفظة + FeePolicy.
/// =============================================================
library lifex_ai.screens.donations_center_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/global_donations/donation_types.dart';
import '../features/donations/donation_application_service.dart';
import '../features/donations/donation_beneficiary_directory.dart';
import '../features/finance/wallet_manager.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/honesty_banner.dart';

class DonationsCenterScreen extends StatefulWidget {
  const DonationsCenterScreen({super.key});

  @override
  State<DonationsCenterScreen> createState() => _DonationsCenterScreenState();
}

class _DonationsCenterScreenState extends State<DonationsCenterScreen> {
  late final LifexDonationApplicationService _service;
  final _search = TextEditingController();
  final _amount = TextEditingController(text: '10000');
  List<DonationBeneficiaryProfile> _results = [];
  DonationBeneficiaryProfile? _selected;
  DonationFeeQuote? _quote;
  String _statusAr = '';
  DonationPartySource _donorSource = DonationPartySource.selfAccount;

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletManager>();
    _service = LifexDonationApplicationService(wallet: wallet);
    _results = _service.directory.search(const DonationSearchQuery());
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _speak(String msg) async {
    setState(() => _statusAr = msg);
    announceForScreenReader(context, msg);
    await VoiceEngine.instance.speak(msg);
  }

  void _runSearch() {
    final q = _search.text.trim();
    setState(() {
      _results = q.isEmpty
          ? _service.directory.search(const DonationSearchQuery())
          : _service.searchByVoiceOrText(q);
      _selected = null;
      _quote = null;
    });
    _speak(
      _results.isEmpty
          ? 'لا نتائج عامة موافقة للتبرع.'
          : 'عُثر على ${_results.length} نتيجة عامة. ليست قائمة مرضى.',
    );
  }

  void _previewFee() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final q = _service.quoteFinancial(donationAmountMinor: amount);
    setState(() => _quote = q);
    _speak(q.spokenAr());
  }

  Future<void> _confirmDonate() async {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) {
      await _speak('EMPTY — أنشئ ملفاً صحياً أولاً لاستخدام المحفظة.');
      return;
    }
    if (_selected == null) {
      await _speak('اختر مستفيداً من القائمة أولاً.');
      return;
    }
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final outcome = await _service.donateFinancialFromWallet(
      donorProfileId: profile.profileId,
      beneficiaryId: _selected!.beneficiaryId,
      donationAmountMinor: amount,
      idempotencyKey:
          'don_${profile.profileId}_${DateTime.now().millisecondsSinceEpoch}',
      userConfirmedQuote: true,
      needCategory: _selected!.needCategory,
    );
    await _speak(outcome.messageAr);
    setState(() {});
  }

  Future<void> _inKindWheelchair() async {
    if (_selected == null) {
      await _speak('اختر مركزاً أو مستفيداً للأجهزة المساعدة.');
      return;
    }
    final profile = context.read<ActiveProfileController>().activeProfile;
    final outcome = await _service.acceptInKindDevice(
      donorId: profile?.profileId ?? 'anonymous_donor',
      beneficiaryId: _selected!.beneficiaryId,
      category: InKindCategory.wheelchair,
      description: 'كرسي متحرك — بانتظار مطابقة وفحص',
      condition: 'unknown',
    );
    await _speak(outcome.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<ActiveProfileController>().activeProfile == null
        ? 0
        : context.read<WalletManager>().balanceFor(
              context.read<ActiveProfileController>().activeProfile!.profileId,
            );

    return Scaffold(
      appBar: AppBar(title: const Text('التبرعات الصحية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'البحث يعرض حملات/ملفات تبرع عامة موافقة فقط. '
                'ليس استعلاماً على ملفات المرضى. التبرع المالي عبر المحفظة والرسوم من سياسة الرسوم.',
          ),
          Text('رصيد المحفظة (أصغر وحدة): $balance'),
          const SizedBox(height: 8),
          Text(
            'مصدر المتبرع: ${_donorSource.name}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('حسابي'),
                selected: _donorSource == DonationPartySource.selfAccount,
                onSelected: (_) => setState(
                  () => _donorSource = DonationPartySource.selfAccount,
                ),
              ),
              ChoiceChip(
                label: const Text('هاتف (اختيار لاحق)'),
                selected: _donorSource == DonationPartySource.phoneContact,
                onSelected: (_) {
                  setState(
                    () => _donorSource = DonationPartySource.phoneContact,
                  );
                  _speak(
                    'اختيار جهة من الهاتف يمر عبر منتقي النظام — لا استيراد دفتر كامل.',
                  );
                },
              ),
              ChoiceChip(
                label: const Text('دليل Lifex'),
                selected: _donorSource == DonationPartySource.lifexDirectory,
                onSelected: (_) => setState(
                  () => _donorSource = DonationPartySource.lifexDirectory,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'بحث (مرضى السرطان، قلب، كرسي…)',
              hintText: 'أريد التبرع لمرضى السرطان',
            ),
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.search,
            label: 'ابحث عن مستفيدين/حملات',
            semanticHint: 'يبحث في الدليل العام الموافق فقط',
            onTap: _runSearch,
          ),
          const SizedBox(height: 12),
          Text(
            'النتائج (${_results.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_results.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'EMPTY — لا نتائج عامة موافقة حالياً.\n'
                      'ليست رفض صلاحية وليست قائمة مرضى مخفية.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('مرضى السرطان'),
                          onPressed: () {
                            _search.text = 'أريد التبرع لمرضى السرطان';
                            _runSearch();
                          },
                        ),
                        ActionChip(
                          label: const Text('أمراض القلب'),
                          onPressed: () {
                            _search.text = 'أريد التبرع لمرضى القلب';
                            _runSearch();
                          },
                        ),
                        ActionChip(
                          label: const Text('كراسي متحركة'),
                          onPressed: () {
                            _search.text = 'أريد التبرع بكرسي متحرك';
                            _runSearch();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          for (final b in _results)
            Card(
              color: _selected?.beneficiaryId == b.beneficiaryId
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                title: Text(b.alias ?? b.displayName),
                subtitle: Text(
                  '${b.needCategory.name} · ${b.locationArea} · ${b.urgency}\n'
                  '${b.needDescription}',
                ),
                isThreeLine: true,
                onTap: () {
                  setState(() => _selected = b);
                  _speak(b.spokenAr());
                },
              ),
            ),
          const Divider(),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مبلغ التبرع (أصغر وحدة)',
              hintText: '10000 = 100.00 إن كان المضاعف 100',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AccessibleActionButton(
                  icon: Icons.calculate_outlined,
                  label: 'معاينة الرسوم',
                  semanticHint: 'يعرض التبرع والرسوم والإجمالي قبل التأكيد',
                  onTap: _previewFee,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AccessibleActionButton(
                  icon: Icons.volunteer_activism,
                  label: 'تأكيد التبرع',
                  semanticHint: 'يخصم من المحفظة بعد معاينة الرسوم',
                  onTap: _confirmDonate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AccessibleActionButton(
            icon: Icons.accessible,
            label: 'تبرع عيني: كرسي متحرك',
            semanticHint: 'يسجّل تبرعاً عينياً بلا قرار طبي آلي',
            onTap: _inKindWheelchair,
          ),
          if (_quote != null) ...[
            const SizedBox(height: 12),
            LiveAnnouncingText(message: _quote!.spokenAr()),
          ],
          if (_statusAr.isNotEmpty) ...[
            const SizedBox(height: 8),
            LiveAnnouncingText(message: _statusAr),
          ],
        ],
      ),
    );
  }
}
