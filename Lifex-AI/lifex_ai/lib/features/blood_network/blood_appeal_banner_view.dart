/// شريط نداء محلي. بلا وميض، ويُغلق مرة واحدة.
library lifex_ai.features.blood_network.blood_appeal_banner_view;

import 'package:flutter/material.dart';

import '../profile/health_profile.dart';
import '../network_box/profile_box_store.dart';
import 'blood_appeal_desk.dart';

class BloodAppealBannerView extends StatelessWidget {
  const BloodAppealBannerView({
    super.key,
    required this.donor,
    required this.profiles,
    required this.onOpen,
    this.onChanged,
    this.now,
  });

  final HealthProfile donor;
  final List<HealthProfile> profiles;
  final VoidCallback onOpen;
  final VoidCallback? onChanged;

  /// ساعة السيناريو. الغياب يعني ساعة الجهاز.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    BloodAppealBanner? banner;
    ProfileBoxStore? holder;
    for (final profile in profiles) {
      final store = ProfileBoxStore(profile);
      final found = const BloodAppealDesk().bannerFor(
        donor: donor,
        unitStore: store,
        now: now,
      );
      if (found != null) {
        banner = found;
        holder = store;
        break;
      }
    }
    if (banner == null || holder == null) return const SizedBox.shrink();
    final shown = banner;
    final unitStore = holder;
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'نداء تبرع بالدم من ${shown.unitName}. الزمرة ${shown.bloodLabel}. ${shown.whereAr}.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shown.unitName,
                  style: Theme.of(context).textTheme.titleMedium),
              Text('الزمرة ${shown.bloodLabel}'),
              Text(shown.whereAr),
              Text('ينتهي: ${shown.expiresAt}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () {
                      const BloodAppealDesk().respond(
                        unitStore: unitStore,
                        donor: donor,
                        requestId: shown.requestId,
                        responseStatus: 'willing',
                        now: now,
                      );
                      onOpen();
                      onChanged?.call();
                    },
                    child: const Text('أرغب في التبرع'),
                  ),
                  TextButton(
                    onPressed: () {
                      const BloodAppealDesk().respond(
                        unitStore: unitStore,
                        donor: donor,
                        requestId: shown.requestId,
                        responseStatus: 'unavailable',
                        now: now,
                      );
                      onChanged?.call();
                    },
                    child: const Text('لست متاحًا'),
                  ),
                  TextButton(
                    onPressed: () {
                      const BloodAppealDesk().dismiss(donor, shown.requestId);
                      onChanged?.call();
                    },
                    child: const Text('إغلاق التنبيه'),
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
