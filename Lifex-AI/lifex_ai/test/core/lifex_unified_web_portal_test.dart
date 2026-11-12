import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/attribution/project_attribution.dart';
import 'package:lifex_ai/core/ui/lifex_unified_web_portal.dart';

void main() {
  test('البوابة لا تبدأ بعلاج معتمد ولا بجهاز متصل', () {
    final portal = LifexPortalController();
    expect(portal.notes, isEmpty);
    expect(UserCareNote.statusAr, contains('ليست'));
    expect(UserCareNote.statusAr, isNot(contains('معتمد ومفعل')));
    expect(LifexUnifiedThemeConfig.registry.length, 5);
    expect(ProjectAttribution.systemName, 'Lifex-AI Global Health Network');
  });

  test('أمر الكاميرا لا يدّعي قياس مسافة', () async {
    final portal = LifexPortalController();
    var opened = false;
    portal.onOpenCamera = () => opened = true;
    await portal.executeUnifiedCommand('افتح كاميرا المكفوفين');
    expect(opened, isTrue);
    expect(portal.activeRoute, 'vision_radar');
    expect(portal.lastSystemAnnouncement, contains('لا تقيس'));
    expect(portal.lastSystemAnnouncement, isNot(contains('تم تشغيل الرادار')));
    expect(portal.lastSystemAnnouncement, isNot(contains('نجاح')));
  });

  test('فشل الاستماع لا يفتح الكاميرا', () async {
    final portal = LifexPortalController();
    var opened = false;
    portal.onOpenCamera = () => opened = true;
    portal.onListen = () async =>
        const PortalListenResult.failure('رفض النظام إذن الميكروفون.');
    await portal.listenOnce();
    expect(opened, isFalse);
    expect(portal.lastSystemAnnouncement, contains('الميكروفون'));
    expect(portal.listening, isFalse);
  });

  test('الاستماع الناجح ينفّذ الأمر ثم الإيقاف يقطع الجلسة', () async {
    final portal = LifexPortalController();
    var stopped = false;
    portal.onListen = () async => const PortalListenResult.success('بحث دواء');
    portal.onStopListen = () async => stopped = true;
    portal.onOpenSearch = () {};
    await portal.listenOnce();
    expect(portal.activeRoute, 'dashboard');
    expect(portal.lastSystemAnnouncement, contains('لم يُستدعَ نموذج'));
    await portal.stopListening();
    expect(stopped, isTrue);
    expect(portal.lastSystemAnnouncement, 'أوقفت الاستماع.');
  });

  test('مسار غير مربوط لا يُحسب نجاحاً', () async {
    final portal = LifexPortalController();
    await portal.executeUnifiedCommand('افتح الأجهزة');
    expect(portal.lastSystemAnnouncement, contains('غير مربوط'));
    expect(portal.lastSystemAnnouncement, isNot(contains('تم تفعيل')));
  });

  test('التغذية لا تُحسب والقصّ ليس تفويضاً', () async {
    final plan = LifexPortalController.planCommand('احسب الماكرو');
    expect(plan.announcement, contains('لا حاسبة'));
    expect(plan.action, PortalAction.none);
    expect(LifexPortalController.inputTrimIsNotAuthorization, isTrue);
    final kept = LifexPortalController.planCommand('<كاميرا>');
    expect(kept.action, PortalAction.openCamera);
  });

  test('الرادار ومنع الفتح لا يشغّلان الكاميرا', () async {
    final portal = LifexPortalController();
    var opened = false;
    portal.onOpenCamera = () => opened = true;
    await portal.executeUnifiedCommand('شغّل الرادار');
    expect(opened, isFalse);
    expect(portal.lastSystemAnnouncement, contains('لا رادار'));
    await portal.executeUnifiedCommand('لا تفتح الكاميرا');
    expect(opened, isFalse);
    expect(portal.lastSystemAnnouncement, contains('لم يُنفَّذ فتح'));
  });

  test('فشل إيقاف المحرك لا يُعرض كإيقاف ناجح', () async {
    final portal = LifexPortalController();
    portal.onStopListen = () async => throw StateError('engine');
    await portal.stopListening();
    expect(portal.listening, isFalse);
    expect(portal.lastSystemAnnouncement, contains('تعذّر إيقاف'));
    expect(portal.lastSystemAnnouncement, isNot(contains('أوقفت الاستماع')));
  });

  test('الملاحظة تبقى وصفاً كتبه المستخدم', () {
    final portal = LifexPortalController();
    portal.addUserNote('ملاحظة ضغط', 'متابعة', 'قراءة كتبها المستخدم');
    expect(portal.notes.single.title, 'ملاحظة ضغط');
    expect(portal.lastSystemAnnouncement, UserCareNote.statusAr);
    expect(UserCareNote.storedInClinicalRecord, isFalse);
  });
}
