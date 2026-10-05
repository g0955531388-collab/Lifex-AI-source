/// =============================================================
/// Lifex-AI — المكوّنات المشتركة
/// الملف: encyclopedia_share_bar.dart
/// المشاركة العامة تمر عبر LioSensitiveActionEntry → LIO.
/// =============================================================
library lifex_ai.widgets.encyclopedia_share_bar;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';

class EncyclopediaShareBar extends StatelessWidget {
  const EncyclopediaShareBar({super.key});

  Future<void> _share(BuildContext context) async {
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.sharePublicEncyclopedia(
      gatewayRequest: LioGatewayRequest(
        requestId: 'share_ency_${DateTime.now().millisecondsSinceEpoch}',
        correlationId: 'share_public',
        identityAccountId: 'public_share',
        purpose: 'education',
        requestedAction: 'share_public_encyclopedia',
        dataScope: 'public',
        sensitivity: LioDataSensitivity.public,
        consent: const LioConsentContext(
          consentGranted: true,
          purposeAligned: true,
        ),
        riskLevel: LioActionRisk.low,
        timestamp: DateTime.now().toUtc(),
        authenticated: true,
        authorized: true,
        minimumNecessarySatisfied: true,
      ),
    );
    if (!context.mounted) return;
    final msg = outcome.executed
        ? (outcome.value?.messageAr ?? 'تمت المشاركة.')
        : 'توقفت المشاركة عند LIO (${outcome.decision.wireDecision}).';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يحق لك مشاركة هذه الموسوعة مع صديق أو مواقع التواصل',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareIcon(
                    icon: Icons.share,
                    label: 'مشاركة',
                    onTap: () => _share(context),
                  ),
                  _ShareIcon(
                    icon: Icons.chat,
                    label: 'واتساب',
                    onTap: () => _share(context),
                  ),
                  _ShareIcon(
                    icon: Icons.send,
                    label: 'تلغرام',
                    onTap: () => _share(context),
                  ),
                  _ShareIcon(
                    icon: Icons.public,
                    label: 'تواصل',
                    onTap: () => _share(context),
                  ),
                  _ShareIcon(
                    icon: Icons.groups,
                    label: 'أصدقاء',
                    onTap: () => _share(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
