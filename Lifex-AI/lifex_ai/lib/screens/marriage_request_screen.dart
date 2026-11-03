/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: marriage_request_screen.dart
/// ثلاث خطوات باتجاهين: طلب زواج ↔ موافقة، مؤشر النسبة، طلب السبب ↔ موافقة الكشف.
/// =============================================================
library lifex_ai.screens.marriage_request_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/family/marriage_request_ledger.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import '../features/qiran/qiran_engine.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';

class MarriageRequestScreen extends StatelessWidget {
  const MarriageRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final me = controller.activeProfile;
        if (me == null) {
          return Scaffold(
            appBar: AppBar(title: const LifexText('القران والتناسب الصحي')),
            body: const Center(child: LifexText('لا يوجد ملف نشط.')),
          );
        }
        final others = controller.allProfiles
            .where((item) => item.profileId != me.profileId)
            .toList();

        return Scaffold(
          appBar: AppBar(title: const LifexText('القران والتناسب الصحي')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'ثلاث خطوات على الجهاز: طلب زواج يقابله موافقة الطرف الآخر، '
                    'ثم مؤشر النسبة والتوافق، ثم طلب معرفة السبب يقابله موافقة الكشف. '
                    'الاتجاهان متماثلان. لا أمراض قبل الموافقة الثانية.',
              ),
              LifexText('الملف النشط: ${me.fullName}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (others.isEmpty)
                const LifexText('أضيفي ملفاً آخر من إدارة العائلة أولاً.'),
              for (final other in others)
                _PairCard(me: me, other: other, controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({
    required this.me,
    required this.other,
    required this.controller,
  });

  final HealthProfile me;
  final HealthProfile other;
  final ActiveProfileController controller;

  @override
  Widget build(BuildContext context) {
    final ledger = MarriageRequestLedger();
    const engine = QiranEngine();
    final request = ledger.pairOf(me, other);
    final requestId = request?.id;
    final verdict = request == null
        ? null
        : engine.verdict(a: me, b: other, request: request);
    final reasons = request == null
        ? const <String>[]
        : engine.sealedReasons(a: me, b: other, request: request);
    final incomingPending = request != null &&
        request.status == MarriageRequestStatus.pending &&
        request.toProfileId == me.profileId;
    final outgoingPending = request != null &&
        request.status == MarriageRequestStatus.pending &&
        request.fromProfileId == me.profileId;
    final reasonIncoming = request != null &&
        request.status == MarriageRequestStatus.accepted &&
        request.reasonAskStatus == MarriageRequestStatus.pending &&
        request.reasonAskFromId.isNotEmpty &&
        request.reasonAskFromId != me.profileId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LifexText(other.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            LifexText('١) طلب زواج ↔ موافقة',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (request == null || request.status == MarriageRequestStatus.declined)
              FilledButton(
                onPressed: () {
                  ledger.send(from: me, to: other);
                  controller.saveActiveProfileChanges();
                },
                child: const LifexText('طلب زواج'),
              )
            else if (incomingPending)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () {
                      ledger.send(from: me, to: other);
                      controller.saveActiveProfileChanges();
                    },
                    child: const LifexText('موافقة'),
                  ),
                  TextButton(
                    onPressed: () {
                      ledger.setStatus(
                        from: other,
                        to: me,
                        requestId: requestId ?? '',
                        status: MarriageRequestStatus.declined,
                      );
                      controller.saveActiveProfileChanges();
                    },
                    child: const LifexText('رفض'),
                  ),
                ],
              )
            else if (outgoingPending)
              const LifexText('بانتظار موافقة الطرف الآخر على طلب الزواج.')
            else
              const LifexText('الموافقة تمت من الطرفين على فتح النسبة.'),
            const SizedBox(height: 16),
            LifexText('٢) مؤشر النسبة والتوافق',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (verdict == null || !verdict.ready)
              const LifexText('لا نسبة قبل موافقة طلب الزواج.')
            else ...[
              LifexText(verdict.publicAr,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: verdict.percent / 100),
              LifexText('${verdict.percent}٪'),
            ],
            const SizedBox(height: 16),
            LifexText('٣) طلب معرفة السبب ↔ موافقة الكشف',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (verdict == null ||
                !verdict.ready ||
                !engine.canAskReason(verdict))
              const LifexText('طلب السبب يظهر عند تعارض مرتفع أو نتيجة غير مناسب.')
            else if (reasonIncoming)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () {
                      ledger.answerReason(
                        from: other,
                        to: me,
                        requestId: requestId ?? '',
                        accept: true,
                      );
                      controller.saveActiveProfileChanges();
                    },
                    child: const LifexText('موافقة الكشف'),
                  ),
                  TextButton(
                    onPressed: () {
                      ledger.answerReason(
                        from: other,
                        to: me,
                        requestId: requestId ?? '',
                        accept: false,
                      );
                      controller.saveActiveProfileChanges();
                    },
                    child: const LifexText('رفض الكشف'),
                  ),
                ],
              )
            else if (request?.reasonAskStatus == MarriageRequestStatus.accepted)
              const LifexText('كُشف السبب بعد الموافقة المعاكسة.')
            else if (request?.reasonAskStatus == MarriageRequestStatus.pending &&
                request?.reasonAskFromId == me.profileId)
              const LifexText('بانتظار موافقة الطرف الآخر على كشف السبب.')
            else
              FilledButton.tonal(
                onPressed: () {
                  final current = ledger.pairOf(me, other);
                  if (current == null) return;
                  ledger.askReason(
                    from: me,
                    to: other,
                    requestId: current.id,
                    askerId: me.profileId,
                  );
                  controller.saveActiveProfileChanges();
                },
                child: const LifexText('طلب معرفة السبب'),
              ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              const LifexText('الأسباب بعد موافقة الكشف:'),
              for (final line in reasons) LifexText(line),
            ],
          ],
        ),
      ),
    );
  }
}
