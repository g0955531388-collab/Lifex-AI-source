/// =============================================================
/// Lifex-AI — Clock abstraction (للاختبارات الحتمية)
/// =============================================================
library lifex_ai.core.orchestrator.clock;

/// ساعة قابلة للحقن — الإنتاج يستخدم [SystemClock]، الاختبارات [FixedClock].
abstract class LifexClock {
  DateTime now();
}

class SystemClock implements LifexClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class FixedClock implements LifexClock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration by) {
    _now = _now.add(by);
  }

  void set(DateTime value) {
    _now = value.toUtc();
  }
}
