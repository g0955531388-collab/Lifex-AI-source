/// وضع المشي: يُنطق ما ظهر جديداً في الإطار، ويُكتم ما لم يتغير.
library lifex_ai.features.accessibility.scan_mode;

List<String> scanSpeechDelta({
  required List<String> previous,
  required List<String> next,
}) {
  final seen = previous
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
  final added = <String>[];
  for (final item in next) {
    final name = item.trim();
    if (name.isEmpty || seen.contains(name) || added.contains(name)) continue;
    added.add(name);
  }
  return added;
}
