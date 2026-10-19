import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_contract.dart';

/// حراسة معمارية — تمنع المسارات المحظورة من أن تُعرَّف كقدرات افتراضية.
void main() {
  const canon = LifexLioCanon();
  final registry = McpLiveToolRegistry();

  test('AI لا يلمس SQL مباشرة', () {
    expect(canon.aiMayTalkSqlDirectly, isFalse);
    expect(canon.aiDataPath, contains('REPOSITORY'));
    expect(canon.aiDataPath, isNot(contains('SQL_DIRECT')));
  });

  test('لا أداة افتراضية تلمس clinical أو تتحكم بجهاز طبي دون سياسة', () {
    for (final t in registry.all) {
      if (t.toolId == 'mcp.devices') {
        expect(t.mayControlDevice, isTrue);
        expect(t.approvalPolicy, McpApprovalPolicy.always);
      } else {
        expect(t.mayTouchClinical, isFalse);
      }
      expect(t.mayMutateMain, isFalse);
      expect(t.maySpendMoney, isFalse);
    }
  });

  test('merge/force_push ليست عمليات قراءة مسموحة افتراضياً كـ allow دون كتابة', () {
    final gh = registry.tool('mcp.github')!;
    expect(gh.writeOperations, contains('merge'));
    expect(gh.allowedOperations, isNot(contains('merge')));
    expect(gh.mayMutateMain, isFalse);
  });

  test('Clinical منفصل عن ذاكرة AI العامة', () {
    expect(canon.clinicalDataEntersGeneralAiMemory, isFalse);
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
  });

  test('المسار الإلزامي يمر بموافقة وصلاحية', () {
    expect(
      canon.aiDataPath,
      containsAll(['IDENTITY', 'AUTHORIZATION', 'CONSENT', 'PURPOSE', 'DATA_SCOPE']),
    );
  });
}
