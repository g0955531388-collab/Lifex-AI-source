/// =============================================================
/// Lifex-AI — Persistent Store لـ HealthObservation (ملفات JSON)
/// المسار: documents/lifex_health/health_observations.json
/// =============================================================
library lifex_ai.core.health_data.file_health_observation_store;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'health_observation_repository.dart';

/// مخزن دائم على نظام الملفات — التنفيذ الإنتاجي الافتراضي.
class FileHealthObservationStore implements HealthObservationPersistentStore {
  FileHealthObservationStore({
    this.fileName = 'health_observations.json',
    Directory? rootDirectory,
    Future<Directory> Function()? resolveDocumentsDirectory,
  })  : _rootDirectory = rootDirectory,
        _resolveDocumentsDirectory = resolveDocumentsDirectory;

  static const storeName = 'FileHealthObservationStore';
  static const relativeFolder = 'lifex_health';

  final String fileName;
  final Directory? _rootDirectory;
  final Future<Directory> Function()? _resolveDocumentsDirectory;

  File? _cachedFile;

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final root = _rootDirectory ??
        await (_resolveDocumentsDirectory ?? getApplicationDocumentsDirectory)();
    final dir = Directory('${root.path}/$relativeFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedFile = File('${dir.path}/$fileName');
    return _cachedFile!;
  }

  @override
  Future<String?> readRaw() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    if (text.trim().isEmpty) return null;
    return text;
  }

  @override
  Future<void> writeRaw(String contents) async {
    final file = await _file();
    await file.writeAsString(contents, flush: true);
  }
}
