import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/clock/speaking_alarm_book.dart';

void main() {
  test('المنبه داخل النطاق وخارجه وبلا نقطة مؤكدة', () {
    expect(
      judgeSpeakingAlarm(
        latitude: 33.5,
        longitude: 36.3,
        radiusMeters: 200,
        hereLatitude: 33.5,
        hereLongitude: 36.3,
        accuracyMeters: 20,
      ),
      AlarmPlace.inside,
    );
    expect(
      judgeSpeakingAlarm(
        latitude: 33.5,
        longitude: 36.3,
        radiusMeters: 200,
        hereLatitude: 34.5,
        hereLongitude: 36.3,
        accuracyMeters: 20,
      ),
      AlarmPlace.outside,
    );
    expect(
      judgeSpeakingAlarm(
        latitude: 33.5,
        longitude: 36.3,
        radiusMeters: 200,
        hereLatitude: 33.5,
        hereLongitude: 36.3,
        accuracyMeters: 800,
      ),
      AlarmPlace.unconfirmed,
    );
    expect(
      judgeSpeakingAlarm(
        latitude: 33.5,
        longitude: 36.3,
        radiusMeters: 200,
        hereLatitude: null,
        hereLongitude: null,
        accuracyMeters: null,
      ),
      AlarmPlace.unconfirmed,
    );
  });

  test('عبارة المنبه تذكر الاسم والمكان بلا عنوان شارع', () {
    final phrase = speakingAlarmPhrase(
      name: 'البيت',
      timeLabel: '07:30',
      place: AlarmPlace.inside,
      arabic: true,
    );
    expect(phrase, contains('البيت'));
    expect(phrase, contains('07:30'));
    expect(phrase, contains('ضمن نطاق'));
    expect(phrase.contains('شارع'), isFalse);
  });

  test('منبه بلا اسم أو بنطاق غير صالح لا يُحفظ', () {
    expect(
      SpeakingAlarm.fromJson({
        'id': 'a',
        'name': '  ',
        'hour': 7,
        'minute': 30,
        'enabled': true,
        'latitude': 1,
        'longitude': 2,
        'radiusMeters': 200,
      }),
      isNull,
    );
    final alarm = SpeakingAlarm.fromJson({
      'id': 'a',
      'name': 'العمل',
      'hour': 7,
      'minute': 30,
      'enabled': true,
      'latitude': 1.5,
      'longitude': 2.5,
      'radiusMeters': 200,
    });
    expect(alarm?.name, 'العمل');
    expect(alarm?.hour, 7);
    expect(alarm?.speechCue, isTrue);
    expect(alarm?.toneUri, isEmpty);
  });
}
