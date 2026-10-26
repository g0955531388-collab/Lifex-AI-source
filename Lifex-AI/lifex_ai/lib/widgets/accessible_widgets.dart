/// =============================================================
/// Lifex-AI — المكوّنات المشتركة
/// الملف: accessible_widgets.dart
/// المسار: lib/widgets/accessible_widgets.dart
/// الوصف: مكوّنات واجهة قياسية تضمن توافق كل شاشات التطبيق مع قارئ
/// الشاشة المدمج في نظام التشغيل (TalkBack على أندرويد، VoiceOver على
/// iOS)، بدلاً من الاعتماد فقط على النطق الصوتي المخصص لدينا
/// (voice_engine.dart). هذا الملف هو الحل لمشكلة "عناصر واجهة بلا
/// تسميات دلالية" التي كانت موجودة في الشاشات السابقة.
///
/// لماذا هذا مهم تحديداً لتطبيق يخدم المكفوفين: قارئ الشاشة لا يقرأ
/// المظهر البصري للعنصر، بل يقرأ خاصية Semantics.label المرفقة به. أي
/// شاشة جديدة في المشروع يجب أن تستخدم هذه المكوّنات بدلاً من
/// IconButton/Card العادية مباشرة، لضمان اتساق إمكانية الوصول عبر كل
/// التطبيق دون نسيانها في شاشة بعينها.
/// =============================================================
library lifex_ai.widgets.accessible_widgets;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../core/app_config.dart';
import '../features/accessibility/screen_voice_board.dart';
import '../features/voice/voice_engine.dart';

/// زر إجراء كبير بتسمية دلالية واضحة وحجم لمسة كافٍ (لا يقل عن 48×48
/// نقطة منطقية، وهو الحد الأدنى الموصى به عالمياً لإمكانية الوصول).
class AccessibleActionButton extends StatelessWidget {
  const AccessibleActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticHint,
    this.onTap,
    this.isUrgent = false,
    this.disabledHint = 'هذه الميزة غير متاحة بعد.',
  });

  final IconData icon;
  final String label;

  /// وصف إضافي يُقرأ لقارئ الشاشة يوضّح ماذا يحدث عند الضغط (مثلاً
  /// "يفتح صفحة الملف الصحي")، وليس فقط اسم الزر.
  final String semanticHint;
  final VoidCallback? onTap;
  final bool isUrgent;

  /// يُقرأ عندما يكون الزر بلا فعل. الافتراضي للميزة غير المبنية.
  final String disabledHint;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    // اللون الرمادي المعطَّل له أولوية دائماً على لون الإلحاح (isUrgent)؛
    // زر طوارئ لا معنى لتعطيله عملياً، لكن هذا يضمن السلوك الصحيح لو
    // حدث ذلك مستقبلاً في أي زر آخر.
    final color = isDisabled
        ? Theme.of(context).disabledColor
        : (isUrgent
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary);

    // قارئ الشاشة يجب أن يُعلن صراحة أن العنصر "معطَّل" (disabled: true
    // في Semantics)، وليس مجرد صمت أو رسالة عامة — هذا يمنع خلط
    // المستخدم الكفيف بين "هذا الزر لا يعمل بعد" و"حدث خطأ عند الضغط".
    final effectiveHint = isDisabled ? disabledHint : semanticHint;

    final forward = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
    return Semantics(
      button: true,
      label: label,
      hint: effectiveHint,
      enabled: !isDisabled,
      container: true,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            elevation: 0,
            child: InkWell(
              onTap: onTap,
              focusColor: color.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 24, color: color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isUrgent && !isDisabled
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isDisabled
                                  ? Theme.of(context).disabledColor
                                  : (isUrgent ? color : null),
                            ),
                          ),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(forward, color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// نص عادي لكنه يُعلن (Announce) نفسه فوراً لقارئ الشاشة عند ظهوره —
/// مفيد لرسائل حالة الطوارئ أو نتائج تحليل الكاميرا المساعدة، حيث يجب
/// أن يسمع المستخدم الكفيف الرسالة فوراً دون الحاجة للتنقل يدوياً
/// إليها بإصبعه على الشاشة.
class LiveAnnouncingText extends StatelessWidget {
  const LiveAnnouncingText({
    super.key,
    required this.message,
    this.style,
  });

  final String message;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true, // يخبر قارئ الشاشة بقراءة هذا فور تحديثه
      label: message,
      child: Text(message, style: style),
    );
  }
}

/// قراءة بلا تسجيل تابع. `of()` أثناء الإغلاق يعيد ربط العنصر
/// بالموروث الذي يُزال، فيفشل فحص `_dependents.isEmpty`.
TextDirection lifexTextDirection(BuildContext context) {
  if (!context.mounted) return _lifexFallbackDirection();
  try {
    return context.getInheritedWidgetOfExactType<Directionality>()?.textDirection ??
        _lifexFallbackDirection();
  } on FlutterError {
    return _lifexFallbackDirection();
  }
}

TextDirection _lifexFallbackDirection() =>
    AppConfig.instance.defaultLanguage == AppLanguage.arabic
        ? TextDirection.rtl
        : TextDirection.ltr;

/// هل قارئ الشاشة في النظام شغّال، دون الاشتراك في إعادة البناء.
bool lifexScreenReaderOn(BuildContext context) {
  if (!context.mounted) return false;
  try {
    return context
            .getInheritedWidgetOfExactType<MediaQuery>()
            ?.data
            .accessibleNavigation ??
        false;
  } on FlutterError {
    return false;
  }
}

/// دالة مساعدة لإجبار قارئ الشاشة على الإعلان الفوري عن رسالة معيّنة
/// (مثلاً نتيجة تحليل الكاميرا فور جاهزيتها)، حتى لو لم يكن تركيز
/// قارئ الشاشة على هذا العنصر أصلاً.
void announceForScreenReader(BuildContext context, String message) {
  if (!context.mounted || message.isEmpty) return;
  SemanticsService.announce(message, lifexTextDirection(context));
}

/// عبارات الوصول التي يسمعها المكفوف. بلا مشهد أو مسافة مخترعة.
class BlindNavigationCopy {
  const BlindNavigationCopy._();

  static const needsProfile = 'أنشئ ملفك الصحي أولاً من زر ملفي الصحي.';
  static const needsProfileEn =
      'Create your health profile first with My health profile.';

  static const splashArrival =
      'Lifex-AI. زر الدخول ينقلك للخطوة التالية. نص الملكية أسفل الشاشة.';
  static const splashArrivalEn =
      'Lifex-AI. The Enter button continues. The ownership text is at the bottom of the screen.';

  static const obstacleUnavailable =
      'كشف المسافة غير متاح على هذا الهاتف. العصا البيضاء تبقى وسيلة السلامة. الكاميرا لا تعطي متراً.';
  static const obstacleUnavailableEn =
      'Distance detection is not available on this phone. The white cane remains the safety aid. The camera does not give a distance.';

  static const profileArrival =
      'إنشاء الملف. ابدأ بالاسم الكامل، ثم العمر بعدد السنوات. تاريخ الميلاد اختياري.';
  static const profileArrivalEn =
      'Creating the profile. Start with the full name, then age in years. Date of birth is optional.';

  static String get needsProfileText => lifexUi(needsProfile, needsProfileEn);

  static String get splashArrivalText => lifexUi(splashArrival, splashArrivalEn);

  static String get obstacleUnavailableText =>
      lifexUi(obstacleUnavailable, obstacleUnavailableEn);

  static String get profileArrivalText =>
      lifexUi(profileArrival, profileArrivalEn);

  static String homeArrival({required bool hasProfile}) {
    if (hasProfile) {
      return lifexUi(
        'الرئيسية. مرّر بين الأزرار. كل زر يعلن اسمه وما يفتحه.',
        'Home. Move between the buttons. Each button says its name and what it opens.',
      );
    }
    return lifexUi(
      'الرئيسية. ابدأ بزر ملفي الصحي. بقية الأزرار تنتظر هذا الملف.',
      'Home. Start with My health profile. The other buttons wait for that profile.',
    );
  }
}

/// يعلن عنوان الشاشة مرة لقارئ الشاشة. النطق الإضافي يبقى إذا كان
/// الإرشاد الصوتي مفتوحاً وقارئ الشاشة نفسه غير شغّال، حتى لا يُكرَّر الصوت.
class ScreenArrival extends StatefulWidget {
  const ScreenArrival({
    super.key,
    required this.message,
    this.controls = const [],
    this.body = '',
    required this.child,
  });

  final String message;
  final List<String> controls;
  final String body;
  final Widget child;

  @override
  State<ScreenArrival> createState() => _ScreenArrivalState();
}

class _ScreenArrivalState extends State<ScreenArrival> {
  @override
  void initState() {
    super.initState();
    _publish();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.message.isEmpty) return;
      announceForScreenReader(context, widget.message);
      if (!lifexScreenReaderOn(context) &&
          AppConfig.instance.voiceGuidanceEnabledByDefault) {
        unawaited(VoiceEngine.instance.speak(widget.message));
      }
    });
  }

  @override
  void didUpdateWidget(ScreenArrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  @override
  void dispose() {
    ScreenVoiceBoard.instance.remove(this);
    super.dispose();
  }

  void _publish() {
    ScreenVoiceBoard.instance.upsert(
      ScreenVoiceCard(
        token: this,
        titleAr: widget.message,
        controlsAr: widget.controls,
        bodyAr: widget.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      explicitChildNodes: true,
      label: widget.message,
      child: widget.child,
    );
  }
}
