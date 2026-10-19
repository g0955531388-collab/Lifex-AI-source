/// =============================================================
/// Lifex-AI Global Health Network
/// الملف: medical_database_manager.dart
/// المسار: lib/data/medical_database_manager.dart
/// الوصف: يدير دورة حياة قاعدة البيانات الطبية الخمسة الملفات
/// (الأمراض، الأعراض، التحاليل، الأدوية، طبقة الربط) كـ"حزمة واحدة"
/// (Bundle) بدلاً من تحديث ملف واحد بمعزل عن الباقي — لأن الملفات
/// مترابطة عبر معرّفات متبادلة (diseaseId, symptomId...) ولا يجوز
/// تحديث واحد منها فقط دون التأكد من توافقه مع البقية.
///
/// آلية العمل:
/// 1) القراءة الافتراضية دائماً من ملفات الأصول (assets) المرفقة مع
///    التطبيق — هذه هي النسخة "المستقرة والموثوقة دائماً".
/// 2) عند طلب المستخدم تحديثاً، يُحمَّل أرشيف الحزمة كاملاً من الخادم
///    (وليس ملفاً واحداً)، ويُتحقق من تكامله الداخلي (كل المعرّفات
///    المتبادلة صحيحة) قبل حفظه محلياً.
/// 3) لو فشل التحقق أو انقطع التحميل، يبقى التطبيق يعمل بالنسخة
///    المحلية القديمة (أو نسخة الأصول) دون أي انقطاع للمستخدم.
/// =============================================================
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/error_handler.dart';

/// أسماء الملفات الخمسة التي تُشكّل الحزمة الطبية الكاملة. أي تحديث
/// يجب أن يشمل هذه الملفات الخمسة معاً، وليس ملفاً واحداً بمعزل.
class MedicalBundleFiles {
  static const String diseases = 'diseases_database.json';
  static const String symptoms = 'symptoms_database.json';
  static const String tests = 'tests_database.json';
  static const String medications = 'medications_database.json';
  static const String knowledge = 'medical_knowledge.json';

  /// قاموس قياسات منفصل عن الحزمة الخماسية. غيابه لا يلغي تحديث الأمراض.
  static const String biometrics =
      'Lifex_AI_Human_Biometric_Measurements_v1.json';

  static const List<String> all = [
    diseases,
    symptoms,
    tests,
    medications,
    knowledge,
  ];
}

/// نتيجة عملية تحميل وتحديث الحزمة الطبية.
class MedicalUpdateResult {
  final bool success;
  final String messageAr;
  final int? newDiseasesCount;

  const MedicalUpdateResult.success({
    required this.messageAr,
    this.newDiseasesCount,
  }) : success = true;

  const MedicalUpdateResult.failure(this.messageAr)
      : success = false,
        newDiseasesCount = null;
}

/// مدير قاعدة البيانات الطبية — نقطة الوصول الموحدة لقراءة وتحديث
/// الحزمة الطبية الكاملة.
class MedicalDatabaseManager {
  MedicalDatabaseManager({
    required this.remoteManifestUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// رابط "بيان" الحزمة على الخادم — يُرجع رقم إصدار وروابط تحميل كل
  /// ملف من الملفات الخمسة، وليس ملفاً واحداً مباشرة.
  final String remoteManifestUrl;
  final http.Client _httpClient;

  static const String _assetBasePath = 'lib/data/medical/';
  static const String _localVersionFileName = '_medical_bundle_version.txt';

  /// المسار المحلي القابل للكتابة لأي ملف من ملفات الحزمة.
  Future<File> _localFileFor(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/medical_bundle_$fileName');
  }

  Future<File> _localVersionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_localVersionFileName');
  }

  /// قراءة ملف واحد من الحزمة: يبحث أولاً في النسخة المحلية المحدَّثة
  /// (إن وُجدت)، وإلا يقرأ من نسخة الأصول المرفقة مع التطبيق.
  Future<Map<String, dynamic>> readBundleFile(String fileName) async {
    try {
      final localFile = await _localFileFor(fileName);
      if (await localFile.exists()) {
        final contents = await localFile.readAsString();
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'MEDICAL_LOCAL_READ_FAILED',
        'فشلت قراءة النسخة المحلية المحدَّثة لملف $fileName، سيتم '
            'الرجوع للنسخة الافتراضية المرفقة مع التطبيق.',
        sourceModule: 'medical_database_manager',
        severity: ErrorSeverity.warning,
        exception: e,
        stackTrace: stackTrace,
      );
    }

    // الرجوع الآمن دائماً لنسخة الأصول المستقرة عند أي فشل أو عدم وجود
    // تحديث محلي بعد.
    final assetContents = await rootBundle.loadString('$_assetBasePath$fileName');
    return jsonDecode(assetContents) as Map<String, dynamic>;
  }

  /// قراءة الحزمة الطبية الكاملة دفعة واحدة (الملفات الخمسة معاً).
  Future<Map<String, Map<String, dynamic>>> readFullBundle() async {
    final result = <String, Map<String, dynamic>>{};
    for (final fileName in MedicalBundleFiles.all) {
      result[fileName] = await readBundleFile(fileName);
    }
    return result;
  }

  /// التحقق من وجود إصدار أحدث على الخادم دون تحميل الحزمة كاملة.
  Future<String?> checkForNewerVersion() async {
    try {
      final response = await _httpClient.get(Uri.parse(remoteManifestUrl));
      if (response.statusCode != 200) return null;

      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = manifest['version'] as String?;
      final localVersion = await _readLocalVersion();

      if (remoteVersion != null && remoteVersion != localVersion) {
        return remoteVersion;
      }
      return null;
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'MEDICAL_VERSION_CHECK_FAILED',
        'فشل التحقق من وجود تحديث لقاعدة البيانات الطبية.',
        sourceModule: 'medical_database_manager',
        severity: ErrorSeverity.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String?> _readLocalVersion() async {
    try {
      final file = await _localVersionFile();
      if (await file.exists()) {
        return (await file.readAsString()).trim();
      }
    } catch (_) {
      // لا يوجد إصدار محلي مسجَّل بعد — طبيعي عند أول تشغيل.
    }
    return null;
  }

  /// تحميل الحزمة الكاملة من الخادم، والتحقق من تكاملها الداخلي، ثم
  /// حفظها محلياً فقط إذا نجح التحقق بالكامل. لا يُستبدل أي ملف قديم
  /// إلا بعد التأكد من صحة كل الملفات الخمسة الجديدة معاً.
  Future<MedicalUpdateResult> downloadAndUpdateBundle() async {
    try {
      final manifestResponse =
          await _httpClient.get(Uri.parse(remoteManifestUrl));
      if (manifestResponse.statusCode != 200) {
        return const MedicalUpdateResult.failure(
          'تعذّر الوصول للخادم حالياً. حاول لاحقاً.',
        );
      }

      final manifest = jsonDecode(manifestResponse.body) as Map<String, dynamic>;
      final remoteVersion = manifest['version'] as String?;
      final fileUrls = manifest['files'] as Map<String, dynamic>?;

      if (remoteVersion == null || fileUrls == null) {
        return const MedicalUpdateResult.failure(
          'استجابة الخادم غير مكتملة أو غير صالحة.',
        );
      }

      // تحميل كل الملفات الخمسة أولاً في الذاكرة، دون حفظ أي شيء بعد.
      final downloadedFiles = <String, Map<String, dynamic>>{};
      for (final fileName in MedicalBundleFiles.all) {
        final url = fileUrls[fileName] as String?;
        if (url == null) {
          return MedicalUpdateResult.failure(
            'ملف $fileName مفقود من بيان التحديث. تم إلغاء التحديث بالكامل.',
          );
        }

        final fileResponse = await _httpClient.get(Uri.parse(url));
        if (fileResponse.statusCode != 200) {
          return MedicalUpdateResult.failure(
            'تعذّر تحميل $fileName من الخادم. تم إلغاء التحديث بالكامل.',
          );
        }

        final decoded = jsonDecode(fileResponse.body);
        if (decoded is! Map<String, dynamic>) {
          return MedicalUpdateResult.failure(
            'صيغة $fileName غير صحيحة. تم إلغاء التحديث بالكامل.',
          );
        }
        downloadedFiles[fileName] = decoded;
      }

      // التحقق من التكامل الداخلي بين الملفات الخمسة قبل أي حفظ فعلي.
      final integrityError = _validateBundleIntegrity(downloadedFiles);
      if (integrityError != null) {
        ErrorHandler.instance.report(
          'MEDICAL_BUNDLE_INTEGRITY_FAILED',
          'فشل التحقق من تكامل الحزمة الطبية المُحمَّلة: $integrityError',
          sourceModule: 'medical_database_manager',
          severity: ErrorSeverity.error,
        );
        return const MedicalUpdateResult.failure(
          'البيانات المُحمَّلة غير متوافقة داخلياً. تم إلغاء التحديث '
          'للحفاظ على استقرار قاعدة بياناتك الحالية.',
        );
      }

      // كل الملفات صالحة ومتكاملة — الحفظ الفعلي الآن فقط.
      for (final entry in downloadedFiles.entries) {
        final file = await _localFileFor(entry.key);
        await file.writeAsString(jsonEncode(entry.value));
      }

      final versionFile = await _localVersionFile();
      await versionFile.writeAsString(remoteVersion);

      final newDiseasesCount =
          (downloadedFiles[MedicalBundleFiles.diseases]?['diseases'] as List?)
                  ?.length ??
              0;

      return MedicalUpdateResult.success(
        messageAr: 'تم تحديث قاعدة البيانات الطبية بنجاح إلى الإصدار '
            '$remoteVersion.',
        newDiseasesCount: newDiseasesCount,
      );
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'MEDICAL_BUNDLE_DOWNLOAD_FAILED',
        'فشل تحميل تحديث قاعدة البيانات الطبية.',
        sourceModule: 'medical_database_manager',
        severity: ErrorSeverity.error,
        exception: e,
        stackTrace: stackTrace,
      );
      return const MedicalUpdateResult.failure(
        'حدث خطأ أثناء التحديث. تبقى نسختك الحالية سليمة وتعمل بشكل طبيعي.',
      );
    }
  }

  /// فحص تكامل أساسي: كل معرّف مُشار إليه في طبقة الربط
  /// (medical_knowledge.json) يجب أن يكون موجوداً فعلياً في الملفات
  /// الأربعة الأخرى ضمن نفس الحزمة الجديدة. يُرجع نص الخطأ الأول الذي
  /// يُعثر عليه، أو null إذا كانت الحزمة سليمة بالكامل.
  String? _validateBundleIntegrity(Map<String, Map<String, dynamic>> files) {
    final diseasesJson = files[MedicalBundleFiles.diseases];
    final symptomsJson = files[MedicalBundleFiles.symptoms];
    final testsJson = files[MedicalBundleFiles.tests];
    final medicationsJson = files[MedicalBundleFiles.medications];
    final knowledgeJson = files[MedicalBundleFiles.knowledge];

    if (diseasesJson == null ||
        symptomsJson == null ||
        testsJson == null ||
        medicationsJson == null ||
        knowledgeJson == null) {
      return 'أحد الملفات الخمسة مفقود من الحزمة.';
    }

    final diseaseIds = ((diseasesJson['diseases'] as List?) ?? [])
        .map((d) => (d as Map<String, dynamic>)['id'] as String)
        .toSet();
    final symptomIds = ((symptomsJson['symptoms'] as List?) ?? [])
        .map((s) => (s as Map<String, dynamic>)['id'] as String)
        .toSet();
    final testIds = ((testsJson['tests'] as List?) ?? [])
        .map((t) => (t as Map<String, dynamic>)['id'] as String)
        .toSet();
    final medicationIds = ((medicationsJson['medications'] as List?) ?? [])
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .toSet();

    final diseaseSymptomLinks =
        (knowledgeJson['diseaseSymptomLinks'] as List?) ?? [];
    for (final link in diseaseSymptomLinks) {
      final linkMap = link as Map<String, dynamic>;
      final diseaseId = linkMap['diseaseId'] as String?;
      if (diseaseId != null && !diseaseIds.contains(diseaseId)) {
        return 'diseaseId "$diseaseId" في diseaseSymptomLinks غير موجود '
            'في قائمة الأمراض.';
      }
      final symptomIdsInLink = (linkMap['symptomIds'] as List?) ?? [];
      for (final sid in symptomIdsInLink) {
        if (!symptomIds.contains(sid)) {
          return 'symptomId "$sid" في diseaseSymptomLinks غير موجود في '
              'قائمة الأعراض.';
        }
      }
    }

    final diseaseTestLinks = (knowledgeJson['diseaseTestLinks'] as List?) ?? [];
    for (final link in diseaseTestLinks) {
      final linkMap = link as Map<String, dynamic>;
      final testIdsInLink = (linkMap['recommendedTestIds'] as List?) ?? [];
      for (final tid in testIdsInLink) {
        if (!testIds.contains(tid)) {
          return 'testId "$tid" في diseaseTestLinks غير موجود في قائمة '
              'التحاليل.';
        }
      }
    }

    final diseaseMedicationLinks =
        (knowledgeJson['diseaseMedicationLinks'] as List?) ?? [];
    for (final link in diseaseMedicationLinks) {
      final linkMap = link as Map<String, dynamic>;
      final medIdsInLink = (linkMap['commonMedicationIds'] as List?) ?? [];
      for (final mid in medIdsInLink) {
        if (!medicationIds.contains(mid)) {
          return 'medicationId "$mid" في diseaseMedicationLinks غير موجود '
              'في قائمة الأدوية.';
        }
      }
    }

    final emergencyRules =
        (knowledgeJson['emergencyEscalationRules'] as List?) ?? [];
    for (final rule in emergencyRules) {
      final ruleMap = rule as Map<String, dynamic>;
      final triggerIds = (ruleMap['triggerSymptomIds'] as List?) ?? [];
      for (final sid in triggerIds) {
        if (!symptomIds.contains(sid)) {
          return 'triggerSymptomId "$sid" في emergencyEscalationRules غير '
              'موجود في قائمة الأعراض.';
        }
      }
    }

    return null; // كل شيء سليم ومتكامل
  }

  /// إعادة الضبط الكاملة للحزمة المحلية المحدَّثة، والعودة للاعتماد
  /// على نسخة الأصول الافتراضية فقط (يُستخدم كخيار "استعادة الإعدادات
  /// الافتراضية" في شاشة الإعدادات إن احتاج المستخدم ذلك).
  Future<void> resetToDefaultBundle() async {
    for (final fileName in MedicalBundleFiles.all) {
      final file = await _localFileFor(fileName);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final versionFile = await _localVersionFile();
    if (await versionFile.exists()) {
      await versionFile.delete();
    }
  }
}
