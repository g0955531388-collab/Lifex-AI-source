/// =============================================================
/// Lifex-AI — المرجع المحلي
/// الملف: device_catalog_adapter.dart
/// يطوي بطاقة LIFEX-MD على سجل الجهاز المحلي. توعية فقط. ليست أمر شراء.
/// =============================================================
library lifex_ai.core.device_catalog_adapter;

class DeviceCatalogAdapter {
  const DeviceCatalogAdapter();

  Map<String, dynamic> toLocalRecord(Map<String, dynamic> incoming) {
    final id = (incoming['device_id'] ?? incoming['id'] ?? '').toString();
    final nameAr =
        (incoming['name_ar'] ?? incoming['nameAr'] ?? '').toString();
    final nameEn =
        (incoming['name_en'] ?? incoming['nameEn'] ?? '').toString();
    final typical = incoming['typical_use'] ?? incoming['useAr'] ?? '';
    final typicalList = typical is List
        ? [for (final item in typical) item.toString()]
        : [
            if ('$typical'.trim().isNotEmpty) typical.toString(),
          ];
    return {
      'id': id.isEmpty ? 'DEV-unknown' : id,
      'catalogId': id,
      'deviceId': id,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'category': incoming['category'] ?? '',
      'purposeSummaryAr': incoming['purpose_summary'] ?? incoming['useAr'] ?? '',
      'description': incoming['purpose_summary'] ?? incoming['useAr'] ?? '',
      'typicalUse': typicalList,
      'typicalUseAr': typicalList.join('، '),
      'safetyLevelAr': incoming['safety_level'] ?? '',
      'noteAr': incoming['note'] ??
          incoming['noteAr'] ??
          'وجود الجهاز في المكتبة لا يعني ملاءمته لحالة فردية.',
    };
  }
}
