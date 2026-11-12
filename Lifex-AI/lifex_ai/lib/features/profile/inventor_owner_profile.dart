/// ملف شخص للمخترع. صلاحية المالك تُفتح من البريد أو الهاتف، لا من الاسم.
library lifex_ai.features.profile.inventor_owner_profile;

import '../../core/app_constants.dart';
import '../../core/attribution/project_attribution.dart';
import 'health_profile.dart';

class InventorOwnerProfileDraft {
  const InventorOwnerProfileDraft({
    required this.profile,
    required this.email,
    required this.phone,
  });

  static const profileId = 'local-inventor-owner';

  final HealthProfile profile;
  final String email;
  final String phone;

  /// هوية معروفة فقط: الاسم والبريد والهاتف. بلا عمر ولا فصيلة ولا تشخيص.
  factory InventorOwnerProfileDraft.official() {
    return InventorOwnerProfileDraft(
      email: AppConstants.ownerEmail,
      phone: AppConstants.ownerPhoneNumber,
      profile: HealthProfile(
        profileId: profileId,
        fullName: ProjectAttribution.inventorOwnerAr,
        biologicalSex: BiologicalSex.unspecified,
        bloodType: BloodType.unknown,
        questionnaireData: {
          'personFileKind': 'inventor_owner',
          'roleNoteAr':
              'ملف شخص للمخترع. دور المالك التشغيلي يُفتح إذا طابق البريد أو الهاتف الهوية المعتمدة. الاسم وحده لا يفتح صلاحية أدمن.',
        },
      ),
    );
  }
}
