import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  late HealthProfile profile;
  late ProfileBoxStore store;

  setUp(() {
    profile = HealthProfile(
      profileId: 'profile-1',
      fullName: 'Test Patient',
      dateOfBirth: DateTime(1990, 1, 1),
    );
    store = ProfileBoxStore(profile);
  });

  test('records can be edited without changing their identity', () {
    final record = store.add('notes', {'title': 'Before'});
    final id = record['id'] as String;

    expect(store.updateById('notes', id, {'title': 'After', 'id': 'spoofed'}), isTrue);
    final updated = store.list('notes').single;
    expect(updated['title'], 'After');
    expect(updated['id'], id);
    expect(updated['createdAt'], record['createdAt']);
    expect(updated['updatedAt'], isNotNull);
  });

  test('legacy removeAt archives and restore brings the record back', () {
    final record = store.add('notes', {'title': 'Keep me'});
    final id = record['id'] as String;

    // ignore: deprecated_member_use_from_same_package
    store.removeAt('notes', 0);

    expect(store.activeRecords('notes'), isEmpty);
    expect(store.archivedRecords('notes'), hasLength(1));
    expect(store.restoreArchivedById('notes', id), isTrue);
    expect(store.activeRecords('notes').single['title'], 'Keep me');
  });
}
