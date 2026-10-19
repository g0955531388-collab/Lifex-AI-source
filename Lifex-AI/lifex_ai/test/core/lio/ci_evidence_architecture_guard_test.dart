import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_verification.dart';
import 'package:lifex_ai/core/lio/ci_evidence/github_ci_evidence_reader.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_contract.dart';

void main() {
  const canon = LifexLioCanon();
  final registry = McpLiveToolRegistry();
  final verification = CiEvidenceVerificationService();

  test('Verifier → GitHub Write محظور', () {
    expect(verification.allowsWrite, isFalse);
    expect(verification.readerAllowsWrite, isFalse);
    expect(const UnavailableGitHubCiEvidenceReader().allowsWrite, isFalse);
    final gh = registry.tool('mcp.github')!;
    expect(gh.mayMutateMain, isFalse);
    expect(gh.writeOperations, isNotEmpty);
  });

  test('Verifier → SQL محظور في القانون', () {
    expect(canon.aiMayTalkSqlDirectly, isFalse);
  });

  test('Verifier → Clinical غير مسموح في ذاكرة AI', () {
    expect(canon.clinicalDataEntersGeneralAiMemory, isFalse);
  });

  test('Verifier → Medical Device / Main mutation غير مفعّلين', () {
    expect(registry.tool('mcp.devices')!.mayControlDevice, isTrue);
    expect(
      registry.tool('mcp.devices')!.approvalPolicy,
      McpApprovalPolicy.always,
    );
    expect(registry.tool('mcp.github')!.mayMutateMain, isFalse);
  });
}
