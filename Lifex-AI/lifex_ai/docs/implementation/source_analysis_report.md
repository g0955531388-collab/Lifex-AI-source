# Source analysis report

Roots: lib, test. Built packages are not analyzed.
Command: `dart run tool/lifex_source_report.dart`

| Tier | Count |
|---|---:|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 0 |
| LOW | 40 |

| Category | Count |
|---|---:|
| error | 0 |
| performance | 34 |
| dead-code | 0 |
| null-safety | 0 |
| other | 6 |

| Tier | Category | Code | File | Line | Message |
|---|---|---|---|---:|---|
| LOW | other | PREFER_INITIALIZING_FORMALS | lib/core/health_data/encrypted_health_observation_store.dart | 24 | Use an initializing formal to assign a parameter to a field. |
| LOW | other | PREFER_INITIALIZING_FORMALS | lib/features/donations/donation_application_service.dart | 56 | Use an initializing formal to assign a parameter to a field. |
| LOW | other | DANGLING_LIBRARY_DOC_COMMENTS | lib/features/voice/voice_command_engine.dart | 1 | Dangling library doc comment. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/admin_dashboard_screen.dart | 196 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/ai_hub_screen.dart | 122 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/ai_hub_screen.dart | 333 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/book_library_screen.dart | 68 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/child_rights_book_screen.dart | 96 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/disability_fixation_screen.dart | 104 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/disability_fixation_screen.dart | 112 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/disability_fixation_screen.dart | 127 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/disability_fixation_screen.dart | 135 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/family_management_screen.dart | 393 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/family_management_screen.dart | 408 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/family_management_screen.dart | 422 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/family_management_screen.dart | 455 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/identity_workspace_screen.dart | 246 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/medications_screen.dart | 212 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/partner_sign_in_screen.dart | 83 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/protection_workspace_screen.dart | 145 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/system_search_screen.dart | 287 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/system_search_screen.dart | 288 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/voice_control_screen.dart | 1852 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/voice_control_screen.dart | 1957 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/voice_control_screen.dart | 1977 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/voice_control_screen.dart | 1997 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/wallet_screen.dart | 153 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/wallet_screen.dart | 369 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/wallet_screen.dart | 378 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | lib/screens/youth_guide_screen.dart | 96 | Use 'const' with the constructor to improve performance. |
| LOW | other | DANGLING_LIBRARY_DOC_COMMENTS | test/core/device_semantic_graph_test.dart | 1 | Dangling library doc comment. |
| LOW | other | DANGLING_LIBRARY_DOC_COMMENTS | test/core/device_service_registry_test.dart | 1 | Dangling library doc comment. |
| LOW | other | UNNECESSARY_BRACE_IN_STRING_INTERPS | test/data/biometric_dictionary_test.dart | 26 | Unnecessary braces in a string interpolation. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/care_cycle_desk_test.dart | 221 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/medication_alarm_test.dart | 18 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/medication_alarm_test.dart | 62 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/nearby_care_finder_test.dart | 13 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/nearby_care_finder_test.dart | 41 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/nearby_care_finder_test.dart | 58 | Use 'const' with the constructor to improve performance. |
| LOW | performance | PREFER_CONST_CONSTRUCTORS | test/features/unit_slot_board_test.dart | 63 | Use 'const' with the constructor to improve performance. |
