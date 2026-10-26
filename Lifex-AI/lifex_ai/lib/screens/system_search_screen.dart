/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: system_search_screen.dart
/// بحث داخلي، ثم اقتراح فتح محرك خارجي. ليس تشخيصاً.
/// =============================================================
library lifex_ai.screens.system_search_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/lasting_search_index.dart';
import '../core/local_knowledge.dart';
import '../core/medical_record_canon.dart';
import '../core/network_canon.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';
import '../features/ai/public_search_desk.dart';
import '../features/search/external_link_desk.dart';
import '../features/search/external_search_catalog.dart';
import 'blood_request_screen.dart';
import 'book_library_screen.dart';
import 'box_unit_screen.dart';
import 'project_box_hub_screen.dart';
import 'vision_resource_screen.dart';

class SystemSearchScreen extends StatefulWidget {
  const SystemSearchScreen({
    super.key,
    this.initialQuery = '',
    this.startOnWeb = false,
  });

  final String initialQuery;
  final bool startOnWeb;

  @override
  State<SystemSearchScreen> createState() => _SystemSearchScreenState();
}

class _SystemSearchScreenState extends State<SystemSearchScreen> {
  late final TextEditingController _field;
  late final TextEditingController _engineName;
  late final TextEditingController _engineTemplate;
  String _engineId = ExternalSearchCatalog.defaultId;
  List<WebEngine> _userEngines = const [];
  Map<String, String> _templates = const {};
  bool _web = false;
  String? _linkNote;
  String? _engineFormNote;
  String? _outsideAr;
  bool _outsideBusy = false;
  String? _offerSpokenFor;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: widget.initialQuery);
    _engineName = TextEditingController();
    _engineTemplate = TextEditingController();
    _web = widget.startOnWeb;
    unawaited(_loadEngine());
  }

  @override
  void dispose() {
    _field.dispose();
    _engineName.dispose();
    _engineTemplate.dispose();
    super.dispose();
  }

  WebEngine _selectedEngine() {
    for (final engine in _userEngines) {
      if (engine.id == _engineId) return engine;
    }
    return ExternalSearchCatalog.byId(_engineId);
  }

  Future<void> _loadEngine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(ExternalSearchCatalog.preferenceKey);
      final custom = UserEngineDraft.decode(
        prefs.getString(UserEngineDraft.preferenceKey),
      );
      if (!mounted) return;
      setState(() {
        _userEngines = [for (final row in custom) row.engine];
        _templates = {for (final row in custom) row.engine.id: row.template};
        final known = stored != null &&
            (_userEngines.any((engine) => engine.id == stored) ||
                ExternalSearchCatalog.engines.any((engine) => engine.id == stored));
        if (known) _engineId = stored;
      });
    } catch (_) {}
  }

  Future<void> _rememberEngine(String id) async {
    setState(() => _engineId = id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ExternalSearchCatalog.preferenceKey, id);
    } catch (_) {}
  }

  Future<void> _saveUserEngines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      UserEngineDraft.preferenceKey,
      UserEngineDraft.encode(_userEngines, _templates),
    );
  }

  Future<void> _addEngine() async {
    final reason = UserEngineDraft.rejection(_engineName.text, _engineTemplate.text);
    if (reason != null) {
      setState(() => _engineFormNote = reason);
      return;
    }
    final id = 'user-${DateTime.now().microsecondsSinceEpoch}';
    final engine = UserEngineDraft.toEngine(
      id: id,
      label: _engineName.text,
      template: _engineTemplate.text,
    );
    if (engine == null) return;
    setState(() {
      _userEngines = [..._userEngines, engine];
      _templates = {..._templates, id: _engineTemplate.text.trim()};
      _engineId = id;
      _engineFormNote = 'حُفظ المحرك. فتح موقعه ليس دمجاً برمجياً لخدمته.';
      _engineName.clear();
      _engineTemplate.clear();
    });
    await _rememberEngine(id);
    await _saveUserEngines();
  }

  Future<void> _removeSelectedUserEngine() async {
    if (!_templates.containsKey(_engineId)) {
      setState(() => _engineFormNote = 'محركات Lifex الثابتة تبقى. احذف محركاً أضفته أنت.');
      return;
    }
    setState(() {
      _userEngines = [
        for (final engine in _userEngines)
          if (engine.id != _engineId) engine,
      ];
      _templates = {
        for (final entry in _templates.entries)
          if (entry.key != _engineId) entry.key: entry.value,
      };
      _engineId = ExternalSearchCatalog.defaultId;
      _engineFormNote = 'حُذف المحرك الذي أضفته.';
    });
    await _rememberEngine(_engineId);
    await _saveUserEngines();
  }

  Future<void> _speakOffer(String query) async {
    if (_offerSpokenFor == query) return;
    _offerSpokenFor = query;
    await VoiceEngine.instance.speak(ExternalSearchCatalog.offerAr);
  }

  Future<void> _acceptOfferByVoice() async {
    final heard = await VoiceEngine.instance.listenFresh();
    if (!mounted) return;
    final text = heard.textResult?.trim() ?? '';
    if (text == 'نعم' || text.startsWith('نعم ')) {
      await _searchOutside();
      return;
    }
    setState(() => _linkNote = 'لم أسمع نعم. اضغط زر التوسيع أو أعد المحاولة.');
  }

  Future<void> _searchOutside() async {
    final phrase = _field.text.trim();
    if (phrase.isEmpty || _outsideBusy) {
      if (phrase.isEmpty) {
        setState(() => _outsideAr = 'اكتب عبارة قبل البحث خارج المنظومة.');
      }
      return;
    }
    setState(() {
      _outsideBusy = true;
      _outsideAr = null;
    });
    final answer = await const PublicSearchDesk().ask(phrase);
    if (!mounted) return;
    setState(() {
      _outsideBusy = false;
      _outsideAr = answer.textAr.trim().isEmpty
          ? 'المحرك العام بلا مفتاح لم يعد خلاصة. لم يُخترع نص.'
          : answer.textAr;
    });
  }

  Future<void> _openWeb() async {
    final phrase = _field.text.trim();
    if (phrase.isEmpty) {
      setState(() => _linkNote = 'اكتب عبارة قبل مغادرة التطبيق.');
      return;
    }
    final uri = _selectedEngine().build(phrase);
    final result = await const ExternalLinkDesk().open(uri);
    if (!mounted) return;
    setState(() => _linkNote = result.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    final query = _field.text.trim();
    final knowledge = context.read<LocalKnowledge>();
    LastingSearchIndex lasting;
    try {
      lasting = context.read<LastingSearchIndex>();
    } catch (_) {
      lasting = LastingSearchIndex();
    }
    List<KnowledgeHit> hits = const [];
    var lookupFailed = false;
    try {
      hits = InternalSearchEngine(knowledge: knowledge, lasting: lasting)
          .search(query);
    } catch (_) {
      lookupFailed = true;
    }
    final aliasSeat = query.isEmpty ? null : NetworkCanon.match(query);
    final units = BoxUnitCatalog.recordUnits
        .where((unit) =>
            query.isEmpty ||
            MedicalRecordCanon.queryMatches(
              '${unit.titleAr} ${unit.subtitleAr}',
              query,
            ) ||
            (aliasSeat != null && aliasSeat.unitId == unit.id))
        .toList();
    final localCount = hits.length + units.length + (aliasSeat == null ? 0 : 1);
    final sourcesReady = knowledge.sourcesReady;
    final unloaded = query.isNotEmpty && !lookupFailed && !sourcesReady;
    final offer = SearchHandoff.offerInternet(
      query: query,
      localHits: localCount,
      lookupFailed: lookupFailed,
      sourcesReady: sourcesReady,
    );
    final engine = _selectedEngine();
    final engines = [...ExternalSearchCatalog.engines, ..._userEngines];

    final status = lookupFailed
        ? SearchHandoff.failedAr
        : unloaded
            ? SearchHandoff.unloadedAr
            : query.isEmpty
                ? 'اكتب عبارة البحث.'
                : 'عبارة البحث: $query. النتائج الداخلية: $localCount.';
    return ScreenArrival(
      message: 'بحث المنظومة',
      controls: const [
        'داخل Lifex-AI',
        'الإنترنت',
        'فتح المتصفح',
        'مكتبة الفهارس',
        'موارد الرؤية',
      ],
      body: status,
      child: Scaffold(
      appBar: AppBar(title: const Text('بحث المنظومة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            textField: true,
            label: 'عبارة البحث',
            child: TextField(
              controller: _field,
              autofocus: widget.initialQuery.isEmpty,
              decoration: const InputDecoration(
                labelText: 'وحدة أو مرض أو دواء أو عرض',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _linkNote = null),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'اكتب داخل الحقل لتظهر نتائج المنظومة فوراً.'
                : 'داخل المنظومة: $localCount',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (lookupFailed)
            const ListTile(
              leading: Icon(Icons.error_outline),
              title: Text(SearchHandoff.failedAr),
            )
          else if (unloaded)
            const ListTile(
              leading: Icon(Icons.downloading_outlined),
              title: Text(SearchHandoff.unloadedAr),
            )
          else if (query.isNotEmpty && hits.isEmpty && units.isEmpty)
            const ListTile(
              leading: Icon(Icons.search_off),
              title: Text(SearchHandoff.emptyAr),
            ),
          if (hits.isNotEmpty) ...[
            Text(knowledge.disclaimerAr),
            for (final hit in hits)
              ListTile(
                title: Text(hit.titleAr),
                subtitle: Text('المصدر: ${hit.kindAr}\n${hit.detailAr}'),
                isThreeLine: true,
              ),
          ],
          for (final unit in units)
            ListTile(
              title: Text(unit.titleAr),
              subtitle: Text('وحدة — ${unit.subtitleAr}'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BoxUnitScreen(unit: unit)),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _outsideBusy ? null : _searchOutside,
            icon: _outsideBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.public),
            label: const Text('ابحث في المحلي والإنترنت'),
          ),
          if (_outsideAr != null) ...[
            const SizedBox(height: 8),
            const Text(
              'خلاصة محرك عام بلا مفتاح. ليست تشخيصاً، والملف الصحي لم يُرسل.',
            ),
            Text(_outsideAr!),
          ],
          const SizedBox(height: 12),
          const Text('النتائج المحلية تظهر مع خلاصة الإنترنت. الملف الصحي لا يُرسل.'),
          const SizedBox(height: 12),
          if (_web) ...[
            Text(
              'ستغادر التطبيق إلى ${engine.host}. يُرسل نص البحث الذي كتبته فقط، ولا يُرسل الملف الصحي.',
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: engine.id,
              items: [
                for (final item in engines)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.labelAr} — ${item.host}'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) unawaited(_rememberEngine(value));
              },
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'فتح المتصفح على ${engine.labelAr}',
              child: FilledButton.icon(
                onPressed: _openWeb,
                icon: const Icon(Icons.open_in_new),
                label: Text('فتح ${engine.labelAr} في المتصفح'),
              ),
            ),
            if (_linkNote != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: _linkNote,
                child: Text(_linkNote!),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'إعداد المحركات: أضف رابط https يحتوي {query}. حذف المحركات الثابتة غير متاح.',
            ),
            TextField(
              controller: _engineName,
              decoration: const InputDecoration(labelText: 'اسم المحرك'),
            ),
            TextField(
              controller: _engineTemplate,
              decoration: const InputDecoration(
                labelText: 'قالب الرابط',
                hintText: 'https://example.com/search?q={query}',
              ),
            ),
            Row(
              children: [
                TextButton(onPressed: _addEngine, child: const Text('إضافة محرك')),
                TextButton(
                  onPressed: _removeSelectedUserEngine,
                  child: const Text('حذف المحرك المضاف'),
                ),
              ],
            ),
            if (_engineFormNote != null) Text(_engineFormNote!),
          ],
          ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('صندوق المشروع'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectBoxHubScreen()),
              ),
            ),
            if (aliasSeat?.openBlood == true)
              ListTile(
                leading: const Icon(Icons.bloodtype_outlined),
                title: const Text('شبكة الدم'),
                subtitle: const Text(
                  'فرع التبرعات. التنبيه للموافقين على هذا الجهاز فقط',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BloodRequestScreen()),
                ),
              ),
            if (offer) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: ExternalSearchCatalog.offerAr,
                child: const Text(ExternalSearchCatalog.offerAr),
              ),
              const SizedBox(height: 8),
              _OfferSpeaker(query: query, onSpeak: _speakOffer),
              FilledButton(
                onPressed: () {
                  setState(() => _web = true);
                  unawaited(_searchOutside());
                },
                child: const Text('أظهر المتصفح مع البحث'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => unawaited(_acceptOfferByVoice()),
                child: const Text('قل نعم لتوسيع البحث'),
              ),
            ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('مكتبة الفهارس'),
            subtitle: const Text('تفتح مصدر الكتاب ولا تنسخ نصه'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookLibraryScreen(initialPhrase: query),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('موارد الرؤية'),
            subtitle: const Text('صفحات الناشرين. لا تثبيت تلقائي'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VisionResourceScreen(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _OfferSpeaker extends StatefulWidget {
  const _OfferSpeaker({required this.query, required this.onSpeak});

  final String query;
  final Future<void> Function(String query) onSpeak;

  @override
  State<_OfferSpeaker> createState() => _OfferSpeakerState();
}

class _OfferSpeakerState extends State<_OfferSpeaker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSpeak(widget.query);
    });
  }

  @override
  void didUpdateWidget(_OfferSpeaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      widget.onSpeak(widget.query);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
