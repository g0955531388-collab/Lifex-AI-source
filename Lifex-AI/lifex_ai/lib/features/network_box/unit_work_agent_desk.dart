/// وكيل وحدة يعمل فقط إذا فعّله مديرها المعتمد، وينقل ملفاً بين وحدات هذا الجهاز.
library lifex_ai.features.network_box.unit_work_agent_desk;

import 'box_unit_catalog.dart';
import 'profile_box_store.dart';
import 'unit_membership_desk.dart';

class UnitWorkResult {
  const UnitWorkResult({required this.ok, required this.messageAr, this.id});

  final bool ok;
  final String messageAr;
  final String? id;
}

class UnitWorkAgentDesk {
  const UnitWorkAgentDesk({this.membership = const UnitMembershipDesk()});

  final UnitMembershipDesk membership;

  static String agentKey(String unitId) => 'unitAgent_$unitId';

  static String inboxKey(String unitId) => 'unitWorkInbox_$unitId';

  static bool knownUnit(String unitId) =>
      BoxUnitCatalog.recordUnits.any((unit) => unit.id == unitId);

  bool isEnabled(ProfileBoxStore store, String unitId) {
    final map = store.map(agentKey(unitId));
    return map['enabled'] == true;
  }

  String? managerId(ProfileBoxStore store, String unitId) {
    final id = store.map(agentKey(unitId))['managerProfileId']?.toString();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  UnitWorkResult setEnabled({
    required ProfileBoxStore store,
    required String unitId,
    required String managerProfileId,
    required bool enabled,
  }) {
    if (!knownUnit(unitId)) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'الوحدة غير معروفة. لم يُفعَّل وكيل.',
      );
    }
    if (!membership.isMember(store, unitId, managerProfileId)) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'مدير الوحدة المعتمد فقط يفعّل الوكيل أو يوقفه.',
      );
    }
    store.setMap(agentKey(unitId), {
      'enabled': enabled,
      'managerProfileId': managerProfileId,
      'serverDeliveryConfirmed': false,
    });
    return UnitWorkResult(
      ok: true,
      messageAr: enabled
          ? 'وكيل الوحدة يعمل على هذا الجهاز بأمر مديرها. لا يشخص ولا يصف علاجاً.'
          : 'توقف وكيل الوحدة. لن ينقل ملفات حتى يُفعَّل من جديد.',
    );
  }

  void release({
    required ProfileBoxStore store,
    required String unitId,
  }) {
    store.setMap(agentKey(unitId), {
      'enabled': false,
      'managerProfileId': '',
      'serverDeliveryConfirmed': false,
    });
  }

  List<Map<String, dynamic>> inbox(ProfileBoxStore store, String unitId) =>
      store.list(inboxKey(unitId));

  UnitWorkResult exchangeFile({
    required ProfileBoxStore store,
    required String fromUnitId,
    required String toUnitId,
    required String actorProfileId,
    required String fileName,
    String note = '',
    int sizeBytes = 0,
  }) {
    if (!knownUnit(fromUnitId) || !knownUnit(toUnitId)) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'إحدى الوحدتين غير معروفة. لم يُنقل ملف.',
      );
    }
    if (fromUnitId == toUnitId) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'لا تنقل الوحدة الملف إلى نفسها.',
      );
    }
    if (!membership.isMember(store, fromUnitId, actorProfileId)) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'النقل من مدير الوحدة المعتمد فقط.',
      );
    }
    if (!isEnabled(store, fromUnitId)) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'الوكيل متوقف. مدير الوحدة لم يفعّله، فلم يُنقل ملف.',
      );
    }
    final name = fileName.trim();
    if (name.isEmpty) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'اسم الملف فارغ. لم يُنقل شيء.',
      );
    }
    if (sizeBytes < 0) {
      return const UnitWorkResult(
        ok: false,
        messageAr: 'حجم الملف غير صالح. لم يُنقل شيء.',
      );
    }
    final privateFile = fromUnitId == 'women' || toUnitId == 'women';
    final id = 'UWF-${DateTime.now().microsecondsSinceEpoch}';
    final packet = <String, dynamic>{
      'id': id,
      'fromUnitId': fromUnitId,
      'toUnitId': toUnitId,
      'actorProfileId': actorProfileId,
      'fileName': name,
      'note': note.trim(),
      'sizeBytes': sizeBytes,
      'privateFile': privateFile,
      'status': 'localDelivered',
      'serverDeliveryConfirmed': false,
      'interpreted': false,
    };
    store.add(inboxKey(toUnitId), packet);
    store.add(inboxKey(fromUnitId), {
      ...packet,
      'status': 'localSent',
    });
    final privacy = privateFile
        ? ' الملف خاص ويبقى على هذا الجهاز.'
        : '';
    return UnitWorkResult(
      ok: true,
      id: id,
      messageAr:
          'نقل الوكيل اسم الملف من الوحدة إلى الوحدة على هذا الجهاز.$privacy ليس تشخيصاً ولم يغادر الجهاز.',
    );
  }
}
