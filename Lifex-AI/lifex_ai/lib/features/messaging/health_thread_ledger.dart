/// =============================================================
/// Lifex-AI — التراسل الصحي
/// الملف: health_thread_ledger.dart
/// خيوط محادثة محلية بين الملفات على الجهاز. تسليم فوري هنا فقط.
/// =============================================================
library lifex_ai.features.messaging.health_thread_ledger;

import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';
import 'conversation_type_router.dart';
import 'health_channel_filter.dart';

class HealthThreadPost {
  const HealthThreadPost({
    required this.id,
    required this.fromId,
    required this.text,
    this.fileName = '',
    this.sizeBytes = 0,
    required this.at,
    this.delivered = true,
    this.read = false,
  });

  final String id;
  final String fromId;
  final String text;
  final String fileName;
  final int sizeBytes;
  final DateTime at;
  final bool delivered;
  final bool read;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'text': text,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'at': at.toIso8601String(),
        'delivered': delivered,
        'read': read,
      };

  factory HealthThreadPost.fromJson(Map<String, dynamic> json) =>
      HealthThreadPost(
        id: json['id'] as String? ?? '',
        fromId: json['fromId'] as String? ?? '',
        text: json['text'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        delivered: json['delivered'] as bool? ?? true,
        read: json['read'] as bool? ?? false,
      );
}

class HealthThreadSendResult {
  const HealthThreadSendResult({
    required this.ok,
    required this.messageAr,
    this.post,
  });

  final bool ok;
  final String messageAr;
  final HealthThreadPost? post;
}

class HealthThreadLedger {
  HealthThreadLedger({this.filter = const HealthChannelFilter()});

  final HealthChannelFilter filter;

  static String threadId(String a, String b) {
    final ids = [a, b]..sort();
    return 'HT-${ids.join('-')}';
  }

  List<HealthThreadPost> posts(HealthProfile me, String threadId) {
    return ProfileBoxStore(me)
        .list(BoxKeys.healthThreads)
        .where((item) => item['threadId'] == threadId)
        .map(HealthThreadPost.fromJson)
        .toList();
  }

  HealthThreadSendResult send({
    required HealthProfile from,
    required HealthProfile to,
    required ConversationType type,
    required String text,
    String fileName = '',
    int sizeBytes = 0,
    required bool subscriber,
  }) {
    final trimmed = text.trim();
    final named = fileName.trim();
    if (trimmed.isEmpty && named.isEmpty) {
      return const HealthThreadSendResult(
        ok: false,
        messageAr: 'اكتب رسالة أو أرفق ملفاً قبل الإرسال.',
      );
    }
    final verdict = filter.inspect(
      type: type,
      senderSeat: from.billingSeat,
      text: trimmed,
      fileName: named,
      sizeBytes: sizeBytes,
      subscriber: subscriber,
    );
    if (!verdict.allowed) {
      return HealthThreadSendResult(ok: false, messageAr: verdict.messageAr);
    }
    final post = HealthThreadPost(
      id: 'HP-${DateTime.now().millisecondsSinceEpoch}',
      fromId: from.profileId,
      text: trimmed,
      fileName: named,
      sizeBytes: sizeBytes,
      at: DateTime.now(),
    );
    final packed = post.toJson()
      ..['threadId'] = threadId(from.profileId, to.profileId);
    ProfileBoxStore(from).add(BoxKeys.healthThreads, packed);
    if (from.profileId != to.profileId) {
      ProfileBoxStore(to).add(BoxKeys.healthThreads, packed);
    }
    return HealthThreadSendResult(
      ok: true,
      messageAr: verdict.messageAr,
      post: post,
    );
  }
}
