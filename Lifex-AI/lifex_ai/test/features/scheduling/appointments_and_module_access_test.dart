import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/module_access/module_access_registry.dart';
import 'package:lifex_ai/core/trial_manager.dart';
import 'package:lifex_ai/features/scheduling/user_appointment_store.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  group('ModuleAccessRegistry', () {
    const registry = ModuleAccessRegistry();

    test('SubscriptionDoesNotBlockCoreModule — doctors/appointments', () {
      for (final phase in [
        TrialPhase.residual,
        TrialPhase.reducedMonth,
        TrialPhase.subscribed,
      ]) {
        final d = registry.evaluate(
          moduleId: 'doctors',
          phase: phase,
          feeExempt: false,
          hasActiveProfile: true,
          authenticated: true,
        );
        expect(d.canNavigate, isTrue);
        expect(d.state, ModuleAccessState.available);
      }
    });

    test('EmptyModuleIsStillAccessible — بدون ملف = EMPTY وليس منع', () {
      final d = registry.evaluate(
        moduleId: 'doctors',
        phase: TrialPhase.residual,
        feeExempt: false,
        hasActiveProfile: false,
        authenticated: true,
      );
      expect(d.canNavigate, isTrue);
      expect(d.state, ModuleAccessState.empty);
      expect(d.messageAr.contains('ACCESS DENIED'), isFalse);
    });

    test('giftFrozen → REQUIRES_EXTERNAL_SETUP للإعدادات فقط', () {
      final blocked = registry.evaluate(
        moduleId: 'doctors',
        phase: TrialPhase.giftFrozen,
        feeExempt: false,
        hasActiveProfile: true,
        authenticated: true,
      );
      expect(blocked.canNavigate, isFalse);
      expect(blocked.state, ModuleAccessState.requiresExternalSetup);

      final settings = registry.evaluate(
        moduleId: 'settings',
        phase: TrialPhase.giftFrozen,
        feeExempt: false,
        hasActiveProfile: true,
        authenticated: true,
      );
      expect(settings.canNavigate, isTrue);
    });

    test('ALL MODULES ACCESS — residual لا يحجب أي وحدة أساسية', () {
      final all = registry.evaluateAll(
        phase: TrialPhase.residual,
        feeExempt: false,
        hasActiveProfile: true,
        authenticated: true,
      );
      expect(all.every((d) => d.canNavigate), isTrue);
      expect(
        all.every((d) => d.state == ModuleAccessState.available),
        isTrue,
      );
    });

    test('premium_booking مقيد دون حجب وحدة المواعيد', () {
      const policy = SessionAccessPolicy();
      expect(
        policy.canOpenUnit(
          'appointments',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
      expect(
        policy.canUsePaidFeature(
          'premium_booking',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isFalse,
      );
    });
  });

  group('UserAppointmentStore / Calendar', () {
    test('Add Edit Delete on selected day', () {
      final store = UserAppointmentStore();
      final day = DateTime(2026, 9, 18);
      final a = store.add(
        UserAppointment(
          id: '1',
          title: 'طبيب قلب',
          dateIso: '2026-09-18',
          timeHm: '09:00',
          type: 'doctor',
        ),
      );
      expect(store.forDay(day), hasLength(1));
      expect(store.countOn(day), 1);

      final edited = UserAppointment(
        id: a.id,
        title: 'طبيب قلب — معدّل',
        dateIso: '2026-09-18',
        timeHm: '10:00',
        type: 'doctor',
      );
      expect(store.update(a.id, edited), isTrue);
      expect(store.forDay(day).first.timeHm, '10:00');

      expect(store.removeOrCancel(a.id), 'deleted');
      expect(store.forDay(day), isEmpty);
    });

    test('Provider-created لا يُحذف مباشرة — إلغاء', () {
      final store = UserAppointmentStore([
        UserAppointment(
          id: 'ext',
          title: 'مستشفى',
          dateIso: '2026-09-19',
          timeHm: '11:00',
          type: 'hospital',
          source: AppointmentSourceOwnership.providerCreated,
        ),
      ]);
      expect(store.removeOrCancel('ext'), 'cancelled_request');
      expect(store.all.first.status, AppointmentLifecycle.cancelled);
    });

    test('Month and day spoken summaries', () {
      final store = UserAppointmentStore([
        UserAppointment(
          id: 'a',
          title: 'مختبر',
          dateIso: '2026-09-18',
          timeHm: '11:30',
          type: 'laboratory',
        ),
        UserAppointment(
          id: 'b',
          title: 'صيدلية',
          dateIso: '2026-09-18',
          timeHm: '16:00',
          type: 'pharmacy',
        ),
      ]);
      final day = DateTime(2026, 9, 18);
      expect(store.spokenDayAr(day), contains('2'));
      expect(store.spokenMonthSummaryAr(DateTime(2026, 9)), contains('2'));
    });

    test('Timezone and reminder persist in map roundtrip', () {
      final a = UserAppointment(
        id: 'tz',
        title: 'متابعة',
        dateIso: '2026-10-01',
        timeHm: '08:00',
        type: 'follow_up',
        timezone: 'Asia/Damascus',
        reminderMinutes: 60,
        recurrence: AppointmentRecurrence.weekly,
      );
      final back = UserAppointment.fromMap(a.toMap());
      expect(back.timezone, 'Asia/Damascus');
      expect(back.reminderMinutes, 60);
      expect(back.recurrence, AppointmentRecurrence.weekly);
    });
  });

  group('Voice routing', () {
    test('افتح المواعيد / مواعيدي اليوم', () {
      final p = CommandParser();
      expect(
        p.parse('ليفكس افتح المواعيد').intent,
        VoiceCommandIntent.openAppointments,
      );
      expect(
        p.parse('ليفكس مواعيدي اليوم').intent,
        VoiceCommandIntent.openAppointments,
      );
      expect(
        p.parse('ليفكس الأطباء').intent,
        VoiceCommandIntent.openDoctors,
      );
    });
  });
}
