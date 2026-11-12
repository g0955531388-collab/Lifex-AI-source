/// =============================================================
/// Lifex-AI — دفتر حركة الصيدلية
/// التكويد من الرمز الذي يدخله الصيدلي. الإحصاء بعد كل شراء أو بيع.
/// =============================================================
library lifex_ai.features.providers.pharmacy_stock_ledger;

enum PharmacyFlow { purchase, sale }

class PharmacyCensus {
  const PharmacyCensus({
    required this.recorded,
    required this.messageAr,
    required this.code,
    required this.name,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.codedItems,
    required this.unitsOnHand,
  });

  final bool recorded;
  final String messageAr;
  final String code;
  final String name;
  final int quantityBefore;
  final int quantityAfter;
  final int codedItems;
  final int unitsOnHand;
}

class PharmacyStockLedger {
  const PharmacyStockLedger();

  static int readQuantity(Map<String, dynamic> row) {
    final value = row['quantity'];
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  PharmacyCensus apply({
    required List<Map<String, dynamic>> stock,
    required String code,
    required String name,
    required String materialKind,
    required PharmacyFlow flow,
    required int units,
    String city = '',
    String km = '',
  }) {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();
    if (trimmedCode.isEmpty || units <= 0) {
      return PharmacyCensus(
        recorded: false,
        messageAr: 'لم يُسجَّل شيء. التكويد يحتاج رمزاً وكمية أكبر من صفر.',
        code: trimmedCode,
        name: trimmedName,
        quantityBefore: 0,
        quantityAfter: 0,
        codedItems: _codedItems(stock),
        unitsOnHand: _unitsOnHand(stock),
      );
    }
    final index = stock.indexWhere(
      (row) => (row['barcode']?.toString().trim() ?? '') == trimmedCode,
    );
    if (index < 0 && trimmedName.isEmpty) {
      return PharmacyCensus(
        recorded: false,
        messageAr: 'رمز جديد يحتاج اسم الصنف كما يكتبه الصيدلي. لن يُخترع اسم.',
        code: trimmedCode,
        name: '',
        quantityBefore: 0,
        quantityAfter: 0,
        codedItems: _codedItems(stock),
        unitsOnHand: _unitsOnHand(stock),
      );
    }
    if (index < 0) {
      if (flow == PharmacyFlow.sale) {
        return PharmacyCensus(
          recorded: false,
          messageAr:
              'البيع لم يُسجَّل. الرمز $trimmedCode غير مكوّد في دفتر الصيدلي.',
          code: trimmedCode,
          name: trimmedName,
          quantityBefore: 0,
          quantityAfter: 0,
          codedItems: _codedItems(stock),
          unitsOnHand: _unitsOnHand(stock),
        );
      }
      stock.add({
        'title': trimmedName,
        'barcode': trimmedCode,
        'materialKind': materialKind,
        'quantity': units,
        'city': city.trim(),
        'km': km.trim(),
      });
      return _done(
        stock: stock,
        code: trimmedCode,
        name: trimmedName,
        before: 0,
        after: units,
        flow: flow,
        units: units,
      );
    }
    final row = stock[index];
    final before = readQuantity(row);
    final storedName = (row['title']?.toString().trim().isNotEmpty ?? false)
        ? row['title'].toString()
        : trimmedName;
    if (flow == PharmacyFlow.sale && before < units) {
      return PharmacyCensus(
        recorded: false,
        messageAr:
            'البيع لم يُسجَّل. رمز $trimmedCode رصيده $before وهو أقل من $units. الدفتر لم يتغير.',
        code: trimmedCode,
        name: storedName,
        quantityBefore: before,
        quantityAfter: before,
        codedItems: _codedItems(stock),
        unitsOnHand: _unitsOnHand(stock),
      );
    }
    final after = flow == PharmacyFlow.purchase ? before + units : before - units;
    row['quantity'] = after;
    row['barcode'] = trimmedCode;
    if (storedName.isNotEmpty) row['title'] = storedName;
    if (materialKind.trim().isNotEmpty) row['materialKind'] = materialKind;
    if (city.trim().isNotEmpty) row['city'] = city.trim();
    if (km.trim().isNotEmpty) row['km'] = km.trim();
    return _done(
      stock: stock,
      code: trimmedCode,
      name: storedName,
      before: before,
      after: after,
      flow: flow,
      units: units,
    );
  }

  PharmacyCensus _done({
    required List<Map<String, dynamic>> stock,
    required String code,
    required String name,
    required int before,
    required int after,
    required PharmacyFlow flow,
    required int units,
  }) {
    final coded = _codedItems(stock);
    final onHand = _unitsOnHand(stock);
    final verb = flow == PharmacyFlow.purchase ? 'شراء داخل' : 'بيع خارج';
    return PharmacyCensus(
      recorded: true,
      code: code,
      name: name,
      quantityBefore: before,
      quantityAfter: after,
      codedItems: coded,
      unitsOnHand: onHand,
      messageAr:
          '$verb. الرمز $code، $name، $units وحدة. '
          'الرصيد كان $before وصار $after. '
          'الإحصاء: $coded صنفاً مرمّزاً، $onHand وحدة في دفتر الصيدلي.',
    );
  }

  int _codedItems(List<Map<String, dynamic>> stock) {
    return stock
        .where((row) => (row['barcode']?.toString().trim() ?? '').isNotEmpty)
        .length;
  }

  int _unitsOnHand(List<Map<String, dynamic>> stock) {
    var total = 0;
    for (final row in stock) {
      total += readQuantity(row);
    }
    return total;
  }
}
