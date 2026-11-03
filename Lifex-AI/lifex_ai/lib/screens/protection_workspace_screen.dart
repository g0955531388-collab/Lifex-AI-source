/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: protection_workspace_screen.dart
/// فقدان الجهاز، الطاقة، المراقبة، الأجهزة.
/// =============================================================
library lifex_ai.screens.protection_workspace_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/device_guardian/account_recovery_manager.dart';
import '../features/device_guardian/device_guardian_manager.dart';
import '../features/device_guardian/device_presence_note.dart';
import 'package:geolocator/geolocator.dart';

import '../features/device_guardian/lost_phone_desk.dart';
import '../features/device_guardian/lost_phone_policy.dart';
import '../features/device_guardian/trusted_devices_manager.dart';
import '../features/device_guardian/watch_bond_ledger.dart';
import '../features/energy/energy_manager.dart';
import '../features/energy/survival_energy_mode.dart';
import '../features/network_box/box_unit_catalog.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';
import 'box_unit_screen.dart';
import 'manual_vitals_screen.dart';
import 'permission_transparency_screen.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class ProtectionWorkspaceScreen extends StatelessWidget {
  const ProtectionWorkspaceScreen({super.key});

  String get _thisDeviceId => 'this-device';

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        final energy = context.watch<EnergyManager>();
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const LifexText('الحماية حتى آخر يوم')),
            body: const Center(child: LifexText('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final guardian = store.map(BoxKeys.guardian);
        final links = store.list(BoxKeys.remoteLinks);
        final bonds = WatchBondLedger(links);
        final presence = const DevicePresenceNote().describe(
          lastLocalHeartbeat: DateTime.tryParse(
            guardian['lastHeartbeat']?.toString() ?? '',
          ),
          lostReported: guardian['lost'] == true,
          locationReaderBound: false,
        );
        final battery = energy.batteryMonitor.lastKnownStatus;
        final hasReader = energy.batteryMonitor.reader != null;
        return Scaffold(
          appBar: AppBar(title: const LifexText('الحماية حتى آخر يوم')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'حماية الجهاز محلية على هذا الهاتف. المسح عن بعد وقفل الأجهزة الأخرى يحتاج خادماً. بلا Device Admin.',
              ),
              const SizedBox(height: 12),
              LifexText('حارس الجهاز',
                  style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                title: const LifexText('هذا الجهاز'),
                subtitle: LifexText(
                  guardian['registered'] == true
                      ? 'مسجَّل محلياً'
                      : 'غير مسجَّل بعد',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () {
                    final now = DateTime.now().toIso8601String();
                    store.setMap(BoxKeys.guardian, {
                      ...guardian,
                      'registered': true,
                      'deviceId': _thisDeviceId,
                      'registeredAt': now,
                      'lastHeartbeat': now,
                    });
                    controller.saveActiveProfileChanges();
                  },
                  child: const LifexText('تسجيل'),
                ),
              ),
              ListTile(
                title: const LifexText('حضور هذا الجهاز'),
                subtitle: LifexText(presence),
              ),
              ListTile(
                title: const LifexText('الإبلاغ عن فقدان'),
                subtitle: LifexText(guardian['lost'] == true
                    ? 'مُبلَّغ محلياً — بانتظار خادم للقفل البعيد'
                    : 'لم يُبلَّغ'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    final trusted = TrustedDevicesManager()
                      ..registerDevice(TrustedDevice(
                        deviceId: _thisDeviceId,
                        deviceLabel: 'هذا الجهاز',
                      ));
                    DeviceGuardianManager(
                      recoveryManager: AccountRecoveryManager(),
                      trustedDevicesManager: trusted,
                    ).reportDeviceLostOrStolen(
                      deviceId: _thisDeviceId,
                      wasStolen: false,
                    );
                    store.setMap(BoxKeys.guardian, {
                      ...store.map(BoxKeys.guardian),
                      'lost': true,
                      'lostAt': DateTime.now().toIso8601String(),
                    });
                    controller.saveActiveProfileChanges();
                  },
                  child: const LifexText('فقدان'),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LifexText('سياسة أين جوالي',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      LifexText(const LostPhonePolicy().nearbyActionAr()),
                      const SizedBox(height: 6),
                      LifexText(const LostPhonePolicy().farSmsTemplate()),
                      const SizedBox(height: 6),
                      LifexText(const LostPhonePolicy().simChangeWithoutPinAr()),
                      const SizedBox(height: 8),
                      LifexText(LostPhoneDesk.limitAr),
                      const SizedBox(height: 8),
                      LifexText(
                        (guardian['pinHash']?.toString().isNotEmpty == true)
                            ? 'بصمة الرمز محفوظة. الرمز نفسه غير مخزّن.'
                            : guardian['pin']?.toString().isNotEmpty == true
                                ? 'وُجد رمز قديم بصيغة واضحة. أعد كتابته ليُستبدل ببصمة.'
                                : 'لم تُحفظ بصمة رمز بعد.',
                      ),
                      TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: tr('رمز أين جوالي'),
                        ),
                        onSubmitted: (value) async {
                          final desk = LostPhoneDesk();
                          await desk.rememberSecret(value);
                          if (desk.secretHash == null) return;
                          final next = {...store.map(BoxKeys.guardian)};
                          next.remove('pin');
                          next['pinHash'] = desk.secretHash;
                          store.setMap(BoxKeys.guardian, next);
                          controller.saveActiveProfileChanges();
                        },
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        button: true,
                        label: tr('فحص جاهزية العثور'),
                        child: OutlinedButton(
                          onPressed: () async {
                            bool? locationOn;
                            try {
                              locationOn = await Geolocator.isLocationServiceEnabled();
                            } catch (_) {
                              locationOn = null;
                            }
                            final desk = LostPhoneDesk()..restore({
                              ...guardian,
                              'pinHash': guardian['pinHash'],
                              'consent': guardian['findConsent'] == true,
                            });
                            final message = desk.arm(
                              userConsent: guardian['findConsent'] == true,
                              mobileDataOn: null,
                              locationOn: locationOn,
                              now: DateTime.now(),
                            );
                            store.setMap(BoxKeys.guardian, {
                              ...store.map(BoxKeys.guardian),
                              'findCheckedAt': DateTime.now().toIso8601String(),
                              'findLocationOn': locationOn,
                              'findReadinessAr': message,
                              'findArmed': false,
                            });
                            controller.saveActiveProfileChanges();
                          },
                          child: const LifexText('أعد فحص الجاهزية'),
                        ),
                      ),
                      LifexText(
                        guardian['findReadinessAr']?.toString() ??
                            LostPhoneDesk().readinessAr(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const LifexText('أوافق على متطلبات العثور'),
                        subtitle: const LifexText(
                          'الموافقة وحدها لا تفعّل الحماية إذا لم تُقاس البيانات والموقع.',
                        ),
                        value: guardian['findConsent'] == true,
                        onChanged: (value) {
                          store.setMap(BoxKeys.guardian, {
                            ...store.map(BoxKeys.guardian),
                            'findConsent': value,
                            'findArmed': false,
                          });
                          controller.saveActiveProfileChanges();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LifexText('الطاقة', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                title: const LifexText('قراءة البطارية'),
                subtitle: LifexText(
                  hasReader
                      ? 'المستوى ${battery.level}% — ${battery.isCharging ? 'يشحن' : 'لا يشحن'}'
                      : 'لا توجد قراءة من النظام حتى يُربط قارئ بطارية حقيقي',
                ),
              ),
              ListTile(
                title: const LifexText('وضع البقاء'),
                subtitle: LifexText(
                  energy.survivalMode.isActive
                      ? 'مفعّل — الطوارئ تبقى والتنبيهات تبقى'
                      : 'غير مفعّل. يُفعَّل تحت ${energy.survivalMode.activationThresholdPercent}% عند توفر قراءة',
                ),
              ),
              LifexText(
                'يبقى يعمل: ${alwaysActiveFeatures.join('، ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              LifexText('المراقبة عن بعد',
                  style: Theme.of(context).textTheme.titleMedium),
              const HonestyBanner(
                messageAr:
                    'الربط بين ملفين على هذا الجهاز. البث الحي عبر الحدود يحتاج قناة معتمدة بعد موافقة الطرفين.',
              ),
              for (final member in controller.allProfiles)
                if (member.profileId != profile.profileId)
                  Card(
                    child: ListTile(
                      title: LifexText(member.fullName),
                      subtitle: LifexText(_bondLabel(bonds.forProfile(member.profileId))),
                      trailing: PopupMenuButton<WatchBondGrade>(
                        onSelected: (grade) async {
                          var counterpartHere = false;
                          if (grade == WatchBondGrade.liveWatch ||
                              grade == WatchBondGrade.emergency) {
                            counterpartHere = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const LifexText('موافقة الطرفين'),
                                    content: const LifexText(
                                      'المستوى الحي لا يكتمل إلا إذا كان الطرف الآخر أمام الشاشة ويوافق. '
                                      'حتى بعد ذلك لن أبث صورة إلى شبكة قبل خادم معتمد.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const LifexText('الطرف غائب'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const LifexText('نعم، يوافق أمامي'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          }
                          if (!context.mounted) return;
                          bonds.propose(
                            counterpartProfileId: member.profileId,
                            grade: grade,
                            counterpartStandingHere: counterpartHere,
                          );
                          store.setList(BoxKeys.remoteLinks, bonds.rows);
                          controller.saveActiveProfileChanges();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: WatchBondGrade.notices,
                            child: LifexText('إشعارات محلية'),
                          ),
                          PopupMenuItem(
                            value: WatchBondGrade.followup,
                            child: LifexText('متابعة محلية'),
                          ),
                          PopupMenuItem(
                            value: WatchBondGrade.liveWatch,
                            child: LifexText('نية بث حي'),
                          ),
                          PopupMenuItem(
                            value: WatchBondGrade.emergency,
                            child: LifexText('طوارئ عائلية'),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (controller.allProfiles.length <= 1)
                const LifexText('أضف فرد عائلة من الإعدادات لربط مراقب.'),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const LifexText('شفافية الصلاحيات'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PermissionTransparencyScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.devices_outlined),
                title: const LifexText('سجل الأجهزة المرتبطة'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BoxUnitScreen(
                      unit: BoxUnitCatalog.connectedDevices,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const LifexText('الأجهزة الطبية والقياسات'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BoxUnitScreen(
                      unit: BoxUnitCatalog.medicalDevices,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const LifexText('قياسات يدوية'),
                subtitle: const LifexText('ليست من الكاميرا وليست تشخيصاً'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManualVitalsScreen(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _bondLabel(WatchBond? bond) {
    if (bond == null) return 'بلا ربط';
    return '${bond.gradeAr} — ${bond.honestyAr()}';
  }
}
