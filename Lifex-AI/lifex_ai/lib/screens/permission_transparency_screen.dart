/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: permission_transparency_screen.dart
/// المسار: lib/screens/permission_transparency_screen.dart
/// الوصف: شاشة إدارة الأذونات الحساسة وفق إطار الشفافية الثلاثي:
/// شرح ← موافقة/رفض ← إيقاف لاحق من داخل التطبيق.
/// =============================================================
library lifex_ai.screens.permission_transparency_screen;

import 'package:flutter/material.dart';

import '../core/permission_transparency.dart';
import '../widgets/lifex_text.dart';

class PermissionTransparencyScreen extends StatefulWidget {
  const PermissionTransparencyScreen({super.key});

  @override
  State<PermissionTransparencyScreen> createState() =>
      _PermissionTransparencyScreenState();
}

class _PermissionTransparencyScreenState
    extends State<PermissionTransparencyScreen> {
  final _manager = PermissionTransparencyManager.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LifexText('شفافية الصلاحيات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const LifexText(
            'لا يُفعَّل أي إذن حسّاس تلقائياً. لكل إذن شرح صحي، موافقة '
            'صريحة، ويمكن إيقافه لاحقاً من هنا.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          for (final permission in LifexSensitivePermission.values)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LifexText(
                      PermissionTransparencyManager.titlesAr[permission]!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    LifexText(
                      PermissionTransparencyManager.explanationsAr[permission]!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: LifexText(
                        _manager.isGranted(permission) ? 'مسموح' : 'مرفوض',
                      ),
                      subtitle: LifexText(
                        _manager.recordOf(permission) == null
                            ? 'لم يُتخذ قرار بعد'
                            : 'آخر قرار: ${_manager.recordOf(permission)!.decidedAt.toIso8601String().substring(0, 16)}',
                      ),
                      value: _manager.isGranted(permission),
                      onChanged: (granted) {
                        setState(() {
                          _manager.decide(
                            permission: permission,
                            granted: granted,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
