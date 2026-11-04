/// Append-only wallet ledger with optional durable local persistence.
library lifex_ai.features.finance.transaction_ledger;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum TransactionType {
  topUp,
  hospitalPayment,
  donationPayment,
  refund,
  subscriptionPayment,
  appStoreSale,
  platformFee,
  extraService,
}

class WalletTransaction {
  final String transactionId;
  final String profileId;
  final TransactionType type;
  final int amountInSmallestUnit;
  final String currencyCode;
  final String? relatedGatewayTransactionId;
  final String? relatedEntityId;
  final DateTime recordedAt;

  const WalletTransaction({
    required this.transactionId,
    required this.profileId,
    required this.type,
    required this.amountInSmallestUnit,
    required this.currencyCode,
    this.relatedGatewayTransactionId,
    this.relatedEntityId,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'profileId': profileId,
        'type': type.name,
        'amountInSmallestUnit': amountInSmallestUnit,
        'currencyCode': currencyCode,
        'relatedGatewayTransactionId': relatedGatewayTransactionId,
        'relatedEntityId': relatedEntityId,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = TransactionType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => throw const FormatException('Unknown transaction type'),
    );
    final amount = json['amountInSmallestUnit'];
    if (amount is! int || amount <= 0) {
      throw const FormatException('Invalid transaction amount');
    }
    final profileId = json['profileId'] as String?;
    final currency = json['currencyCode'] as String?;
    final id = json['transactionId'] as String?;
    if (profileId == null || profileId.isEmpty ||
        currency == null || currency.isEmpty || id == null || id.isEmpty) {
      throw const FormatException('Invalid transaction identity');
    }
    return WalletTransaction(
      transactionId: id,
      profileId: profileId,
      type: type,
      amountInSmallestUnit: amount,
      currencyCode: currency.toUpperCase(),
      relatedGatewayTransactionId:
          json['relatedGatewayTransactionId'] as String?,
      relatedEntityId: json['relatedEntityId'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }
}

/// Append-only ledger. Persistence is local durability only; it is not a
/// payment processor, bank balance, or server-authoritative account ledger.
class TransactionLedger {
  TransactionLedger({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String storageKey = 'lifex_wallet_ledger_v1';
  final SharedPreferences? _preferences;
  final List<WalletTransaction> _transactions = [];
  int _counter = 0;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> load() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Ledger is not a list');
      final restored = decoded
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList(growable: false);
      _transactions
        ..clear()
        ..addAll(restored);
      _counter = restored.length;
    } catch (_) {
      // Never silently overwrite an unreadable ledger. Keep the app usable,
      // but surface a clear warning and leave the stored value untouched.
      rethrow;
    }
  }

  Future<void> flush() => _writeQueue;

  WalletTransaction record({
    required String profileId,
    required TransactionType type,
    required int amountInSmallestUnit,
    required String currencyCode,
    String? relatedGatewayTransactionId,
    String? relatedEntityId,
  }) {
    if (profileId.trim().isEmpty || amountInSmallestUnit <= 0 ||
        currencyCode.trim().isEmpty) {
      throw ArgumentError('Invalid wallet transaction');
    }
    _counter++;
    final transaction = WalletTransaction(
      transactionId: 'TXN-${DateTime.now().microsecondsSinceEpoch}-$_counter',
      profileId: profileId,
      type: type,
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode.trim().toUpperCase(),
      relatedGatewayTransactionId: relatedGatewayTransactionId,
      relatedEntityId: relatedEntityId,
      recordedAt: DateTime.now(),
    );
    _transactions.add(transaction);
    _queuePersist();
    return transaction;
  }

  void _queuePersist() {
    final prefs = _preferences;
    if (prefs == null) return;
    final snapshot = jsonEncode(
      _transactions.map((transaction) => transaction.toJson()).toList(),
    );
    _writeQueue = _writeQueue.then((_) async {
      final saved = await prefs.setString(storageKey, snapshot);
      if (!saved) throw StateError('Wallet ledger could not be persisted');
    });
  }

  List<WalletTransaction> historyFor(String profileId) =>
      List.unmodifiable(_transactions.where((t) => t.profileId == profileId));

  List<WalletTransaction> get allTransactions =>
      List.unmodifiable(_transactions);

  int currentBalanceFor(String profileId, {String? currencyCode}) {
    var balance = 0;
    for (final transaction in _transactions.where((t) =>
        t.profileId == profileId &&
        (currencyCode == null ||
            t.currencyCode == currencyCode.toUpperCase()))) {
      switch (transaction.type) {
        case TransactionType.topUp:
        case TransactionType.refund:
          balance += transaction.amountInSmallestUnit;
          break;
        case TransactionType.hospitalPayment:
        case TransactionType.donationPayment:
        case TransactionType.subscriptionPayment:
        case TransactionType.appStoreSale:
        case TransactionType.platformFee:
        case TransactionType.extraService:
          balance -= transaction.amountInSmallestUnit;
          break;
      }
    }
    return balance;
  }
}
