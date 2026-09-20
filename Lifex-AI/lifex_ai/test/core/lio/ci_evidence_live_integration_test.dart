import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_mcp_bridge.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_model.dart';
import 'package:lifex_ai/core/lio/ci_evidence/ci_evidence_verification.dart';
import 'package:lifex_ai/core/lio/ci_evidence/github_actions_run_snapshot.dart';
import 'package:lifex_ai/core/lio/claim_verifier.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lifex_intelligence_fabric.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/mcp_live/mcp_tool_adapters.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';

void main() {
  late CiEvidenceVerificationService verification;

  setUp(() {
    verification = CiEvidenceVerificationService(
      reader: GithubActionsRunSnapshot.reader(),
    );
  });

  test(
    'Real GH Actions run 35534653852 + commit 31c8d15 → VERIFIED + Audit',
    () async {
      final r = await verification.verifyApkClaim(
        claim: const LioClaim(
          id: 'pr5-debug-apk',
          statementAr: 'commit 31c8d15 produced successful debug APK on Actions',
          madeByAgentId: 'agent.critic_verifier',
        ),
        expected: GithubActionsRunSnapshot.debugApkExpectation(),
        actor: 'ghazi',
        agent: 'agent.critic_verifier',
        workflowRunId: GithubActionsRunSnapshot.workflowRunId,
      );

      expect(r.verificationStatus, CiVerificationStatus.verified);
      expect(r.verificationStatus.wireName, 'VERIFIED');
      expect(r.commitSha, GithubActionsRunSnapshot.commitSha);
      expect(r.workflowRunId, GithubActionsRunSnapshot.workflowRunId);
      expect(r.verifiedChecks, contains('commitSha'));
      expect(r.verifiedChecks, contains('artifact'));
      expect(r.verifiedChecks, contains('artifactDigest'));
      expect(r.integrityEvidence, 'matched');
      expect(r.provenance['notAgentReport'], isTrue);
      expect(verification.auditEvents, isNotEmpty);
      expect(
        verification.auditEvents.last.verificationStatus,
        'VERIFIED',
      );
      expect(verification.allowsWrite, isFalse);
    },
  );

  test('Failed workflow wireName → VERIFICATION_FAILED', () async {
    final reader = GithubActionsRunSnapshot.reader();
    reader.put(
      'fail',
      const CiEvidence(
        repository: GithubActionsRunSnapshot.repository,
        workflowRunId: 'fail',
        conclusion: 'failure',
        branch: GithubActionsRunSnapshot.branch,
        commitSha: GithubActionsRunSnapshot.commitSha,
        analyzeResult: CiCheckResult.failure,
        testResult: CiCheckResult.failure,
        apkBuildResult: CiCheckResult.failure,
        artifact: CiArtifactEvidence(
          name: GithubActionsRunSnapshot.debugArtifactName,
          digestOrSha256: GithubActionsRunSnapshot.debugArtifactDigest,
        ),
      ),
    );
    final v = CiEvidenceVerificationService(reader: reader);
    final r = await v.verifyApkClaim(
      claim: const LioClaim(
        id: 'f',
        statementAr: 'apk ok',
        madeByAgentId: 'agent.critic_verifier',
      ),
      expected: GithubActionsRunSnapshot.debugApkExpectation(),
      actor: 'ghazi',
      agent: 'agent.critic_verifier',
      workflowRunId: 'fail',
    );
    expect(r.verificationStatus, CiVerificationStatus.failed);
    expect(r.verificationStatus.wireName, 'VERIFICATION_FAILED');
    expect(v.auditEvents.last.verificationStatus, 'VERIFICATION_FAILED');
  });

  test('Test11 Knowledge Engine لا يتجاوز MCP Gateway للـ CI', () async {
    final fabric = LifexIntelligenceFabric(
      knowledgeEngine: LifexKnowledgeEngine(
        corpus: InMemoryKnowledgeCorpus(),
      ),
    );
    final live = fabric.attachLiveMcpGateway();
    live.adapters.replace(
      'mcp.github',
      GitHubMcpToolAdapter(evidenceReader: GithubActionsRunSnapshot.reader()),
    );
    await live.connect();

    // KE retrieve لا يلمس GitHub write ولا يتجاوز Gateway.
    expect(fabric.knowledgeEngine!.safety.mayTouchClinicalDatabase, isFalse);
    expect(fabric.knowledgeEngine!.safety.llmIsSourceOfTruth, isFalse);

    final bridge = CiEvidenceMcpBridge(
      gateway: live,
      verification: verification,
    );
    final r = await bridge.verifyApkClaimViaGateway(
      claim: const LioClaim(
        id: 'via-mcp',
        statementAr: 'debug apk via gateway',
        madeByAgentId: 'agent.code',
      ),
      expected: GithubActionsRunSnapshot.debugApkExpectation(),
      actor: 'ghazi',
      agent: 'agent.code',
      workflowRunId: GithubActionsRunSnapshot.workflowRunId,
    );
    expect(r.verificationStatus, CiVerificationStatus.verified);
    expect(live.auditEvents.any((e) => e.toolId == 'mcp.github'), isTrue);
  });

  test('Test12 Evidence بلا provenance مرفوض في Knowledge Engine', () async {
    final corpus = InMemoryKnowledgeCorpus([
      KnowledgeRecord(
        id: 'bare',
        title: 'bare',
        body: 'no cite',
        provenance: LioSourceProvenance(
          sourceId: 'bare',
          sourceType: 'llm_hallucination',
          authority: LioSourceAuthority.unverified,
          retrievedAt: DateTime.now(),
        ),
      ),
    ]);
    final ke = LifexKnowledgeEngine(corpus: corpus);
    final pack = await ke.retrieve(
      const KnowledgeQuery(
        text: 'bare',
        channels: [RetrievalChannel.keywordBm25],
        requireProvenance: true,
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.missingProvenance);
    expect(pack.items, isEmpty);
  });

  test('Test13 تعارض الأدلة يُحفظ ولا يتحول إلى VERIFIED إجماع', () async {
    final corpus = InMemoryKnowledgeCorpus([
      KnowledgeRecord(
        id: 'a',
        title: 'A',
        body: 'topicz yes',
        terms: const ['topicz'],
        provenance: LioSourceProvenance(
          sourceId: 'a',
          sourceType: 'journal',
          authority: LioSourceAuthority.peerReviewed,
          retrievedAt: DateTime(2026, 9, 20),
          document: 'doc-a',
          url: 'https://example.org/a',
          evidenceLevel: 0.8,
          confidence: 0.7,
        ),
      ),
      KnowledgeRecord(
        id: 'b',
        title: 'B',
        body: 'topicz no',
        terms: const ['topicz'],
        provenance: LioSourceProvenance(
          sourceId: 'b',
          sourceType: 'blog',
          authority: LioSourceAuthority.news,
          retrievedAt: DateTime(2026, 9, 20),
          document: 'doc-b',
          url: 'https://example.org/b',
          evidenceLevel: 0.3,
          confidence: 0.3,
        ),
      ),
    ]);
    final ke = LifexKnowledgeEngine(corpus: corpus);
    final pack = await ke.retrieve(
      const KnowledgeQuery(
        text: 'topicz',
        channels: [RetrievalChannel.keywordBm25],
      ),
    );
    expect(pack.status, KnowledgeRetrievalStatus.conflict);
    expect(pack.conflicts, isNotEmpty);
    expect(pack.hasConflict, isTrue);
    expect(pack.llmIsSourceOfTruth, isFalse);
  });

  test('Test14 LLM لا يصبح Source of Truth', () async {
    final fabric = LifexIntelligenceFabric(
      knowledgeEngine: LifexKnowledgeEngine(
        corpus: InMemoryKnowledgeCorpus(),
      ),
    );
    expect(fabric.knowledgeEngine!.safety.llmIsSourceOfTruth, isFalse);
    expect(fabric.canon.memoryIsNotSourceOfTruth, isTrue);
    expect(
      fabric.bootstrapReport()['llmIsSourceOfTruth'],
      isFalse,
    );
    final pack = await fabric.knowledgeEngine!.retrieve(
      const KnowledgeQuery(text: 'anything'),
    );
    expect(pack.llmIsSourceOfTruth, isFalse);
    expect(pack.mayDiagnose, isFalse);
    expect(pack.mayPrescribe, isFalse);
  });
}
