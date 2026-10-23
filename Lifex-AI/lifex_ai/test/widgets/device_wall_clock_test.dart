import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/widgets/device_wall_clock.dart';

void main() {
  test('الوقت والتاريخ من لحظة محلية بلا نشاط مستقل', () {
    const clock = DeviceWallClock();
    final moment = DateTime(2026, 10, 12, 9, 5, 7);
    expect(clock.timeLabel(moment), '09:05:07');
    expect(clock.dateLabel(moment), 'الاثنين، 12 أكتوبر 2026');
  });
}
