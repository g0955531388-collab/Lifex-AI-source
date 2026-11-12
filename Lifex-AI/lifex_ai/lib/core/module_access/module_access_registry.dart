/// =============================================================
/// Lifex-AI — سجل وصول الوحدات (Module Access ≠ Data Access)
/// الملف: module_access_registry.dart
/// فتح الوحدة ≠ صلاحية بيانات ≠ اشتراك مدفوع.
/// =============================================================
library lifex_ai.core.module_access.module_access_registry;

import '../trial_manager.dart';

/// حالة الوحدة عند الفتح — ليست قفلاً أمنياً شاملاً.
enum ModuleAccessState {
  available,
  empty,
  requiresAuth,
  requiresPermission,
  requiresConsent,
  requiresVerification,
  requiresExternalSetup,
  offline,
  temporarilyUnavailable,
}

class ModuleDescriptor {
  const ModuleDescriptor({
    required this.moduleId,
    required this.nameAr,
    required this.category,
    this.routeHint = '',
    this.coreDiscoverable = true,
    this.requiresActiveProfileForData = true,
  });

  final String moduleId;
  final String nameAr;
  final String category;
  final String routeHint;
  final bool coreDiscoverable;

  /// يحتاج ملفاً نشطاً لعرض/تعديل البيانات — لا لحجب فتح الشاشة.
  final bool requiresActiveProfileForData;
}

class ModuleAccessDecision {
  const ModuleAccessDecision({
    required this.moduleId,
    required this.canNavigate,
    required this.state,
    required this.messageAr,
    this.entitlementBlocked = false,
  });

  final String moduleId;
  final bool canNavigate;
  final ModuleAccessState state;
  final String messageAr;

  /// true فقط لميزة مدفوعة داخل الوحدة — لا يمنع فتح الوحدة.
  final bool entitlementBlocked;
}

/// سجل الوحدات الأساسية القابلة للاكتشاف والتنقل.
class ModuleAccessRegistry {
  const ModuleAccessRegistry();

  static const modules = <ModuleDescriptor>[
    ModuleDescriptor(moduleId: 'health', nameAr: 'الصحة', category: 'health'),
    ModuleDescriptor(moduleId: 'patients', nameAr: 'المرضى', category: 'health'),
    ModuleDescriptor(moduleId: 'family', nameAr: 'العائلة', category: 'health'),
    ModuleDescriptor(moduleId: 'doctors', nameAr: 'الأطباء', category: 'care'),
    ModuleDescriptor(moduleId: 'hospitals', nameAr: 'المستشفيات', category: 'care'),
    ModuleDescriptor(moduleId: 'labs', nameAr: 'المختبرات', category: 'care'),
    ModuleDescriptor(moduleId: 'pharmacy', nameAr: 'الصيدليات', category: 'care'),
    ModuleDescriptor(moduleId: 'blood', nameAr: 'الدم', category: 'care'),
    ModuleDescriptor(moduleId: 'dentistry', nameAr: 'الأسنان', category: 'care'),
    ModuleDescriptor(moduleId: 'imaging', nameAr: 'التصوير', category: 'care'),
    ModuleDescriptor(moduleId: 'appointments', nameAr: 'المواعيد', category: 'scheduling'),
    ModuleDescriptor(moduleId: 'emergency', nameAr: 'الطوارئ', category: 'safety'),
    ModuleDescriptor(moduleId: 'devices', nameAr: 'الأجهزة', category: 'devices'),
    ModuleDescriptor(moduleId: 'location', nameAr: 'الموقع', category: 'geo'),
    ModuleDescriptor(moduleId: 'documents', nameAr: 'الوثائق', category: 'docs'),
    ModuleDescriptor(moduleId: 'search', nameAr: 'البحث', category: 'platform'),
    ModuleDescriptor(moduleId: 'messages', nameAr: 'التواصل', category: 'comms'),
    ModuleDescriptor(moduleId: 'notifications', nameAr: 'الإشعارات', category: 'comms'),
    ModuleDescriptor(moduleId: 'education', nameAr: 'التعليم', category: 'edu'),
    ModuleDescriptor(moduleId: 'ai', nameAr: 'الذكاء', category: 'ai'),
    ModuleDescriptor(moduleId: 'accessibility', nameAr: 'إمكانية الوصول', category: 'a11y'),
    ModuleDescriptor(moduleId: 'camera', nameAr: 'الكاميرا', category: 'a11y'),
    ModuleDescriptor(moduleId: 'voice', nameAr: 'الصوت', category: 'a11y'),
    ModuleDescriptor(moduleId: 'wallet', nameAr: 'المحفظة', category: 'finance'),
    ModuleDescriptor(moduleId: 'settings', nameAr: 'الإعدادات', category: 'platform'),
    ModuleDescriptor(moduleId: 'admin', nameAr: 'الإدارة', category: 'admin'),
    ModuleDescriptor(moduleId: 'profile', nameAr: 'الملف الصحي', category: 'health'),
    ModuleDescriptor(moduleId: 'medications', nameAr: 'الأدوية', category: 'health'),
    ModuleDescriptor(moduleId: 'power', nameAr: 'الطاقة', category: 'platform'),
  ];

  ModuleDescriptor? byId(String id) {
    for (final m in modules) {
      if (m.moduleId == id) return m;
    }
    return null;
  }

  /// تقييم فتح الوحدة — لا يستخدم الاشتراك لحجب الوحدة الأساسية.
  ModuleAccessDecision evaluate({
    required String moduleId,
    required TrialPhase phase,
    required bool feeExempt,
    required bool hasActiveProfile,
    required bool authenticated,
  }) {
    const policy = SessionAccessPolicy();
    if (!policy.canOpenUnit(moduleId, phase: phase, feeExempt: feeExempt)) {
      return ModuleAccessDecision(
        moduleId: moduleId,
        canNavigate: false,
        state: ModuleAccessState.requiresExternalSetup,
        messageAr: phase == TrialPhase.giftFrozen
            ? 'REQUIRES_EXTERNAL_SETUP — أكمل تخصيص نسخة الإهداء من الإعدادات.'
            : 'الوحدة غير متاحة حالياً.',
      );
    }

    if (!authenticated) {
      return ModuleAccessDecision(
        moduleId: moduleId,
        canNavigate: true,
        state: ModuleAccessState.requiresAuth,
        messageAr: 'الوحدة مفتوحة. سجّل الدخول لاستخدام البيانات.',
      );
    }

    final desc = byId(moduleId);
    if (desc != null &&
        desc.requiresActiveProfileForData &&
        !hasActiveProfile) {
      return ModuleAccessDecision(
        moduleId: moduleId,
        canNavigate: true,
        state: ModuleAccessState.empty,
        messageAr:
            'EMPTY — الوحدة متاحة. لا يوجد ملف صحي نشط بعد. أنشئ ملفاً لعرض البيانات.',
      );
    }

    return ModuleAccessDecision(
      moduleId: moduleId,
      canNavigate: true,
      state: ModuleAccessState.available,
      messageAr: 'AVAILABLE — يمكن فتح الوحدة.',
    );
  }

  /// كل الوحدات الأساسية تُقيَّم — للاختبار والواجهة.
  List<ModuleAccessDecision> evaluateAll({
    required TrialPhase phase,
    required bool feeExempt,
    required bool hasActiveProfile,
    required bool authenticated,
  }) {
    return modules
        .map(
          (m) => evaluate(
            moduleId: m.moduleId,
            phase: phase,
            feeExempt: feeExempt,
            hasActiveProfile: hasActiveProfile,
            authenticated: authenticated,
          ),
        )
        .toList();
  }
}
