/// يفصل وثائق JSON المتتالية في ملف واحد. الوثيقة المكسورة تُتجاوز.
library lifex_ai.core.json_documents;

import 'dart:convert';

/// نهاية القيمة التي تبدأ عند [start]، أو فراغ إن لم يُغلق القوس.
int? endOfJsonValue(String raw, int start) {
  if (start < 0 || start >= raw.length) return null;
  final opener = raw[start];
  if (opener != '{' && opener != '[') return null;
  final stack = <String>[opener];
  var inString = false;
  var escape = false;
  for (var i = start + 1; i < raw.length; i++) {
    final ch = raw[i];
    if (inString) {
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\') {
        escape = true;
        continue;
      }
      if (ch == '"') inString = false;
      continue;
    }
    if (ch == '"') {
      inString = true;
      continue;
    }
    if (ch == '{' || ch == '[') {
      stack.add(ch);
      continue;
    }
    if (ch == '}' || ch == ']') {
      if (stack.isEmpty) return null;
      final open = stack.removeLast();
      final matched = (ch == '}' && open == '{') || (ch == ']' && open == '[');
      if (!matched) return null;
      if (stack.isEmpty) return i + 1;
    }
  }
  return null;
}

/// كل قيمة عُليا صالحة. ما انكسر بين القيم لا يُسقط القيم التي بعده.
List<Object?> splitJsonDocuments(String raw) {
  final out = <Object?>[];
  var i = 0;
  while (i < raw.length) {
    final ch = raw[i];
    if (ch.trim().isEmpty || ch == '\uFEFF') {
      i++;
      continue;
    }
    if (ch != '{' && ch != '[') {
      i++;
      continue;
    }
    final end = endOfJsonValue(raw, i);
    if (end == null) {
      i++;
      continue;
    }
    try {
      out.add(jsonDecode(raw.substring(i, end)));
      i = end;
    } catch (_) {
      i++;
    }
  }
  return out;
}
