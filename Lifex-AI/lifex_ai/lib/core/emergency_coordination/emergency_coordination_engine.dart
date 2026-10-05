/// 112 Emergency Coordination — wraps EMS 70; signal ≠ treatment.
library lifex_ai.core.emergency_coordination.engine;

class LifexEmergencyCoordinationEngine {
  bool get isPlatformModule112 => true;
  bool get replacesEms70 => false;
  bool get emergencySignalEqualsDiagnosis => false;
  bool get activationEqualsMedicalTreatment => false;
  bool get emergencyEqualsFullDatabase => false;
  bool get talksSqlDirectly => false;
}
