import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/providers/pharmacist_desk.dart';
import 'package:lifex_ai/features/providers/pharmacy_inventory_manager.dart';
import 'package:lifex_ai/features/providers/pharmacy_stock_ledger.dart';

void main() {
  test('بانر الصيدلية بلا مثال شخص ولا إسناد المرشد', () {
    final branch = UnitBranchCatalog.forUnit('pharmacy')
        .firstWhere((item) => item.id == 'publicPharm');
    expect(branch.subtitleAr, contains(PharmacistDesk.bannerAr));
    expect(branch.extraFields.map((field) => field.key), contains('contact'));
    expect(PharmacistDesk.sampleProfileAllowed, isFalse);
    expect(PharmacistDesk.placeFollowsLocationSystem, isTrue);
    expect(PharmacistDesk.publicShippingPercentIsFee, isFalse);
    expect(PharmacistDesk.bloodFlashRepeats, 0);
    final footer = PharmacistDesk.shareFooter();
    expect(footer, contains('الملكية والشراكة مناصفة'));
    expect(footer.contains('أحمد'), isFalse);
    expect(footer.contains('12345'), isFalse);
    expect(footer.contains('المرشد'), isFalse);
    expect(footer.contains('33.8938'), isFalse);
  });

  test('الباركود نفسه لا ينشئ دواءً ثانياً', () {
    final stock = PharmacyInventoryManager();
    final first = stock.rememberBarcode(
      pharmacyId: 'ph-1',
      barcode: ' 622 ',
      medicationId: 'med-a',
    );
    final second = stock.rememberBarcode(
      pharmacyId: 'ph-1',
      barcode: '622',
      medicationId: 'med-b',
    );
    expect(first, 'med-a');
    expect(second, 'med-a');
    final book = <Map<String, dynamic>>[];
    const ledger = PharmacyStockLedger();
    final bought = ledger.apply(
      stock: book,
      code: '622',
      name: 'صنف الصيدلي',
      materialKind: 'دواء',
      flow: PharmacyFlow.purchase,
      units: 4,
    );
    expect(bought.recorded, isTrue);
    expect(bought.quantityAfter, 4);
    expect(book, hasLength(1));
    final again = ledger.apply(
      stock: book,
      code: '622',
      name: 'اسم آخر',
      materialKind: 'مادة طبية',
      flow: PharmacyFlow.purchase,
      units: 1,
    );
    expect(again.quantityAfter, 5);
    expect(book, hasLength(1));
    expect(book.single['title'], 'صنف الصيدلي');
    final refused = ledger.apply(
      stock: book,
      code: '622',
      name: 'صنف الصيدلي',
      materialKind: 'دواء',
      flow: PharmacyFlow.sale,
      units: 9,
    );
    expect(refused.recorded, isFalse);
    expect(PharmacyStockLedger.readQuantity(book.single), 5);
    final sold = ledger.apply(
      stock: book,
      code: '622',
      name: '',
      materialKind: 'دواء',
      flow: PharmacyFlow.sale,
      units: 2,
    );
    expect(sold.recorded, isTrue);
    expect(sold.quantityAfter, 3);
    expect(sold.unitsOnHand, 3);
    expect(sold.messageAr, contains('الإحصاء'));
    expect(
      stock.rememberBarcode(
        pharmacyId: 'ph-1',
        barcode: ' ',
        medicationId: 'med-a',
      ),
      isNull,
    );
  });
}
