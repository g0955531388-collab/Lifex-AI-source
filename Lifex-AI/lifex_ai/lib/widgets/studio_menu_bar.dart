/// =============================================================
/// Lifex-AI — شريط قوائم الاستوديو
/// نفس ترتيب google-studio: شريط الهوية ثم الروابط ثم البوابات.
/// شعار Lifex يبقى أيقونة النشاط الصحي، بلا شعار جهة أخرى.
/// =============================================================
library lifex_ai.widgets.studio_menu_bar;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import '../core/app_constants.dart';
import '../core/attribution/project_attribution.dart';
import '../core/studio_theme.dart';
import '../features/network_box/studio_portal_catalog.dart';
import '../screens/data_records_screen.dart';
import 'lifex_app_title.dart';

class StudioMenuBar extends StatelessWidget {
  const StudioMenuBar({
    super.key,
    required this.onPortal,
    required this.onSearch,
    required this.onAccount,
    required this.onEmergency,
    this.activePortalId,
    this.includeBanner = true,
  });

  final void Function(StudioPortal portal) onPortal;
  final VoidCallback onSearch;
  final VoidCallback onAccount;
  final VoidCallback onEmergency;
  final StudioPortalId? activePortalId;
  final bool includeBanner;

  bool get _arabic => AppConfig.instance.defaultLanguage != AppLanguage.english;

  StudioPortal? _portal(StudioPortalId? id) {
    if (id == null) return null;
    for (final portal in StudioPortalCatalog.portals) {
      if (portal.id == id) return portal;
    }
    return null;
  }

  Color _accent(StudioMenuAccent accent, bool selected) {
    switch (accent) {
      case StudioMenuAccent.purple:
        return selected ? StudioTheme.purpleSoft : StudioTheme.purple;
      case StudioMenuAccent.rose:
        return StudioTheme.rose;
      case StudioMenuAccent.teal:
        return selected ? StudioTheme.tealBright : StudioTheme.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudioThemeController.instance,
      builder: (context, _) {
        final arabic = _arabic;
        final contrast =
            AppConfig.instance.appearance == StudioAppearance.contrast;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final bar = contrast
            ? Colors.black
            : (dark ? StudioTheme.slate950 : Colors.white);
        final ink = contrast
            ? Colors.white
            : (dark ? StudioTheme.slate100 : StudioTheme.slate900);
        final muted = contrast
            ? StudioTheme.amber
            : (dark ? StudioTheme.slate400 : StudioTheme.slate800);
        final line = contrast
            ? StudioTheme.amber
            : (dark ? StudioTheme.slate800 : StudioTheme.slate200);
        return Material(
          color: bar,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (includeBanner) const AttributionMarqueeBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandRow(ink: ink, muted: muted),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final item in StudioPortalCatalog.mainNav)
                            _NavButton(
                              label: item.title(arabic),
                              selected: item.portalId == null
                                  ? activePortalId == null
                                  : item.portalId == activePortalId,
                              color: _accent(
                                item.accent,
                                item.portalId == activePortalId ||
                                    (item.portalId == null &&
                                        activePortalId == null),
                              ),
                              onPressed: () {
                                final portal = _portal(item.portalId);
                                if (portal != null) onPortal(portal);
                              },
                            ),
                          _PortalsMenu(
                            arabic: arabic,
                            ink: ink,
                            line: line,
                            bar: bar,
                            onPortal: onPortal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ToolButton(
                            tooltip: arabic
                                ? 'البحث في الوحدات والمرجع المحلي'
                                : 'Search local units and reference',
                            onPressed: onSearch,
                            line: line,
                            ink: ink,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search,
                                    color: StudioTheme.tealBright, size: 18),
                                const SizedBox(width: 6),
                                Text(context.nav('nav.searchHint')),
                              ],
                            ),
                          ),
                          _ToolButton(
                            tooltip: _arabic
                                ? 'تعديل السجلات الشخصية'
                                : 'Edit personal records',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DataRecordsScreen(),
                                ),
                              );
                            },
                            line: line,
                            ink: ink,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined,
                                    color: StudioTheme.teal, size: 18),
                                const SizedBox(width: 6),
                                Text(context.nav('nav.edit')),
                              ],
                            ),
                          ),
                          _ToolButton(
                            tooltip: _arabic
                                ? 'ترجمة عربي أو English'
                                : 'Translate Arabic or English',
                            onPressed:
                                StudioThemeController.instance.toggleLanguage,
                            line: line,
                            ink: ink,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language,
                                    color: StudioTheme.indigo, size: 18),
                                const SizedBox(width: 6),
                                Text(_arabic ? 'العربية' : 'English'),
                              ],
                            ),
                          ),
                          _ToolButton(
                            tooltip: arabic
                                ? 'مظهر الاستوديو: ${AppConfig.instance.appearance.name}'
                                : 'Studio appearance: ${AppConfig.instance.appearance.name}',
                            onPressed:
                                StudioThemeController.instance.cycleAppearance,
                            line: line,
                            ink: ink,
                            child: Icon(
                              AppConfig.instance.appearance ==
                                      StudioAppearance.dark
                                  ? Icons.dark_mode_outlined
                                  : AppConfig.instance.appearance ==
                                          StudioAppearance.light
                                      ? Icons.light_mode_outlined
                                      : Icons.tune,
                              size: 18,
                              color: contrast
                                  ? StudioTheme.amber
                                  : StudioTheme.tealBright,
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: StudioTheme.rose,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 44),
                            ),
                            onPressed: onEmergency,
                            icon: const Icon(
                                Icons.local_fire_department_outlined,
                                size: 18),
                            label: Text(context.nav('nav.sos')),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: StudioTheme.tealBright,
                              side: const BorderSide(color: StudioTheme.teal),
                              minimumSize: const Size(48, 44),
                            ),
                            onPressed: onAccount,
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: Text(context.nav('nav.signIn')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AttributionMarqueeBar extends StatelessWidget {
  const AttributionMarqueeBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudioThemeController.instance,
      builder: (context, _) {
        final arabic =
            AppConfig.instance.defaultLanguage != AppLanguage.english;
        final ownership = arabic
            ? AppConstants.ownershipStatementShort
            : AppConstants.ownershipStatementShortEn;
        final line =
            '${ProjectAttribution.systemName} | AlrohAcademy999 | $ownership | v${AppConstants.appVersion} Official';
        return _NeonAttributionStrip._(line);
      },
    );
  }
}

class _NeonAttributionStrip extends StatelessWidget {
  const _NeonAttributionStrip._(this.line);

  final String line;

  static const neon = Color(0xFF7CFFB2);
  static const glow = Color(0xFF39FF14);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF02140C),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1F8F4E)),
        ),
      ),
      child: SizedBox(
        height: 36,
        child: _NeonMarquee(
          text: line,
          style: const TextStyle(
            color: neon,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            shadows: [
              Shadow(color: glow, blurRadius: 6),
              Shadow(color: glow, blurRadius: 14),
              Shadow(color: Color(0xFF00E5A0), blurRadius: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonMarquee extends StatefulWidget {
  const _NeonMarquee({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_NeonMarquee> createState() => _NeonMarqueeState();
}

class _NeonMarqueeState extends State<_NeonMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _durationMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final loop = painter.width + 64;
    final ms = ((loop / 42) * 1000).round().clamp(9000, 70000);
    if (!reduce && _durationMs != ms) {
      _durationMs = ms;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.duration = Duration(milliseconds: ms);
        _controller.repeat();
      });
    } else if (reduce && _controller.isAnimating) {
      _controller.stop();
    }
    final text = Text(
      widget.text,
      style: widget.style,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: ClipRect(
          child: reduce
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(child: text),
                  ),
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final shift = _controller.value * loop;
                    return Transform.translate(
                      offset: Offset(-shift, 0),
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: loop * 2,
                        maxWidth: loop * 2,
                        child: Row(
                          children: [
                            text,
                            const SizedBox(width: 64),
                            Text(
                              widget.text,
                              style: widget.style,
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                            ),
                            const SizedBox(width: 64),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.ink,
    required this.muted,
  });

  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [StudioTheme.tealBright, StudioTheme.indigo],
            ),
          ),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.monitor_heart_outlined, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LifexAppTitle(
            markSize: 20,
            lineSize: 12,
            markColor: ink,
            lineColor: muted,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: color,
          backgroundColor: selected ? color.withOpacity(0.16) : null,
          side: selected ? BorderSide(color: color.withOpacity(0.45)) : null,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.onPressed,
    required this.line,
    required this.ink,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Color line;
  final Color ink;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: line),
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class _PortalsMenu extends StatelessWidget {
  const _PortalsMenu({
    required this.arabic,
    required this.ink,
    required this.line,
    required this.bar,
    required this.onPortal,
  });

  final bool arabic;
  final Color ink;
  final Color line;
  final Color bar;
  final void Function(StudioPortal portal) onPortal;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<StudioPortal>(
      tooltip: StudioPortalCatalog.portalsMenu(arabic),
      color: bar,
      onSelected: onPortal,
      itemBuilder: (context) => [
        PopupMenuItem<StudioPortal>(
          enabled: false,
          child: Text(
            StudioPortalCatalog.portalsHint(arabic),
            style: TextStyle(
                color: ink.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w800),
          ),
        ),
        for (final portal in StudioPortalCatalog.portals)
          PopupMenuItem(
            value: portal,
            child: Row(
              children: [
                Icon(studioPortalIcon(portal.id),
                    color: StudioTheme.tealBright, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(portal.title(arabic),
                        style: TextStyle(color: ink))),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: Icon(Icons.expand_more, color: ink, size: 18),
        label: Text(StudioPortalCatalog.portalsMenu(arabic)),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
        side: BorderSide(color: line),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

IconData studioPortalIcon(StudioPortalId id) {
  switch (id) {
    case StudioPortalId.patient:
      return Icons.favorite_outline;
    case StudioPortalId.doctor:
      return Icons.medical_services_outlined;
    case StudioPortalId.hospital:
      return Icons.local_hospital_outlined;
    case StudioPortalId.lab:
      return Icons.science_outlined;
    case StudioPortalId.pharmacy:
      return Icons.medication_outlined;
    case StudioPortalId.privacy:
      return Icons.lock_outline;
    case StudioPortalId.admin:
      return Icons.fact_check_outlined;
    case StudioPortalId.emergency:
      return Icons.local_fire_department_outlined;
    case StudioPortalId.womenHealth:
      return Icons.spa_outlined;
    case StudioPortalId.devices:
      return Icons.sensors_outlined;
    case StudioPortalId.ai:
      return Icons.auto_awesome_outlined;
    case StudioPortalId.network:
      return Icons.hub_outlined;
    case StudioPortalId.organizations:
      return Icons.volunteer_activism_outlined;
  }
}
