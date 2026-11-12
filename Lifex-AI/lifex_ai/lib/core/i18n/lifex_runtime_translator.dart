/// ترجمة الواجهة وقت البناء. المفتاح هو النص العربي المكتوب في المصدر.
/// الكتب الطبية والمرجع العام والهواتف والمبالغ ليست في الجدول فتبقى كما هي.
library lifex_ai.core.i18n.lifex_runtime_translator;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../app_config.dart';

class LifexRuntimeTranslator {
  LifexRuntimeTranslator._();

  static final LifexRuntimeTranslator instance = LifexRuntimeTranslator._();

  static const assetPath = 'assets/i18n/ui_en.json';

  static final _arabic = RegExp(r'[\u0600-\u06FF]');
  static final _slot = RegExp(r'\{(\d+)\}');

  final Map<String, String> _exact = {};
  final List<_Template> _templates = [];
  final Map<String, String> _cache = {};

  int get size => _exact.length + _templates.length;

  static Future<void> loadAsset() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        instance.load({
          for (final entry in decoded.entries) '${entry.key}': '${entry.value}',
        });
      }
    } catch (_) {}
  }

  void load(Map<String, String> table) {
    _exact.clear();
    _templates.clear();
    _cache.clear();
    for (final entry in table.entries) {
      final english = entry.value.trim();
      if (english.isEmpty) continue;
      if (_slot.hasMatch(entry.key)) {
        final template = _Template.parse(entry.key, entry.value);
        if (template != null) _templates.add(template);
      } else {
        _exact[entry.key] = entry.value;
      }
    }
    _templates.sort((a, b) => b.literalLength.compareTo(a.literalLength));
  }

  bool get english =>
      AppConfig.instance.defaultLanguage == AppLanguage.english;

  String translate(String text) {
    if (!english || text.isEmpty || !_arabic.hasMatch(text)) return text;
    return translateToEnglish(text);
  }

  /// يترجم بلا النظر إلى اللغة الحاكمة. للاختبارات والأدوات.
  String translateToEnglish(String text) {
    final exact = _exact[text];
    if (exact != null) return exact;
    final cached = _cache[text];
    if (cached != null) return cached;
    var result = text;
    for (final template in _templates) {
      final filled = template.fill(text, translateToEnglish);
      if (filled != null) {
        result = filled;
        break;
      }
    }
    if (_cache.length > 4000) _cache.clear();
    _cache[text] = result;
    return result;
  }

  bool hasEntry(String arabicTemplate) =>
      _exact.containsKey(arabicTemplate) ||
      _templates.any((t) => t.source == arabicTemplate);
}

class _Template {
  _Template(this.source, this.pattern, this.english, this.literalLength,
      this.anchor);

  final String source;
  final RegExp pattern;
  final String english;
  final int literalLength;
  final String anchor;

  static _Template? parse(String arabic, String english) {
    final slots = <int>[];
    final buffer = StringBuffer('^');
    var last = 0;
    var literal = 0;
    var anchor = '';
    for (final match in LifexRuntimeTranslator._slot.allMatches(arabic)) {
      final piece = arabic.substring(last, match.start);
      literal += piece.length;
      if (piece.length > anchor.length) anchor = piece;
      buffer.write(RegExp.escape(piece));
      buffer.write(r'([\s\S]*?)');
      slots.add(int.parse(match[1]!));
      last = match.end;
    }
    final tail = arabic.substring(last);
    literal += tail.length;
    if (tail.length > anchor.length) anchor = tail;
    buffer.write(RegExp.escape(tail));
    buffer.write(r'$');
    if (literal == 0) return null;
    return _Template(
      arabic,
      RegExp(buffer.toString()),
      english,
      literal,
      anchor,
    )..slots.addAll(slots);
  }

  final List<int> slots = [];

  String? fill(String text, String Function(String) inner) {
    if (anchor.isNotEmpty && !text.contains(anchor)) return null;
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    final values = <int, String>{};
    for (var i = 0; i < slots.length; i++) {
      final value = match.group(i + 1) ?? '';
      values[slots[i]] = inner(value);
    }
    return english.replaceAllMapped(LifexRuntimeTranslator._slot, (m) {
      return values[int.parse(m[1]!)] ?? m[0]!;
    });
  }
}

/// نص واجهة يتبع اللغة الحاكمة. بالعربية يعود كما هو، والفارغ يبقى فارغاً.
T tr<T extends String?>(T text) {
  final value = text;
  if (value == null) return text;
  return LifexRuntimeTranslator.instance.translate(value) as T;
}
