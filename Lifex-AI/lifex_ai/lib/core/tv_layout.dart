/// =============================================================
/// Lifex-AI — مقاس غرفة المعيشة
/// الشاشة العريضة الأفقية تُعامل كتلفزيون: هامش أمان، نص أكبر، أعمدة.
/// الهاتف يبقى عموداً بعرض 1080 كحد.
/// =============================================================
library lifex_ai.core.tv_layout;

import 'dart:ui';

class TvLayout {
  const TvLayout({
    required this.television,
    required this.overscan,
    required this.textScale,
    required this.maxContentWidth,
    required this.actionColumns,
  });

  final bool television;
  final double overscan;
  final double textScale;
  final double maxContentWidth;
  final int actionColumns;

  static TvLayout forSize(Size size) {
    final landscape = size.width > size.height;
    final livingRoom = landscape && size.width >= 960 && size.shortestSide >= 540;
    if (!livingRoom) {
      return const TvLayout(
        television: false,
        overscan: 0,
        textScale: 1,
        maxContentWidth: 1080,
        actionColumns: 1,
      );
    }
    final overscan = size.shortestSide >= 720 ? 64.0 : 48.0;
    final inner = (size.width - overscan * 2).clamp(720.0, 1600.0);
    return TvLayout(
      television: true,
      overscan: overscan,
      textScale: 1.15,
      maxContentWidth: inner,
      actionColumns: inner >= 1400 ? 3 : 2,
    );
  }
}
