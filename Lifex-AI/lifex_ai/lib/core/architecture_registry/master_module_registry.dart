/// =============================================================
/// Lifex-AI — السجل الموحد للوحدات وملكية البيانات 1.0
/// ONE OWNER. Duplicates 76/77/92–100 are historical aliases.
/// =============================================================
library lifex_ai.core.architecture_registry.master_module_registry;

enum ModuleKind {
  canonical,
  duplicate,
  submodule,
  service,
  adapter,
  projection,
  infrastructure,
}

class ModuleRegistryEntry {
  const ModuleRegistryEntry({
    required this.id,
    required this.universalName,
    required this.folder,
    required this.engine,
    required this.owns,
    this.kind = ModuleKind.canonical,
    this.mergeInto,
  });

  final int id;
  final String universalName;
  final String folder;
  final String engine;
  final String owns;
  final ModuleKind kind;
  final int? mergeInto;
}

class LifexMasterModuleRegistry {
  bool get oneResponsibilityOneOwner => true;
  bool get oneSourceOfTruthManyConsumers => true;
  bool get noDirectCrossModuleDatabaseAccess => true;
  bool get noDuplicateMasterData => true;
  bool get noUncontrolledAiAccess => true;
  bool get noAutomaticAuthorityTransfer => true;
  bool get treats140AsIndependentModules => false;
  bool get sourceOfTruthEqualsProjection => false;
  bool get sourceOfTruthEqualsCache => false;
  bool get sourceOfTruthEqualsEvent => false;
  bool get sourceOfTruthEqualsAudit => false;
  bool get sourceOfTruthEqualsAnalytics => false;
  bool get sourceOfTruthEqualsAiContext => false;

  /// Historical IDs that must not spawn new folders/SoT.
  static const duplicates = <int, int>{
    76: 41, // health search → universal search
    77: 42, // health analytics → universal analytics
    92: 41,
    93: 42,
    94: 78, // quality
    95: 79, // insurance
    96: 80, // donations
    97: 81, // environmental
    98: 82, // sports
    99: 83, // toxicology
    100: 84, // care coordination
  };

  /// Gap-close / prior platform numbers → this registry id (aliases only).
  static const historicalAliases = <int, int>{
    56: 38, // communication
    57: 39, // notifications
    58: 40, // documents
    59: 41, // search
    61: 42, // analytics
    62: 43, // observability
    63: 49, // pharmacy
    64: 50, // doctors
    65: 48, // HIE
    66: 44, // scheduling
    68: 52, // laboratories
    69: 53, // hospitals
    70: 54, // EMS
  };

  static const entityOwner = <String, String>{
    'Person': 'identity_trust',
    'Account': 'identity_trust',
    'Identity': 'identity_trust',
    'Organization': 'identity_trust',
    'Patient': 'personal_family_health',
    'Alias': 'personal_family_health',
    'Family': 'personal_family_health',
    'PatientCondition': 'personal_family_health',
    'PatientMedication': 'personal_family_health',
    'DiseaseDefinition': 'health_knowledge',
    'MedicationDefinition': 'health_knowledge',
    'Observation': 'health_data',
    'Hospital': 'global_hospitals',
    'Laboratory': 'global_laboratories',
    'LaboratoryResult': 'global_laboratories',
    'Pharmacy': 'global_pharmacy',
    'MedicalDeviceDefinition': 'medical_devices',
    'Connection': 'connectivity',
    'DeviceCommand': 'device_control_center',
    'LocationFix': 'global_location',
    'HealthGeography': 'geospatial_health',
    'FinancialTransaction': 'financial',
    'FraudRisk': 'financial_security',
    'Subscription': 'subscriptions',
    'MarketplaceListing': 'marketplace',
    'Consent': 'consent',
    'AuditEvent': 'audit',
    'AiRequest': 'universal_ai_gateway',
    'AiModel': 'ai_model_lifecycle',
    'AiMemory': 'ai_memory',
    'AiAnalysis': 'ai_intelligence',
    'AiAlert': 'ai_intelligence',
    'ClinicalDiagnosis': 'clinical_records',
    'ClinicalNote': 'clinical_records',
    'ClinicalAssessment': 'clinical_records',
    'Encounter': 'clinical_records',
    'Procedure': 'clinical_records',
    'ImagingStudy': 'medical_imaging',
    'DicomObject': 'medical_imaging',
    'ImagingReport': 'medical_imaging',
    'Document': 'documents',
    'BackupCatalog': 'backup_archive',
    'EventTransport': 'event_bus',
  };

  static const forbiddenDualOwners = <String, List<String>>{
    'Patient': ['global_hospitals', 'global_doctors', 'global_pharmacy'],
    'DiseaseDefinition': ['global_hospitals'],
    'MedicationDefinition': ['personal_family_health'],
    'LocationFix': ['emergency_medical_services'],
    'AiModel': ['universal_ai_gateway', 'medical_ai_validation'],
    'DocumentBinary': ['global_hospitals'],
    'FinancialTransaction': ['global_pharmacy'],
    'Consent': ['global_doctors', 'global_hospitals'],
    'ClinicalDiagnosis': ['ai_intelligence', 'personal_family_health'],
    'AiAnalysis': ['universal_ai_gateway', 'clinical_records'],
    'ImagingStudy': ['personal_family_health', 'ai_intelligence'],
  };

  static const accessGates = [
    'identity',
    'authentication',
    'authorization',
    'consent',
    'purpose',
    'data_scope',
    'policy',
    'audit',
  ];

  bool isDuplicate(int id) => duplicates.containsKey(id);

  int resolve(int id) => duplicates[id] ?? id;

  int resolveHistorical(int oldId) =>
      historicalAliases[oldId] ?? resolve(oldId);

  String? ownerOf(String entity) => entityOwner[entity];

  bool mayClaimOwnership(String entity, String moduleFolder) {
    final owner = entityOwner[entity];
    if (owner == null) return false;
    if (owner == moduleFolder) return true;
    final forbidden = forbiddenDualOwners[entity];
    if (forbidden != null && forbidden.contains(moduleFolder)) return false;
    return false;
  }

  int get historicalIdCount => 140;
  int get duplicateCount => duplicates.length;
  int get independentModuleCount => historicalIdCount - duplicateCount;

  String namingPattern(String nameSnake) =>
      'Universal … / lib/core/$nameSnake/ / Lifex…Engine';
}
