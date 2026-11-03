/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: health_modules_screen.dart
/// المسار: lib/screens/health_modules_screen.dart
/// الوصف: سجلات محلية للمخبر والدم والتبرعات والمرأة والأسنان والتأهيل.
/// الربط المؤسسي يحتاج خادماً ولا يُزيف هنا.
/// =============================================================
library lifex_ai.screens.health_modules_screen;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../features/network_box/box_unit_catalog.dart';
import 'blood_request_screen.dart';
import 'box_unit_screen.dart';
import 'camera_notes_screen.dart';
import 'care_order_screen.dart';
import 'doctor_directory_screen.dart';
import 'layered_lens_studio_screen.dart';
import 'medical_reference_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'thumbnail_manage_screen.dart';
import '../widgets/lifex_text.dart';

class HealthModulesScreen extends StatelessWidget {
  const HealthModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = [
      BoxUnitCatalog.labs,
      BoxUnitCatalog.donations,
      BoxUnitCatalog.women,
      BoxUnitCatalog.dental,
      BoxUnitCatalog.education,
      BoxUnitCatalog.chronicPlans,
    ];
    return Scaffold(
      appBar: AppBar(title: const LifexText('الوحدات الصحية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const LifexText('مركز الوحدات المرتبطة بالملف الصحي',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const LifexText(
              'كل وحدة تفتح أقسامها الفرعية من السيناريو: ملف عام، علاقة، حجز، سجلات. الربط المؤسسي يحتاج خادماً.'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.bloodtype_outlined)),
              title: const LifexText('شبكة الدم'),
              subtitle: const LifexText('طلبات للموافقين على هذا الجهاز'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BloodRequestScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
              title: const LifexText('الأطباء'),
              subtitle: const LifexText('اختصاص ثم الأقرب بمسافة تدخلها أنت'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DoctorDirectoryScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.local_pharmacy_outlined)),
              title: const LifexText('الصيدلية'),
              subtitle: const LifexText('مخزون محلي ثم أقرب صنف. لا بيع دم'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PharmacyStockScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.science_outlined)),
              title: const LifexText('طلبات المخبر'),
              subtitle: const LifexText('طلب ثم نتيجة للطبيب. ليست قراءة آلية'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CareOrderScreen.lab()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.radar_outlined)),
              title: const LifexText('طلبات الأشعة'),
              subtitle: const LifexText('أرشيف على نفس الخيط. التفسير للطبيب'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CareOrderScreen.imaging()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.camera_alt_outlined)),
              title: const LifexText('الكاميرا الذكية'),
              subtitle: const LifexText('أوراق بموافقة. OCR فارغ حتى محرك معتمد'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CameraNotesScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.filter_none_outlined)),
              title: const LifexText('تقريب العدسة'),
              subtitle: const LifexText('معاينة حية وزوم العتاد. ليست تشخيص جلد'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LayeredLensStudioScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.image_outlined)),
              title: LifexText(lifexUi('إدارة الصورة المصغّرة', 'Profile thumbnail')),
              subtitle: const LifexText('إدارة الصورة المصغّرة'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ThumbnailManageScreen(),
                ),
              ),
            ),
          ),
          ...modules.map((unit) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(unit.icon)),
                  title: LifexText(unit.titleAr),
                  subtitle: LifexText(unit.subtitleAr),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BoxUnitScreen(unit: unit),
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          const LifexText('مراجع من نسخة Android Studio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.visibility_outlined)),
              title: const LifexText('مرجع العلامات البصرية'),
              subtitle: const LifexText('SmartCameraSigns — معاني علامات الوجه والجلد'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MedicalReferenceScreen(
                    kind: MedicalReferenceKind.cameraSigns,
                  ),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
              title: const LifexText('موسوعة الحالات'),
              subtitle: const LifexText('حالات وأعراض مرجعية للبحث والتنظيم'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MedicalReferenceScreen(
                    kind: MedicalReferenceKind.conditions,
                  ),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.straighten_outlined)),
              title: const LifexText('معايير الطول والوزن'),
              subtitle: const LifexText('مرجع عمري عام وليس تشخيص نمو'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MedicalReferenceScreen(
                    kind: MedicalReferenceKind.growth,
                  ),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.local_pharmacy_outlined)),
              title: const LifexText('دليل الأدوية المرجعي'),
              subtitle: const LifexText('أسماء وتصنيفات من أرشيف الاستوديو'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MedicalReferenceScreen(
                    kind: MedicalReferenceKind.drugs,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: LifexText(
                  'تنبيه: السجلات هنا لتنظيم معلوماتك ولا تشخّص المرض ولا تستبدل الطبيب. الربط مع مؤسسات خارجية يتطلب حسابات وصلاحيات وخادمًا فعليًا.'),
            ),
          ),
        ],
      ),
    );
  }
}
