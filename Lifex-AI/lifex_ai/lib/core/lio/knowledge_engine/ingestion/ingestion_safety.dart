/// =============================================================
/// Lifex-AI — سلامة الاستيعاب (حدود المجال)
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.ingestion.ingestion_safety;

import 'ingestion_contracts.dart';

class IngestionSafetyPolicy {
  const IngestionSafetyPolicy();

  bool get llmIsSourceOfTruth => false;
  bool get mayIngestClinicalRecords => false;
  bool get mayIngestPrescriptions => false;
  bool get mayIngestPrivateHealth => false;
  bool get mayIngestDeviceCommands => false;
  bool get mayIngestSecrets => false;
  bool get mayBypassProvenance => false;
  bool get mayBypassValidation => false;
  bool get mayWriteUiDirectToRepository => false;
  bool get mayTouchClinicalDatabase => false;

  /// كشف محتوى محظور — حتمي وبسيط لهذه المرحلة.
  IngestionRejectReason? detectForbidden(RawKnowledgeDocument doc) {
    final blob =
        '${doc.title}\n${doc.body}\n${doc.metadata.values.join('\n')}'
            .toLowerCase();

    if (_matches(blob, const [
      'patient_id',
      'mrn:',
      'clinical_record',
      'phi:',
      'ehr_export',
    ])) {
      return IngestionRejectReason.forbiddenClinical;
    }
    if (_matches(blob, const [
      'prescription:',
      'rx_order',
      'prescribe_now',
    ])) {
      return IngestionRejectReason.forbiddenPrescription;
    }
    if (_matches(blob, const [
      'private_health',
      'ssn:',
      'national_id:',
    ])) {
      return IngestionRejectReason.forbiddenPrivateHealth;
    }
    if (_matches(blob, const [
      'device_command',
      'ble_write',
      'pump_bolus',
    ])) {
      return IngestionRejectReason.forbiddenDeviceCommand;
    }
    if (_matches(blob, const [
      'api_token',
      'bearer ',
      'password=',
      'private_key',
      '-----begin',
    ])) {
      return IngestionRejectReason.forbiddenSecrets;
    }
    return null;
  }

  bool _matches(String blob, List<String> needles) =>
      needles.any(blob.contains);
}
