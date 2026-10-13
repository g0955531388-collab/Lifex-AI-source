import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/tv_layout.dart';

void main() {
  test('هاتف عمودي يبقى عموداً واحداً', () {
    final layout = TvLayout.forSize(const Size(360, 800));
    expect(layout.television, isFalse);
    expect(layout.maxContentWidth, 1080);
    expect(layout.actionColumns, 1);
    expect(layout.overscan, 0);
  });

  test('شاشة تلفزيون 960 تكبر النص وتترك هامش أمان', () {
    final layout = TvLayout.forSize(const Size(960, 540));
    expect(layout.television, isTrue);
    expect(layout.overscan, 48);
    expect(layout.textScale, 1.15);
    expect(layout.actionColumns, 2);
    expect(layout.maxContentWidth, 864);
  });

  test('شاشة عريضة تفتح ثلاثة أعمدة', () {
    final layout = TvLayout.forSize(const Size(1920, 1080));
    expect(layout.television, isTrue);
    expect(layout.actionColumns, 3);
    expect(layout.maxContentWidth, 1600);
  });
}
