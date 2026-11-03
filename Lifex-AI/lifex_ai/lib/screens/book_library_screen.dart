/// مكتبة تفتح فهارس الكتب الرسمية. النص لا يُنسخ إلى التطبيق.
library lifex_ai.screens.book_library_screen;

import 'package:flutter/material.dart';

import '../widgets/accessible_widgets.dart';
import '../features/knowledge/official_resource.dart';
import '../features/search/external_link_desk.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class BookLibraryScreen extends StatefulWidget {
  const BookLibraryScreen({super.key, this.initialPhrase = ''});

  final String initialPhrase;

  @override
  State<BookLibraryScreen> createState() => _BookLibraryScreenState();
}

class _BookLibraryScreenState extends State<BookLibraryScreen> {
  late final TextEditingController _phrase;
  String? _note;

  @override
  void initState() {
    super.initState();
    _phrase = TextEditingController(text: widget.initialPhrase);
  }

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _open(OfficialResource resource) async {
    final uri = OfficialResourceCatalog.bookQuery(resource, _phrase.text);
    final result = await const ExternalLinkDesk().open(uri);
    if (!mounted) return;
    setState(() => _note = result.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenArrival(
      message: 'مكتبة Lifex-AI',
      controls: const ['عبارة البحث عن كتاب', 'فتح فهرس الناشر'],
      body: _phrase.text.trim().isEmpty
          ? 'اكتب عنواناً أو مؤلفاً ثم اختر الفهرس. الكتاب لا يُنسخ إلى التطبيق.'
          : 'عبارة المكتبة: ${_phrase.text.trim()}. الفتح عند الناشر فقط.',
      child: Scaffold(
      appBar: AppBar(title: const LifexText('مكتبة Lifex-AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const LifexText(
            'البحث هنا يفتح فهرس الناشر. القراءة أو التنزيل يظهران على موقعه وفق شروطه، ولا يُنسخ الكتاب إلى التطبيق.',
          ),
          const SizedBox(height: 12),
          Semantics(
            textField: true,
            label: tr('عبارة البحث عن كتاب'),
            child: TextField(
              controller: _phrase,
              decoration: InputDecoration(
                labelText: tr('عنوان أو مؤلف أو موضوع'),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: tr(_note),
              child: LifexText(_note!),
            ),
          ],
          const SizedBox(height: 12),
          for (final resource in OfficialResourceCatalog.books)
            Card(
              child: ListTile(
                title: LifexText(resource.name),
                subtitle: LifexText(
                  '${resource.kindAr} — ${resource.publisher}\n'
                  '${resource.noteAr}\n'
                  'آخر تحقق من الرابط: ${resource.checkedOn}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(resource),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
