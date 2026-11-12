/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: pharmacy_stock_screen.dart
/// مخزون محلي ثم أقرب صنف. لا بيع دم.
/// =============================================================
library lifex_ai.screens.pharmacy_stock_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/doctors/pharmacy_locator.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/providers/pharmacy_stock_ledger.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/barcode_scan_button.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class PharmacyStockScreen extends StatefulWidget {
  const PharmacyStockScreen({super.key});

  @override
  State<PharmacyStockScreen> createState() => _PharmacyStockScreenState();
}

class _PharmacyStockScreenState extends State<PharmacyStockScreen> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _city = TextEditingController();
  final _km = TextEditingController();
  final _qty = TextEditingController();
  String _materialKind = 'دواء';
  String _notice = '';

  @override
  void dispose() {
    _query.dispose();
    _name.dispose();
    _barcode.dispose();
    _city.dispose();
    _km.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _move(
    ProfileBoxStore store,
    ActiveProfileController controller,
    PharmacyFlow flow,
  ) async {
    final stock = store.list(BoxKeys.pharmacyStock);
    final census = const PharmacyStockLedger().apply(
      stock: stock,
      code: _barcode.text,
      name: _name.text,
      materialKind: _materialKind,
      flow: flow,
      units: int.tryParse(_qty.text.trim()) ?? 0,
      city: _city.text,
      km: _km.text,
    );
    if (census.recorded) {
      store.setList(BoxKeys.pharmacyStock, stock);
      store.add(BoxKeys.pharmacyLedger, {
        'title': census.name,
        'barcode': census.code,
        'materialKind': _materialKind,
        'flow': flow == PharmacyFlow.purchase ? 'purchase' : 'sale',
        'units': int.tryParse(_qty.text.trim()) ?? 0,
        'before': census.quantityBefore,
        'after': census.quantityAfter,
        'codedItems': census.codedItems,
        'unitsOnHand': census.unitsOnHand,
        'detail': census.messageAr,
      });
      controller.saveActiveProfileChanges();
      _name.clear();
      _barcode.clear();
      _qty.clear();
    }
    setState(() => _notice = census.messageAr);
    await VoiceEngine.instance.speak(census.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const LifexText('الصيدلية')),
            body: const Center(child: LifexText('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final movements = store.list(BoxKeys.pharmacyLedger).reversed.toList();
        final hits = PharmacyLocator().nearestWithDrug(
          stock: store.list(BoxKeys.pharmacyStock),
          query: _query.text,
          city: _city.text,
        );
        return Scaffold(
          appBar: AppBar(title: const LifexText('الصيدلية')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'تكويد الداخل والخارج برمز الكاميرا أو الكتابة. بعد كل شراء أو بيع يُحصى دفتر الصيدلي ويُنطق. لا بيع دم ولا اسم دواء مخترع.',
              ),
              TextField(
                controller: _query,
                decoration:
                    InputDecoration(labelText: tr('اسم الدواء أو الباركود')),
                onChanged: (_) => setState(() {}),
              ),
              if (hits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LifexText('لا مخزون مطابق بعد.'),
                )
              else
                for (final item in hits)
                  ListTile(
                    title: LifexText(item['title']?.toString() ?? ''),
                    subtitle: LifexText(
                      '${item['city']} · ${item['km']} كم · كمية ${item['quantity']} · ${item['barcode']}',
                    ),
                  ),
              const Divider(),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: tr('اسم الصنف')),
              ),
              TextField(
                controller: _barcode,
                decoration: InputDecoration(labelText: tr('الباركود')),
              ),
              const SizedBox(height: 8),
              BarcodeScanButton(
                current: _barcode.text,
                onCode: (code) => setState(() => _barcode.text = code),
              ),
              TextField(
                controller: _city,
                decoration: InputDecoration(labelText: tr('المدينة')),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: tr('المسافة كم (يدوياً)')),
              ),
              TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('الكمية')),
              ),
              DropdownButtonFormField<String>(
                value: _materialKind,
                items: const [
                  DropdownMenuItem(value: 'دواء', child: LifexText('دواء')),
                  DropdownMenuItem(value: 'مادة طبية', child: LifexText('مادة طبية')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _materialKind = value);
                },
                decoration: InputDecoration(labelText: tr('نوع الصنف')),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _move(store, controller, PharmacyFlow.purchase),
                child: const LifexText('شراء داخل — تكويد وزيادة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _move(store, controller, PharmacyFlow.sale),
                child: const LifexText('بيع خارج — تكويد ونقص'),
              ),
              if (_notice.isNotEmpty) ...[
                const SizedBox(height: 12),
                LifexText(_notice),
              ],
              if (movements.isNotEmpty) ...[
                const SizedBox(height: 12),
                LifexText('سجل الصيدلي', style: Theme.of(context).textTheme.titleMedium),
                for (final move in movements.take(12))
                  ListTile(
                    title: LifexText(
                      '${move['flow'] == 'sale' ? 'بيع' : 'شراء'} · ${move['title'] ?? ''}',
                    ),
                    subtitle: LifexText(move['detail']?.toString() ?? ''),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
