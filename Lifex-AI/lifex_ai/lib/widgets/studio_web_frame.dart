/// =============================================================
/// Lifex-AI — إطار صفحة الويب
/// يضع كل الشاشات في عمود وسط كما في موقع الاستوديو.
/// =============================================================
library lifex_ai.widgets.studio_web_frame;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_constants.dart';
import '../core/studio_theme.dart';
import '../core/tv_layout.dart';
import '../features/network_box/studio_portal_catalog.dart';
import 'lifex_app_title.dart';
import 'studio_menu_bar.dart';

class StudioWebCanvas extends StatelessWidget {
  const StudioWebCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = TvLayout.forSize(MediaQuery.sizeOf(context));
    final theme = Theme.of(context);
    final framed = FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: child,
    );
    // لا MediaQuery حول المتصفح. نسخة منه داخل builder تُزال وعليها تابع،
    // فتظهر الشاشة الحمراء `_dependents.isEmpty` على كل انتقال.
    final body = layout.television
        ? Theme(
            data: theme.copyWith(
              visualDensity: VisualDensity.comfortable,
              focusColor: theme.colorScheme.primary.withOpacity(0.28),
              textTheme: theme.textTheme.apply(
                fontSizeFactor: layout.textScale.clamp(1.0, 1.6),
              ),
            ),
            child: framed,
          )
        : framed;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.all(layout.overscan),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
            child: body,
          ),
        ),
      ),
    );
  }
}

class StudioWebHero extends StatelessWidget {
  const StudioWebHero({
    super.key,
    required this.onStart,
    required this.onExplore,
    required this.onLogin,
    required this.onServices,
    required this.onEmergency,
  });

  final VoidCallback onStart;
  final VoidCallback onExplore;
  final VoidCallback onLogin;
  final VoidCallback onServices;
  final VoidCallback onEmergency;

  bool get _arabic => AppConfig.instance.defaultLanguage != AppLanguage.english;

  @override
  Widget build(BuildContext context) {
    final arabic = _arabic;
    final theme = Theme.of(context);
    final ownership = arabic
        ? AppConstants.ownershipStatementShort
        : AppConstants.ownershipStatementShortEn;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StudioTheme.teal.withOpacity(0.16),
            StudioTheme.indigo.withOpacity(0.10),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            const _Pill(
              icon: Icons.monitor_heart_outlined,
              label: 'Lifex-AI v${AppConstants.appVersion}',
              color: StudioTheme.tealBright,
            ),
            const SizedBox(height: 8),
            Text(
              ownership,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            LifexAppTitle(
              centered: true,
              markSize: 32,
              lineSize: 16,
              markColor: StudioTheme.tealBright,
              lineColor: theme.textTheme.headlineSmall?.color,
            ),
            const SizedBox(height: 6),
            Text(
              arabic
                  ? 'على هذا الجهاز'
                  : 'On this device',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              arabic
                  ? 'تربط الملف والرعاية والأجهزة والمرجع المحلي في مكان واحد. السجلات تبقى على الجهاز حتى موافقة صريحة.'
                  : 'It links the record, care, devices, and the local reference in one place. Records stay on the device until you give explicit consent.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              StudioPortalCatalog.disclaimer(arabic),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onStart,
                  icon: Icon(Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_back
                      : Icons.arrow_forward),
                  label: Text(arabic ? 'ابدأ الآن' : 'Get Started'),
                ),
                OutlinedButton.icon(
                  onPressed: onExplore,
                  icon: const Icon(Icons.public, color: StudioTheme.tealBright),
                  label: Text(arabic ? 'استكشف Lifex-AI' : 'Explore Lifex-AI'),
                ),
                OutlinedButton.icon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.group_outlined,
                      color: StudioTheme.indigo),
                  label: Text(arabic ? 'تسجيل الدخول' : 'Sign In'),
                ),
                OutlinedButton.icon(
                  onPressed: onServices,
                  icon: const Icon(Icons.medical_services_outlined,
                      color: StudioTheme.purpleSoft),
                  label: Text(arabic ? 'الخدمات الصحية' : 'Health Services'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: StudioTheme.rose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onEmergency,
                  icon: const Icon(Icons.local_fire_department_outlined),
                  label: Text(arabic ? 'طلب طوارئ فوري' : 'Instant Emergency'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HonestMetrics(arabic: arabic),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HonestMetrics extends StatelessWidget {
  const _HonestMetrics({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final items = arabic
        ? const [
            ('على الجهاز', 'السجلات لا تُرسل وحدها'),
            ('ليست تشخيصاً', 'الملاحظة تبقى ملاحظة'),
            ('بتأكيدك', 'الطوارئ لا تُطلق وحدها'),
            ('بلا مفتاح', 'المرجع المحلي يبقى متاحاً'),
          ]
        : const [
            ('On device', 'Records are not sent on their own'),
            ('Not a diagnosis', 'An observation stays an observation'),
            ('Your confirmation', 'Emergency is not fired alone'),
            ('No key required', 'The local reference stays available'),
          ];
    final colors = [
      StudioTheme.tealBright,
      StudioTheme.indigo,
      StudioTheme.purpleSoft,
      StudioTheme.teal,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final width = (constraints.maxWidth - (8 * (columns - 1))) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          items[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors[i],
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class StudioPortalGrid extends StatelessWidget {
  const StudioPortalGrid({super.key, required this.onPortal});

  final void Function(StudioPortal portal) onPortal;

  @override
  Widget build(BuildContext context) {
    final arabic = AppConfig.instance.defaultLanguage != AppLanguage.english;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          StudioPortalCatalog.servicesTitle(arabic),
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          StudioPortalCatalog.honesty(arabic),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - (10 * (columns - 1))) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final portal in StudioPortalCatalog.portals)
                  SizedBox(
                    width: width,
                    child: _PortalCard(
                      portal: portal,
                      arabic: arabic,
                      onTap: () => onPortal(portal),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.portal,
    required this.arabic,
    required this.onTap,
  });

  final StudioPortal portal;
  final bool arabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = portal.title(arabic);
    final subtitle = portal.subtitle(arabic);
    final urgent = portal.id == StudioPortalId.emergency;
    final accent = urgent
        ? StudioTheme.rose
        : portal.id == StudioPortalId.ai
            ? StudioTheme.purple
            : StudioTheme.tealBright;
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          focusColor: accent.withOpacity(0.22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Icon(studioPortalIcon(portal.id), color: accent),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
