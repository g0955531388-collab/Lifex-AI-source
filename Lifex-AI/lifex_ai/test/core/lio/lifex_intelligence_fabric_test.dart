import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/claim_verifier.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';
import 'package:lifex_ai/core/lio/lio_orchestrator.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';
import 'package:lifex_ai/core/lio/unified_memory.dart';

void main() {
  const canon = LifexLioCanon();
  late LifexIntelligenceFabric fabric;

  setUp(() {
    fabric = LifexIntelligenceFabric();
  });

  test('LIO هو الطبقة العليا — النماذج قابلة للتبديل', () {
    expect(canon.orchestratorShortName, 'LIO');
    expect(canon.modelsAreSpecializedToolsNotSoleBrain, isTrue);
    expect(canon.providersAreSwappable, isTrue);
    expect(canon.packageName, 'lifex_ai');
  });

  test('AI لا يلمس SQL — المسار الإلزامي كامل', () {
    expect(canon.aiMayTalkSqlDirectly, isFalse);
    expect(canon.aiDataPath.first, 'AI');
    expect(canon.aiDataPath.last, 'RESULT');
    expect(canon.aiDataPath, contains('CONSENT'));
    expect(canon.aiDataPath, contains('REPOSITORY'));
    expect(fabric.enforcesAiDataPath, isTrue);
  });

  test('Memory ≠ Source of Truth وClinical معزول', () {
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
    expect(canon.clinicalDataEntersGeneralAiMemory, isFalse);

    final mem = fabric.memory;
    expect(
      mem.put(
        LioMemoryRecord(
          id: 'c1',
          kind: LioMemoryKind.clinicalIsolated,
          summaryAr: 'سجل سريري',
          createdAt: DateTime.now(),
        ),
      ),
      isNull,
    );
    expect(
      mem.put(
        LioMemoryRecord(
          id: 'p1',
          kind: LioMemoryKind.project,
          summaryAr: 'قرار معماري LIO',
          createdAt: DateTime.now(),
        ),
      ),
      isNull,
    );
    final pack = mem.buildGeneralAiContext();
    expect(pack.any((r) => r.kind == LioMemoryKind.clinicalIsolated), isFalse);
    expect(pack.any((r) => r.kind == LioMemoryKind.project), isTrue);
    expect(fabric.isolatesClinicalMemory, isTrue);
  });

  test('المهمة السريرية تُحظر في مسار AI العام', () {
    final plan = fabric.lio.plan(
      const LioMissionRequest(
        id: 'm1',
        goalAr: 'اقرأ ملف المريض من SQL',
        touchesClinical: true,
      ),
    );
    expect(plan.status, LioMissionStatus.blocked);
    expect(plan.blockedReasonAr, contains('Consent'));
  });

  test('ResearchAgent ممنوع من الصرف والوصف وتعديل المرضى', () {
    final deny = fabric.agents.denyAction(
      LioAgentRole.research,
      'prescribe',
    );
    expect(deny, isNotNull);
    expect(
      fabric.agents.denyAction(LioAgentRole.research, 'search'),
      isNull,
    );
  });

  test('MCP: Cursor يحتاج موافقة بشرية', () {
    final denied = fabric.lio.authorizeTool(
      role: LioAgentRole.code,
      toolId: 'mcp.cursor',
      humanApproved: false,
    );
    expect(denied, contains('موافقة'));
    expect(
      fabric.lio.authorizeTool(
        role: LioAgentRole.code,
        toolId: 'mcp.cursor',
        humanApproved: true,
      ),
      isNull,
    );
  });

  test('Verifier يرفض ادّعاء الإصلاح بلا أدلة', () {
    final report = fabric.lio.verifyClaim(
      claim: const LioClaim(
        id: 'c-fix',
        statementAr: 'تم إصلاح المشروع',
        madeByAgentId: 'agent.code',
        risk: LioRiskLevel.medium,
      ),
      evidence: const [],
    );
    expect(report.verdict, LioVerificationVerdict.fail);
  });

  test('Verifier يقبل analyze+test ثم يطلب بشرياً عند high', () {
    final report = fabric.lio.verifyClaim(
      claim: const LioClaim(
        id: 'c-apk',
        statementAr: 'البناء نجح',
        madeByAgentId: 'agent.code',
        risk: LioRiskLevel.high,
      ),
      evidence: const [
        LioEvidence(
          kind: LioEvidenceKind.analyzer,
          passed: true,
          detailAr: 'analyze ok',
        ),
        LioEvidence(
          kind: LioEvidenceKind.unitTest,
          passed: true,
          detailAr: 'tests ok',
        ),
      ],
    );
    expect(report.verdict, LioVerificationVerdict.needsHuman);
    expect(report.requiresHuman, isTrue);
  });

  test('مصدر WHO أثقل من مدونة مجهولة', () {
    const eng = LifexSourceReliabilityEngine();
    final who = LioSourceProvenance(
      sourceId: 'who',
      sourceType: 'standard',
      authority: LioSourceAuthority.officialStandard,
      retrievedAt: DateTime(2026, 1, 1),
      url: 'https://www.who.int/example',
    );
    final blog = LioSourceProvenance(
      sourceId: 'blog',
      sourceType: 'blog',
      authority: LioSourceAuthority.unknownBlog,
      retrievedAt: DateTime(2023, 1, 1),
      url: 'https://example.com/blog',
    );
    expect(eng.weightOf(who.authority), greaterThan(eng.weightOf(blog.authority)));
    expect(eng.acceptAsEvidence(who), isTrue);
    expect(eng.prefer(who, blog), same(who));
  });

  test('الموجة الأولى مكتملة العقود الستة', () {
    expect(canon.firstExecutableSlice, containsAll([
      'LIO',
      'MCP_GATEWAY',
      'UNIFIED_MEMORY',
      'SOURCE_PROVENANCE',
      'AGENT_REGISTRY',
      'VERIFIER',
    ]));
    final r = fabric.bootstrapReport();
    expect(r['mcpToolCount'], greaterThanOrEqualTo(4));
    expect(r['agentProfileCount'], greaterThanOrEqualTo(3));
  });

  test('FHIR محوّل وليس النموذج الأساسي', () {
    expect(canon.fhirIsAdapterNotCanonicalModel, isTrue);
  });
}
