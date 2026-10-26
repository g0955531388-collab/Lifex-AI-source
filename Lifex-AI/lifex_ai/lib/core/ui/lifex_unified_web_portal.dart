/// بوابة Lifex-AI Global Health Network البصرية.
/// السمات شكل فقط. لا بروتوكول علاجي معتمد، ولا قراءة جهاز، ولا نموذج سحابي.
library lifex_ai.core.ui.lifex_unified_web_portal;

import 'package:flutter/material.dart';

import '../attribution/project_attribution.dart';

enum LifexThemeMode {
  studioCeramicDark,
  royalMedicalLight,
  emeraldBioMatrix,
  highContrastBlind,
  emergencyRedAlert,
}

class LifexUnifiedThemeConfig {
  const LifexUnifiedThemeConfig({
    required this.titleAr,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.cardSurface,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderGlow,
    required this.themeIcon,
  });

  final String titleAr;
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color cardSurface;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderGlow;
  final IconData themeIcon;

  static const registry = <LifexThemeMode, LifexUnifiedThemeConfig>{
    LifexThemeMode.studioCeramicDark: LifexUnifiedThemeConfig(
      titleAr: 'سمة خزفية داكنة',
      backgroundPrimary: Color(0xFF0B0F19),
      backgroundSecondary: Color(0xFF111827),
      cardSurface: Color(0xFF1E293B),
      accentPrimary: Color(0xFF38BDF8),
      accentSecondary: Color(0xFF818CF8),
      textPrimary: Color(0xFFF8FAFC),
      textSecondary: Color(0xFF94A3B8),
      borderGlow: Color(0xFF0284C7),
      themeIcon: Icons.auto_awesome,
    ),
    LifexThemeMode.royalMedicalLight: LifexUnifiedThemeConfig(
      titleAr: 'سمة طبية فاتحة',
      backgroundPrimary: Color(0xFFF1F5F9),
      backgroundSecondary: Color(0xFFFFFFFF),
      cardSurface: Color(0xFFFFFFFF),
      accentPrimary: Color(0xFF0284C7),
      accentSecondary: Color(0xFF0D9488),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF475569),
      borderGlow: Color(0xFFBAE6FD),
      themeIcon: Icons.light_mode,
    ),
    LifexThemeMode.emeraldBioMatrix: LifexUnifiedThemeConfig(
      titleAr: 'سمة زمردية',
      backgroundPrimary: Color(0xFF041F1E),
      backgroundSecondary: Color(0xFF062C2B),
      cardSurface: Color(0xFF0B3B39),
      accentPrimary: Color(0xFF10B981),
      accentSecondary: Color(0xFF34D399),
      textPrimary: Color(0xFFECFDF5),
      textSecondary: Color(0xFFA7F3D0),
      borderGlow: Color(0xFF059669),
      themeIcon: Icons.spa,
    ),
    LifexThemeMode.highContrastBlind: LifexUnifiedThemeConfig(
      titleAr: 'سمة تباين عالٍ',
      backgroundPrimary: Color(0xFF000000),
      backgroundSecondary: Color(0xFF0A0A0A),
      cardSurface: Color(0xFF141414),
      accentPrimary: Color(0xFFFFD700),
      accentSecondary: Color(0xFF00FFFF),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFFFF59D),
      borderGlow: Color(0xFFFFD700),
      themeIcon: Icons.visibility,
    ),
    LifexThemeMode.emergencyRedAlert: LifexUnifiedThemeConfig(
      titleAr: 'سمة تنبيه',
      backgroundPrimary: Color(0xFF1F0909),
      backgroundSecondary: Color(0xFF2D0C0C),
      cardSurface: Color(0xFF3F1111),
      accentPrimary: Color(0xFFEF4444),
      accentSecondary: Color(0xFFF97316),
      textPrimary: Color(0xFFFEF2F2),
      textSecondary: Color(0xFFFCA5A5),
      borderGlow: Color(0xFFDC2626),
      themeIcon: Icons.emergency,
    ),
  };
}

enum PortalAction { none, openCamera, openDevices, openEmergency, openSearch }

class PortalCommandPlan {
  const PortalCommandPlan({
    required this.route,
    required this.announcement,
    required this.action,
    this.emergencyTheme = false,
  });

  final String route;
  final String announcement;
  final PortalAction action;
  final bool emergencyTheme;
}

class PortalListenResult {
  const PortalListenResult.success(this.text)
      : success = true,
        errorAr = null;

  const PortalListenResult.failure(this.errorAr)
      : success = false,
        text = null;

  final bool success;
  final String? text;
  final String? errorAr;
}

class UserCareNote {
  const UserCareNote({
    required this.title,
    required this.category,
    required this.text,
  });

  final String title;
  final String category;
  final String text;

  static const storedInClinicalRecord = false;

  static const statusAr =
      'ملاحظة في ذاكرة هذه الشاشة فقط. تختفي عند إغلاقها. ليست علاجاً معتمداً وليست توصية.';
}

class LifexPortalController extends ChangeNotifier {
  LifexThemeMode currentTheme = LifexThemeMode.studioCeramicDark;
  String activeRoute = 'dashboard';
  String lastSystemAnnouncement =
      'مرحباً بك في Lifex-AI Global Health Network. هذه البوابة واجهة محلية.';
  final List<UserCareNote> notes = [];
  bool listening = false;

  Future<PortalListenResult> Function()? onListen;
  Future<void> Function()? onStopListen;
  void Function()? onOpenCamera;
  void Function()? onOpenDevices;
  void Function()? onOpenEmergency;
  void Function()? onOpenSearch;

  void switchTheme(LifexThemeMode mode) {
    currentTheme = mode;
    lastSystemAnnouncement =
        'تغير لون الواجهة إلى ${LifexUnifiedThemeConfig.registry[mode]!.titleAr}.';
    notifyListeners();
  }

  void navigateTo(String routeKey) {
    activeRoute = routeKey;
    notifyListeners();
  }

  /// قصّ أحرف العرض فقط. ليس تفويضاً ولا يمنع أمراً من الوصول إلى شاشة.
  static const inputTrimIsNotAuthorization = true;

  static String trimForDisplay(String input) {
    return input.replaceAll(RegExp(r'[<>{};$]'), '').trim();
  }

  static PortalCommandPlan planCommand(String rawCommand) {
    final clean = trimForDisplay(rawCommand);
    if (clean.isEmpty) {
      return const PortalCommandPlan(
        route: 'dashboard',
        announcement: 'لا عبارة للتنفيذ.',
        action: PortalAction.none,
      );
    }
    if (clean.contains('لا تفتح') ||
        clean.contains('لا تشغل') ||
        clean.contains('لا تشغّل') ||
        clean.contains('بدون فتح')) {
      return const PortalCommandPlan(
        route: 'dashboard',
        announcement: 'لم يُنفَّذ فتح. العبارة تمنع التنفيذ.',
        action: PortalAction.none,
      );
    }
    if ((clean.contains('رادار') || clean.contains('مسافة')) &&
        !clean.contains('كاميرا') &&
        !clean.contains('مكفوف')) {
      return const PortalCommandPlan(
        route: 'dashboard',
        announcement: 'لا رادار بصري ولا قياس مسافة من هذه البوابة.',
        action: PortalAction.none,
      );
    }
    if (clean.contains('كاميرا') || clean.contains('مكفوف')) {
      return const PortalCommandPlan(
        route: 'vision_radar',
        announcement:
            'الكاميرا الحية في شاشتها الخاصة بعد الموافقة. هذه البوابة لا تقيس مسافة.',
        action: PortalAction.openCamera,
      );
    }
    if (clean.contains('جهاز') || clean.contains('أجهزة')) {
      return const PortalCommandPlan(
        route: 'devices',
        announcement:
            'لا جهاز مكتشف أو موصول أو مخوّل من هذه البوابة. مركز الأجهزة هو المسار الموجود.',
        action: PortalAction.openDevices,
      );
    }
    if (clean.contains('طوارئ') || clean.contains('إسعاف')) {
      return const PortalCommandPlan(
        route: 'emergency',
        announcement:
            'لم يُرسل موقع ولم تُبث مؤشرات. جهات الطوارئ تُفتح من الشاشة الموجودة.',
        action: PortalAction.openEmergency,
        emergencyTheme: true,
      );
    }
    if (clean.contains('علاج') || clean.contains('بروتوكول')) {
      return const PortalCommandPlan(
        route: 'treatments',
        announcement:
            'لا سجل علاجات معتمدة. الملاحظة تبقى في ذاكرة هذه الشاشة وتُمسح عند إغلاقها.',
        action: PortalAction.none,
      );
    }
    if (clean.contains('تغذية') || clean.contains('ماكرو')) {
      return const PortalCommandPlan(
        route: 'dashboard',
        announcement:
            'لا حاسبة تغذية في هذه البوابة، ولا احتياج محسوب.',
        action: PortalAction.none,
      );
    }
    if (clean.contains('بحث')) {
      return const PortalCommandPlan(
        route: 'dashboard',
        announcement:
            'بحث Lifex-AI يُفتح من شاشته. لم يُستدعَ نموذج سحابي.',
        action: PortalAction.openSearch,
      );
    }
    return const PortalCommandPlan(
      route: 'dashboard',
      announcement:
          'بقيت العبارة على الجهاز. لم يُستدعَ نموذج ولم يُنفَّذ إجراء طبي.',
      action: PortalAction.none,
    );
  }

  Future<void> executeUnifiedCommand(String rawCommand) async {
    final plan = planCommand(rawCommand);
    if (trimForDisplay(rawCommand).isEmpty) return;
    activeRoute = plan.route;
    if (plan.emergencyTheme) {
      currentTheme = LifexThemeMode.emergencyRedAlert;
    }
    final opened = _run(plan.action);
    lastSystemAnnouncement = opened
        ? plan.announcement
        : 'المسار غير مربوط في هذه الجلسة. ${plan.announcement}';
    notifyListeners();
  }

  bool _run(PortalAction action) {
    switch (action) {
      case PortalAction.none:
        return true;
      case PortalAction.openCamera:
        final open = onOpenCamera;
        if (open == null) return false;
        open();
        return true;
      case PortalAction.openDevices:
        final open = onOpenDevices;
        if (open == null) return false;
        open();
        return true;
      case PortalAction.openEmergency:
        final open = onOpenEmergency;
        if (open == null) return false;
        open();
        return true;
      case PortalAction.openSearch:
        final open = onOpenSearch;
        if (open == null) return false;
        open();
        return true;
    }
  }

  void addUserNote(String title, String category, String text) {
    final cleanTitle = trimForDisplay(title);
    final cleanText = trimForDisplay(text);
    if (cleanTitle.isEmpty || cleanText.isEmpty) return;
    notes.insert(
      0,
      UserCareNote(
        title: cleanTitle,
        category: trimForDisplay(category).isEmpty
            ? 'ملاحظة عامة'
            : trimForDisplay(category),
        text: cleanText,
      ),
    );
    lastSystemAnnouncement = UserCareNote.statusAr;
    notifyListeners();
  }

  int _listenTicket = 0;

  Future<void> listenOnce() async {
    final listen = onListen;
    if (listen == null) {
      lastSystemAnnouncement = 'الاستماع غير مربوط في هذه الجلسة.';
      notifyListeners();
      return;
    }
    if (listening) return;
    final ticket = ++_listenTicket;
    listening = true;
    lastSystemAnnouncement = 'طُلب الاستماع. لم يُؤكَّد نص بعد.';
    notifyListeners();
    try {
      final heard = await listen();
      if (ticket != _listenTicket) return;
      if (!heard.success) {
        lastSystemAnnouncement =
            heard.errorAr ?? 'تعذّر الاستماع. لم يُنفَّذ أمر.';
        return;
      }
      final text = heard.text?.trim() ?? '';
      if (text.isEmpty) {
        lastSystemAnnouncement = 'انتهى الاستماع بلا نص. لم يُنفَّذ أمر.';
        return;
      }
      await executeUnifiedCommand(text);
    } catch (_) {
      if (ticket != _listenTicket) return;
      lastSystemAnnouncement = 'تعذّر الاستماع. لم يُنفَّذ أمر.';
    } finally {
      if (ticket == _listenTicket) {
        listening = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopListening() async {
    _listenTicket++;
    listening = false;
    final stop = onStopListen;
    if (stop == null) {
      lastSystemAnnouncement = 'لا جلسة استماع مربوطة لإيقافها.';
      notifyListeners();
      return;
    }
    try {
      await stop();
      lastSystemAnnouncement = 'أوقفت الاستماع.';
    } catch (_) {
      lastSystemAnnouncement =
          'تعذّر إيقاف محرك الاستماع. الحالة المحلية: غير مستمع.';
    }
    notifyListeners();
  }
}

class LifexUnifiedWebPortal extends StatefulWidget {
  const LifexUnifiedWebPortal({
    super.key,
    this.onListen,
    this.onStopListen,
    this.onOpenCamera,
    this.onOpenDevices,
    this.onOpenEmergency,
    this.onOpenSearch,
  });

  final Future<PortalListenResult> Function()? onListen;
  final Future<void> Function()? onStopListen;
  final VoidCallback? onOpenCamera;
  final VoidCallback? onOpenDevices;
  final VoidCallback? onOpenEmergency;
  final VoidCallback? onOpenSearch;

  @override
  State<LifexUnifiedWebPortal> createState() => _LifexUnifiedWebPortalState();
}

class _LifexUnifiedWebPortalState extends State<LifexUnifiedWebPortal> {
  final LifexPortalController _controller = LifexPortalController();
  final TextEditingController _commandInput = TextEditingController();
  final TextEditingController _noteTitle = TextEditingController();
  final TextEditingController _noteCategory = TextEditingController();
  final TextEditingController _noteText = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bind();
    _controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(LifexUnifiedWebPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind();
  }

  void _bind() {
    _controller
      ..onListen = widget.onListen
      ..onStopListen = widget.onStopListen
      ..onOpenCamera = widget.onOpenCamera
      ..onOpenDevices = widget.onOpenDevices
      ..onOpenEmergency = widget.onOpenEmergency
      ..onOpenSearch = widget.onOpenSearch;
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _commandInput.dispose();
    _noteTitle.dispose();
    _noteCategory.dispose();
    _noteText.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  LifexUnifiedThemeConfig get _theme =>
      LifexUnifiedThemeConfig.registry[_controller.currentTheme]!;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
        backgroundColor: _theme.backgroundPrimary,
        drawer: wide ? null : Drawer(child: _sidebar()),
        body: SafeArea(
          child: Column(
            children: [
              _topBar(wide),
              _status(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) SizedBox(width: 280, child: _sidebar()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _viewport(),
                            const SizedBox(height: 32),
                            _footer(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _topBar(bool wide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _theme.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: _theme.borderGlow.withOpacity(0.4)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!wide)
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'أقسام البوابة',
                    icon: Icon(Icons.menu, color: _theme.accentPrimary),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              Icon(Icons.public, color: _theme.accentPrimary, size: 28),
              const SizedBox(width: 12),
              Text(
                ProjectAttribution.systemName,
                style: TextStyle(
                  color: _theme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, minWidth: 260),
            child: TextField(
              controller: _commandInput,
              style: TextStyle(color: _theme.textPrimary),
              decoration: InputDecoration(
                hintText: 'عبارة للانتقال: كاميرا، أجهزة، طوارئ، بحث',
                hintStyle: TextStyle(color: _theme.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: _theme.accentPrimary),
                suffixIcon: IconButton(
                  tooltip: 'استماع مرة واحدة',
                  icon: Icon(
                    _controller.listening ? Icons.mic : Icons.mic_none,
                    color: _theme.accentPrimary,
                  ),
                  onPressed: () => _controller.listening
                      ? _controller.stopListening()
                      : _controller.listenOnce(),
                ),
              ),
              onSubmitted: (value) {
                _controller.executeUnifiedCommand(value);
                _commandInput.clear();
              },
            ),
          ),
          PopupMenuButton<LifexThemeMode>(
            tooltip: 'اختيار لون الواجهة',
            icon: Icon(_theme.themeIcon, color: _theme.accentPrimary),
            onSelected: _controller.switchTheme,
            itemBuilder: (context) {
              return LifexUnifiedThemeConfig.registry.entries
                  .map(
                    (entry) => PopupMenuItem(
                      value: entry.key,
                      child: Text(entry.value.titleAr),
                    ),
                  )
                  .toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _status() {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: _theme.accentPrimary.withOpacity(0.15),
        child: Text(
          _controller.lastSystemAnnouncement,
          style: TextStyle(color: _theme.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _sidebar() {
    const items = <(String, String, IconData)>[
      ('dashboard', 'لوحة البوابة', Icons.dashboard_customize),
      ('ai_studio', 'العبارة المحلية', Icons.psychology_outlined),
      ('treatments', 'ملاحظات المستخدم', Icons.edit_note),
      ('devices', 'مركز الأجهزة', Icons.memory),
      ('vision_radar', 'كاميرا المكفوفين', Icons.visibility_outlined),
      ('emergency', 'جهات الطوارئ', Icons.emergency_share),
    ];
    return Container(
      color: _theme.backgroundSecondary,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: ListView(
        children: [
          for (final item in items)
            ListTile(
              leading: Icon(
                item.$3,
                color: _controller.activeRoute == item.$1
                    ? _theme.accentPrimary
                    : _theme.textSecondary,
              ),
              title: Text(
                item.$2,
                style: TextStyle(color: _theme.textPrimary),
              ),
              selected: _controller.activeRoute == item.$1,
              onTap: () => _controller.navigateTo(item.$1),
            ),
        ],
      ),
    );
  }

  Widget _viewport() {
    switch (_controller.activeRoute) {
      case 'ai_studio':
        return _localPhrase();
      case 'treatments':
        return _notes();
      case 'devices':
        return _devices();
      case 'vision_radar':
        return _camera();
      case 'nutrition_calc':
        return _nutrition();
      case 'emergency':
        return _emergency();
      default:
        return _dashboard();
    }
  }

  Widget _dashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ProjectAttribution.systemName,
          style: TextStyle(
            color: _theme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'واجهة محلية. لا تشخيص، ولا بروتوكول معتمد، ولا جهاز موصول من هذه الشاشة.',
          style: TextStyle(color: _theme.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _card('كاميرا المكفوفين', 'تفتح البث بعد الموافقة', () {
              _controller.executeUnifiedCommand('كاميرا');
            }),
            _card('مركز الأجهزة', 'لا قراءة معروضة هنا', () {
              _controller.executeUnifiedCommand('أجهزة');
            }),
            _card('ملاحظة شخصية', 'تبقى في هذه الجلسة', () {
              _controller.navigateTo('treatments');
            }),
            _card('جهات الطوارئ', 'لا بث مؤشرات من هنا', () {
              _controller.executeUnifiedCommand('طوارئ');
            }),
            _card('بحث Lifex-AI', 'يفتح شاشة البحث', () {
              _controller.executeUnifiedCommand('بحث');
            }),
          ],
        ),
      ],
    );
  }

  Widget _localPhrase() {
    return Text(
      'العبارة التي تكتبها تبقى على الجهاز. هذه الشاشة لا تستدعي Gemini ولا Google AI Studio.',
      style: TextStyle(color: _theme.textPrimary, fontSize: 16),
    );
  }

  Widget _notes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ملاحظات هذه الجلسة',
          style: TextStyle(
            color: _theme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(UserCareNote.statusAr, style: TextStyle(color: _theme.textSecondary)),
        const SizedBox(height: 12),
        TextField(
          controller: _noteTitle,
          decoration: const InputDecoration(labelText: 'عنوان الملاحظة'),
        ),
        TextField(
          controller: _noteCategory,
          decoration: const InputDecoration(labelText: 'تصنيف يكتبه المستخدم'),
        ),
        TextField(
          controller: _noteText,
          decoration: const InputDecoration(labelText: 'نص الملاحظة'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            _controller.addUserNote(
              _noteTitle.text,
              _noteCategory.text,
              _noteText.text,
            );
            _noteTitle.clear();
            _noteCategory.clear();
            _noteText.clear();
          },
          child: const Text('حفظ الملاحظة في هذه الجلسة'),
        ),
        for (final note in _controller.notes)
          ListTile(
            title: Text(note.title, style: TextStyle(color: _theme.textPrimary)),
            subtitle: Text(
              '${note.category}\n${note.text}\n${UserCareNote.statusAr}',
              style: TextStyle(color: _theme.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _devices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'لا جهاز مكتشف أو موصول أو مخوّل من هذه البوابة.',
          style: TextStyle(color: _theme.textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.onOpenDevices,
          child: const Text('افتح مركز الأجهزة'),
        ),
      ],
    );
  }

  Widget _camera() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'البث الحي يُفتح في شاشة الكاميرا بعد موافقتك. لا قياس مسافة ولا فلاش رادار من هذه البوابة.',
          style: TextStyle(color: _theme.textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.onOpenCamera,
          child: const Text('افتح كاميرا المكفوفين'),
        ),
      ],
    );
  }

  Widget _nutrition() {
    return Text(
      'لا حاسبة تغذية في هذه البوابة، ولا ربط بقراءات السكر أو الضغط، ولا احتياج علاجي محسوب.',
      style: TextStyle(color: _theme.textPrimary, fontSize: 16),
    );
  }

  Widget _emergency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'هذه الشاشة لا تبث مؤشرات ولا موقعاً. تفتح جهات الطوارئ المحفوظة.',
          style: TextStyle(color: _theme.textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.onOpenEmergency,
          child: const Text('افتح جهات الطوارئ'),
        ),
      ],
    );
  }

  Widget _card(String title, String subtitle, VoidCallback onTap) {
    return SizedBox(
      width: 240,
      child: Card(
        color: _theme.cardSurface,
        child: ListTile(
          title: Text(title, style: TextStyle(color: _theme.textPrimary)),
          subtitle: Text(subtitle, style: TextStyle(color: _theme.textSecondary)),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _footer() {
    return Text(
      ProjectAttribution.officialStatementShortAr,
      textAlign: TextAlign.center,
      style: TextStyle(color: _theme.accentPrimary, fontWeight: FontWeight.bold),
    );
  }
}
