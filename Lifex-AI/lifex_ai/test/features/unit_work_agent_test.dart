import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/network_box/unit_membership_desk.dart';
import 'package:lifex_ai/features/network_box/unit_work_agent_desk.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  test('الوكيل لا ينقل ملفاً إلا بأمر مدير الوحدة المعتمد', () {
    const membership = UnitMembershipDesk();
    const agent = UnitWorkAgentDesk();
    final profile = HealthProfile(profileId: 'mgr', fullName: 'مدير');
    final store = ProfileBoxStore(profile);

    expect(
      agent.setEnabled(
        store: store,
        unitId: 'labs',
        managerProfileId: 'visitor',
        enabled: true,
      ).ok,
      isFalse,
    );
    expect(agent.isEnabled(store, 'labs'), isFalse);

    membership.accredit(
      store: store,
      unitId: 'labs',
      profileId: 'mgr',
      displayName: 'مدير',
    );
    expect(
      agent.exchangeFile(
        store: store,
        fromUnitId: 'labs',
        toUnitId: 'pharmacy',
        actorProfileId: 'mgr',
        fileName: 'طلب.pdf',
      ).ok,
      isFalse,
    );
    expect(agent.inbox(store, 'pharmacy'), isEmpty);

    expect(
      agent.setEnabled(
        store: store,
        unitId: 'labs',
        managerProfileId: 'mgr',
        enabled: true,
      ).ok,
      isTrue,
    );
    final sent = agent.exchangeFile(
      store: store,
      fromUnitId: 'labs',
      toUnitId: 'pharmacy',
      actorProfileId: 'mgr',
      fileName: 'طلب.pdf',
      note: 'مرفق الطلب',
      sizeBytes: 12,
    );
    expect(sent.ok, isTrue);
    final received = agent.inbox(store, 'pharmacy').single;
    expect(received['fileName'], 'طلب.pdf');
    expect(received['serverDeliveryConfirmed'], isFalse);
    expect(received['interpreted'], isFalse);
    expect(received.containsKey('allergies'), isFalse);
    expect(agent.inbox(store, 'labs').single['status'], 'localSent');

    membership.accredit(
      store: store,
      unitId: 'women',
      profileId: 'mgr',
      displayName: 'مدير',
    );
    agent.setEnabled(
      store: store,
      unitId: 'women',
      managerProfileId: 'mgr',
      enabled: true,
    );
    final privateFile = agent.exchangeFile(
      store: store,
      fromUnitId: 'women',
      toUnitId: 'hospital',
      actorProfileId: 'mgr',
      fileName: 'متابعة.pdf',
    );
    expect(privateFile.ok, isTrue);
    expect(agent.inbox(store, 'hospital').single['privateFile'], isTrue);

    agent.release(store: store, unitId: 'labs');
    expect(agent.isEnabled(store, 'labs'), isFalse);
  });
}
