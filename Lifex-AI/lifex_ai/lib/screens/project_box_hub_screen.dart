/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: project_box_hub_screen.dart
/// مدخل الصندوق الكامل: نواة، مؤسسات، حماية، عالم.
/// =============================================================
library lifex_ai.screens.project_box_hub_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/network_box/box_unit_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';
import 'appointments_screen.dart';
import 'blood_request_screen.dart';
import 'booking_workspace_screen.dart';
import 'box_unit_screen.dart';
import 'camera_notes_screen.dart';
import 'care_order_screen.dart';
import 'dental_chart_screen.dart';
import 'doctor_directory_screen.dart';
import 'family_management_screen.dart';
import 'health_profile_screen.dart';
import 'identity_workspace_screen.dart';
import 'medications_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'protection_workspace_screen.dart';
import 'smart_health_questionnaire_screen.dart';
import 'stamped_reports_screen.dart';
import 'system_search_screen.dart';
import 'wallet_screen.dart';
import 'women_cycle_screen.dart';
import 'world_workspace_screen.dart';
import '../widgets/lifex_text.dart';

class ProjectBoxHubScreen extends StatelessWidget {
  const ProjectBoxHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    return Scaffold(
      appBar: AppBar(title: const LifexText('صندوق المشروع أ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LifexText('من الصفر حتى آخر يوم',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const LifexText(
              'كل مقعد يفتح أقسامه: ملف عام، علاقة، حجز، سجلات. ليست صفحة واحدة.'),
          const SizedBox(height: 8),
          HonestyBanner.localAndServer(),
          const SizedBox(height: 16),
          _section(context, '1 النواة', [
            _Tile('الهوية من التكوين', Icons.badge_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const IdentityWorkspaceScreen()));
            }),
            _Tile('الملف الصحي الحي', Icons.person_outline, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HealthProfileScreen(profile: profile),
                ),
              );
            }),
            _Tile('الاستبيان', Icons.assignment_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SmartHealthQuestionnaireScreen()));
            }),
            _Tile('العائلة', Icons.family_restroom_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FamilyManagementScreen()));
            }),
            _Tile('أدويتي', Icons.medication_outlined, () {
              final id = profile?.profileId;
              if (id == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicationsScreen(profileId: id),
                ),
              );
            }),
            _Tile('المواعيد الشخصية', Icons.event_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen()));
            }),
            _Tile(
                'الرعاية المزمنة والهمم',
                Icons.accessibility_new_outlined,
                () => _openUnit(context, BoxUnitCatalog.chronicPlans)),
            _Tile('رعاية الإناث والحمل', Icons.pregnant_woman_outlined,
                () => _openUnit(context, BoxUnitCatalog.women)),
            _Tile('دورة وحمل اختيارية', Icons.calendar_today_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WomenCycleScreen()));
            }),
            _Tile('التأهيل والتدريب', Icons.school_outlined,
                () => _openUnit(context, BoxUnitCatalog.education)),
            _Tile('التقارير المختومة', Icons.description_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StampedReportsScreen()));
            }),
            _Tile('بحث المنظومة', Icons.search, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SystemSearchScreen()));
            }),
          ]),
          _section(context, '2 المؤسسات — فراغ بخادم', [
            for (final unit in [
              BoxUnitCatalog.doctors,
              BoxUnitCatalog.patients,
              BoxUnitCatalog.hospital,
              BoxUnitCatalog.labs,
              BoxUnitCatalog.pharmacy,
              BoxUnitCatalog.radiology,
              BoxUnitCatalog.dental,
              BoxUnitCatalog.donations,
            ])
              _Tile(unit.titleAr, unit.icon, () => _openUnit(context, unit)),
            _Tile('مخطط الأسنان', Icons.tag_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DentalChartScreen()));
            }),
            _Tile('شبكة الدم', Icons.bloodtype_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BloodRequestScreen()));
            }),
            _Tile('الحجز والأكواد', Icons.qr_code_2, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BookingWorkspaceScreen()));
            }),
            _Tile('دليل الأطباء المحلي', Icons.medical_services_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DoctorDirectoryScreen()));
            }),
            _Tile('مخزون الصيدلية', Icons.local_pharmacy_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PharmacyStockScreen()));
            }),
            _Tile('طلبات المخبر', Icons.science_outlined, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CareOrderScreen.lab()),
              );
            }),
            _Tile('طلبات الأشعة', Icons.radar_outlined, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CareOrderScreen.imaging()),
              );
            }),
            _Tile('الكاميرا الذكية', Icons.camera_alt_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CameraNotesScreen()));
            }),
          ]),
          _section(context, '3 الحماية', [
            _Tile('حارس الجهاز والطاقة والمراقبة', Icons.shield_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProtectionWorkspaceScreen()));
            }),
            _Tile('محفظتي', Icons.account_balance_wallet_outlined, () {
              final id = profile?.profileId;
              if (id == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WalletScreen(profileId: id)),
              );
            }),
          ]),
          _section(context, '4 العالم', [
            _Tile('سحابة إحصاء شاشات تراسل', Icons.public_outlined, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WorldWorkspaceScreen()));
            }),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<_Tile> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LifexText(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...tiles.map((tile) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(tile.icon)),
                title: LifexText(tile.title),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: tile.onTap,
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openUnit(BuildContext context, BoxUnit unit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BoxUnitScreen(unit: unit)),
    );
  }
}

class _Tile {
  const _Tile(this.title, this.icon, this.onTap);
  final String title;
  final IconData icon;
  final VoidCallback onTap;
}
