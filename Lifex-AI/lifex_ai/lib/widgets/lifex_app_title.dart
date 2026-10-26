/// اسم التطبيق على سطرين ثابتين: العلامة، ثم الشبكة.
library lifex_ai.widgets.lifex_app_title;

import 'package:flutter/material.dart';

class LifexAppTitle extends StatelessWidget {
  const LifexAppTitle({
    super.key,
    this.centered = false,
    this.markSize = 22,
    this.lineSize = 13,
    this.markColor,
    this.lineColor,
  });

  final bool centered;
  final double markSize;
  final double lineSize;
  final Color? markColor;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    final align =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'Lifex-AI',
          textAlign: textAlign,
          style: TextStyle(
            color: markColor,
            fontSize: markSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Global Health Network',
          textAlign: textAlign,
          style: TextStyle(
            color: lineColor,
            fontSize: lineSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
