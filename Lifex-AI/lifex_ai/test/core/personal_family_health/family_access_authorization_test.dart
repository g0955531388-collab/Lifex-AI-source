import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/personal_family_health/personal_health_engine.dart';
import 'package:lifex_ai/core/personal_family_health/personal_health_repository.dart';
import 'package:lifex_ai/core/personal_family_health/personal_health_types.dart';

void main() {
  test('عضوية العائلة لا تمنح قراءة السجل بلا تفويض', () async {
    final engine = LifexPersonalFamilyHealthEngine();
    final at = DateTime.utc(2026, 10, 21);
    await engine.createPatient(
      PatientRecord(
        patientId: 'patient-1',
        personId: 'person-1',
        identityId: 'identity-1',
        createdAt: at,
        updatedAt: at,
      ),
    );
    await engine.createFamily(
      FamilyGroup(familyId: 'family-1', name: 'أسرة', createdAt: at),
    );
    await engine.addFamilyMember(
      FamilyMembership(
        membershipId: 'm-1',
        familyId: 'family-1',
        personId: 'relative-1',
        role: FamilyRole.member,
        joinedAt: at,
      ),
    );

    expect(engine.isFamilyMember('family-1', 'relative-1'), isTrue);
    expect(engine.familyMembershipGrantsAccess(), isFalse);
    expect(
      engine.authorize(
        actorId: 'relative-1',
        patientId: 'patient-1',
        scope: HealthDataScope.conditions,
        purpose: ConsentPurpose.familyCare,
        at: at,
      ),
      isFalse,
    );

    final repository = InMemoryPersonalHealthRepository(engine);
    expect(
      await repository.getPatient(
        actorId: 'relative-1',
        patientId: 'patient-1',
        at: at,
      ),
      isNull,
    );
    expect(
      await repository.getConditions(
        actorId: 'relative-1',
        patientId: 'patient-1',
        at: at,
      ),
      isEmpty,
    );
    expect(
      await repository.getPatient(
        actorId: 'person-1',
        patientId: 'patient-1',
        at: at,
      ),
      isNotNull,
    );
  });
}
