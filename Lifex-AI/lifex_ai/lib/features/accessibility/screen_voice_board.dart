/// لوحة قراءة واحدة للشاشة الظاهرة. الشاشات تسجّل نصها ولا تنشئ قارئاً.
library lifex_ai.features.accessibility.screen_voice_board;

class ScreenVoiceCard {
  const ScreenVoiceCard({
    required this.token,
    required this.titleAr,
    this.controlsAr = const [],
    this.bodyAr = '',
  });

  final Object token;
  final String titleAr;
  final List<String> controlsAr;
  final String bodyAr;

  String readingAr() {
    final parts = <String>[];
    final title = titleAr.trim();
    if (title.isNotEmpty) parts.add('الشاشة: $title');
    if (controlsAr.isNotEmpty) {
      parts.add('العناصر: ${controlsAr.join('، ')}');
    }
    final body = bodyAr.trim();
    if (body.isNotEmpty) parts.add(body);
    if (parts.isEmpty) return 'هذه الشاشة لم تسجّل نصاً للقراءة بعد.';
    return parts.join('. ');
  }
}

class ScreenVoiceBoard {
  ScreenVoiceBoard._();

  static final ScreenVoiceBoard instance = ScreenVoiceBoard._();

  final List<ScreenVoiceCard> _stack = [];

  ScreenVoiceCard? get current => _stack.isEmpty ? null : _stack.last;

  int get depth => _stack.length;

  void upsert(ScreenVoiceCard card) {
    final index = _stack.indexWhere((item) => identical(item.token, card.token));
    if (index >= 0) {
      _stack[index] = card;
      return;
    }
    _stack.add(card);
  }

  void remove(Object token) {
    _stack.removeWhere((item) => identical(item.token, token));
  }

  String readingAr() {
    final card = current;
    if (card == null) return 'هذه الشاشة لم تسجّل نصاً للقراءة بعد.';
    return card.readingAr();
  }

  void clearForTest() => _stack.clear();
}
