/// =============================================================
/// Lifex-AI — لوحة تحكم الأدمن العالمية
/// المخترع/المالك التشغيلي يمنح أدمن ومشرف. الإسناد في ProjectAttribution.
/// =============================================================
library lifex_ai.screens.admin_dashboard_screen;

import 'package:flutter/material.dart';

import '../core/admin/admin_manager.dart';
import '../core/admin/admin_permissions.dart';
import '../core/admin/owner_identity_policy.dart';
import '../core/attribution/project_attribution.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.currentUserLifexId});

  final String currentUserLifexId;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _admin = GlobalAdminManager.instance;
  final _targetIdController = TextEditingController();
  String? _statusMessageAr;
  StaffEngagement _engagement = StaffEngagement.volunteer;

  @override
  void dispose() {
    _targetIdController.dispose();
    super.dispose();
  }

  void _showStatus(String messageAr) {
    setState(() => _statusMessageAr = messageAr);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageAr)));
  }

  void _grant(GlobalAdminRole role) {
    final targetId = _targetIdController.text.trim();
    if (targetId.isEmpty) {
      _showStatus('أدخل معرّف Lifex-ID للمستخدم أولاً.');
      return;
    }
    final result = _admin.grantRole(
      granterLifexId: widget.currentUserLifexId,
      targetLifexId: targetId,
      role: role,
      engagement: _engagement,
    );
    _showStatus(result.messageAr);
    setState(() {});
  }

  void _revoke() {
    final targetId = _targetIdController.text.trim();
    if (targetId.isEmpty) {
      _showStatus('أدخل معرّف Lifex-ID للمستخدم أولاً.');
      return;
    }
    final result = _admin.revokeRole(
      granterLifexId: widget.currentUserLifexId,
      targetLifexId: targetId,
    );
    _showStatus(result.messageAr);
    setState(() {});
  }

  void _toggleEvent(String key, bool value) {
    final result = _admin.setEventToggle(
      actorLifexId: widget.currentUserLifexId,
      eventKey: key,
      enabled: value,
    );
    _showStatus(result.messageAr);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final myRole = _admin.roleOf(widget.currentUserLifexId);
    final myPerms = _admin.permissionsOf(widget.currentUserLifexId);
    final canGrantAdmin = _admin.hasPermission(
      widget.currentUserLifexId,
      GlobalAdminPermission.grantAdminRole,
    );
    final canGrantModerator = _admin.hasPermission(
      widget.currentUserLifexId,
      GlobalAdminPermission.grantModeratorRole,
    );
    final canGrantEmployee = _admin.hasPermission(
      widget.currentUserLifexId,
      GlobalAdminPermission.grantStaffRole,
    );
    final canManageToggles = _admin.hasPermission(
      widget.currentUserLifexId,
      GlobalAdminPermission.manageSystemEventToggles,
    );
    final staff = _admin.listStaffRoles();
    const policy = OwnerIdentityPolicy();

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    ProjectAttribution.officialStatementShortAr,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    myRole == GlobalAdminRole.owner
                        ? 'أنت المالك التشغيلي. الصيانة ومفاتيح التشغيل وتعيين '
                            'مدير وموظف ومشرف، مأجورين أو متطوعين. '
                            'هذا لا يفتح ملفات المرضى.'
                        : 'دورك: ${_roleLabelAr(myRole)}',
                  ),
                  Text(
                    'Lifex-ID: ${widget.currentUserLifexId}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('دورك الحالي'),
              subtitle: Text(_roleLabelAr(myRole)),
            ),
          ),
          const SizedBox(height: 8),
          Text('صلاحياتك (${myPerms.length})',
              style: Theme.of(context).textTheme.titleMedium),
          ...myPerms.map(
            (p) => ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle_outline, size: 20),
              title: Text(_permissionLabelAr(p)),
            ),
          ),
          if (myRole != GlobalAdminRole.owner) ...[
            const SizedBox(height: 8),
            Text(
              policy.activationHintAr(),
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
          const SizedBox(height: 16),
          if (canGrantAdmin || canGrantModerator || canGrantEmployee) ...[
            Text('تعيين الطاقم',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              canGrantAdmin
                  ? 'كمالك: تعيّن مديراً أو موظفاً أو مشرفاً، مأجوراً أو متطوعاً، '
                      'وتسحب أدوارهم. دور المالك لا يُمنح يدوياً.'
                  : 'كمدير: يمكنك تعيين مشرفين فقط. المدير والموظف للمالك.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SegmentedButton<StaffEngagement>(
              segments: const [
                ButtonSegment(
                  value: StaffEngagement.paid,
                  label: Text('مأجور'),
                ),
                ButtonSegment(
                  value: StaffEngagement.volunteer,
                  label: Text('متطوع'),
                ),
              ],
              selected: {_engagement},
              onSelectionChanged: (selected) {
                setState(() => _engagement = selected.first);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(
                labelText: 'معرّف Lifex-ID للمستخدم المستهدف',
                border: OutlineInputBorder(),
                hintText: 'مثال: LFX-482913',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canGrantAdmin)
                  FilledButton.icon(
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('تعيين مدير'),
                    onPressed: () => _grant(GlobalAdminRole.admin),
                  ),
                if (canGrantEmployee)
                  FilledButton.icon(
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('تعيين موظف'),
                    onPressed: () => _grant(GlobalAdminRole.employee),
                  ),
                if (canGrantModerator)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('تعيين مشرف'),
                    onPressed: () => _grant(GlobalAdminRole.moderator),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove_moderator_outlined),
                  label: const Text('سحب الدور'),
                  onPressed: _revoke,
                ),
              ],
            ),
            const Divider(height: 32),
          ],
          Text('الطاقم الإداري الحالي',
              style: Theme.of(context).textTheme.titleMedium),
          if (staff.isEmpty)
            const ListTile(
              title: Text('لا أدوار إدارية أخرى على هذا الجهاز بعد.'),
            )
          else
            ...staff.entries.map(
              (e) => ListTile(
                leading: Icon(
                  e.value == GlobalAdminRole.owner
                      ? Icons.star
                      : Icons.person_outline,
                ),
                title: Text(e.key),
                subtitle: Text(_staffLine(e.key, e.value)),
              ),
            ),
          const Divider(height: 32),
          if (canManageToggles) ...[
            Text('مفاتيح الأحداث الدقيقة',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'تفعيل أو تعطيل ميزات على مستوى النظام كاملاً دون تحديث التطبيق.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ..._admin.allEventToggles.entries.where((entry) {
              if (entry.key != GlobalAdminManager.remoteCameraEventKey) {
                return true;
              }
              return _admin.hasPermission(
                widget.currentUserLifexId,
                GlobalAdminPermission.manageRemoteCameraMonitoring,
              );
            }).map(
              (entry) => SwitchListTile(
                title: Text(_eventLabelAr(entry.key)),
                value: entry.value,
                onChanged: (value) => _toggleEvent(entry.key, value),
              ),
            ),
          ],
          if (_statusMessageAr != null) ...[
            const SizedBox(height: 16),
            Text(_statusMessageAr!, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  String _roleLabelAr(GlobalAdminRole role) {
    switch (role) {
      case GlobalAdminRole.owner:
        return 'مالك تشغيلي / مخترع مفعَّل';
      case GlobalAdminRole.admin:
        return 'مدير';
      case GlobalAdminRole.employee:
        return 'موظف';
      case GlobalAdminRole.moderator:
        return 'مشرف';
      case GlobalAdminRole.none:
        return 'مستخدم عادي';
    }
  }

  String _staffLine(String lifexId, GlobalAdminRole role) {
    final engagement = _admin.engagementOf(lifexId);
    final roleAr = _roleLabelAr(role);
    if (engagement == null) return roleAr;
    final pay = engagement == StaffEngagement.paid ? 'مأجور' : 'متطوع';
    return '$roleAr · $pay';
  }

  String _permissionLabelAr(GlobalAdminPermission p) {
    switch (p) {
      case GlobalAdminPermission.grantModeratorRole:
        return 'تعيين / سحب مشرفين';
      case GlobalAdminPermission.grantAdminRole:
        return 'تعيين / سحب المدراء';
      case GlobalAdminPermission.grantStaffRole:
        return 'تعيين / سحب الموظفين';
      case GlobalAdminPermission.manageSystemEventToggles:
        return 'مفاتيح أحداث النظام';
      case GlobalAdminPermission.manageUsers:
        return 'إدارة المستخدمين';
      case GlobalAdminPermission.moderateContent:
        return 'إشراف المحتوى';
      case GlobalAdminPermission.viewSectorStatistics:
        return 'إحصاءات القطاع';
      case GlobalAdminPermission.manageBilling:
        return 'إدارة الفوترة على مستوى المنصة';
      case GlobalAdminPermission.manageEmergencyPolicy:
        return 'سياسات الطوارئ العامة';
      case GlobalAdminPermission.manageRemoteCameraMonitoring:
        return 'مراقبة الكاميرا عن بُعد';
    }
  }

  String _eventLabelAr(String key) {
    const labels = {
      'blood_network_flash_alerts_enabled': 'تنبيهات شبكة الدم الفورية',
      'emergency_silent_light_mode_enabled': 'وضع الطوارئ الصامت (ضوء بدل صوت)',
      'ai_gateway_enabled': 'بوابة الذكاء الاصطناعي الموحّدة',
      'remote_health_camera_monitoring_enabled': 'المراقبة الصحية عن بُعد بالكاميرا',
    };
    return labels[key] ?? key;
  }
}
