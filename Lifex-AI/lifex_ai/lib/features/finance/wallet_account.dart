/// =============================================================
/// Lifex-AI — محفظة / حساب مالي
/// الرصيد المعروض يُشتق من السجل وليس رقم واجهة عشوائي.
/// =============================================================
library lifex_ai.features.finance.wallet_account;

enum WalletStatus {
  active,
  limited,
  frozen,
  underReview,
  closed,
}

/// أرصدة مفصولة — لا تستخدم رقماً واحداً للعمليات المعلقة.
class WalletBalances {
  const WalletBalances({
    required this.availableMinor,
    required this.pendingMinor,
    required this.reservedMinor,
    required this.currencyCode,
  });

  final int availableMinor;
  final int pendingMinor;
  final int reservedMinor;
  final String currencyCode;

  int get totalKnownMinor => availableMinor + pendingMinor + reservedMinor;
}

class WalletAccount {
  WalletAccount({
    required this.walletId,
    required this.ownerIdentityId,
    required this.accountId,
    required this.currencyCode,
    this.status = WalletStatus.active,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();

  final String walletId;
  final String ownerIdentityId;
  final String accountId;
  final String currencyCode;
  WalletStatus status;
  final DateTime createdAt;
  DateTime updatedAt;
  final String provenance = 'lifex_wallet_v1';

  bool get canTransact =>
      status == WalletStatus.active || status == WalletStatus.limited;
}
