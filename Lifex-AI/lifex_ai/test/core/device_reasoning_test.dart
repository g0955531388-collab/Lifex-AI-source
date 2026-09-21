/// =============================================================
/// Lifex-AI — اختبار
/// الملف: device_reasoning_test.dart
/// =============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/device_reasoning/device_reasoning_engine.dart';
import 'package:lifex_ai/core/device_reasoning/reasoning_types.dart';

void main() {
  test('hypothesis stays unverified; missing info is not allow or deny', () {
    final e = DeviceReasoningEngine();
    final h = e.createHypothesis(
      const Hypothesis(
        id: 'h1',
        statement: 'BLE communication may be unavailable',
        confidence: 0.73,
        verified: true,
      ),
    );
    expect(h.verified, isFalse);
    final d = e.evaluate(
      const ReasoningContext(objective: 'unknown device'),
    );
    expect(d.status, DecisionStatus.requiresInformation);
    expect(d.explanation.reasons, contains('missing_information_not_allow_or_deny'));
  });

  test('control not verified is blocked; reasoning does not execute', () {
    final e = DeviceReasoningEngine();
    e.addObservation(
      Observation(
        id: 'o1',
        sourceId: 'ble',
        timestamp: DateTime.now(),
        subjectId: 'ecg-01',
        property: 'connectionState',
        value: 'disconnected',
        confidence: 1,
      ),
    );
    final d = e.evaluate(
      const ReasoningContext(
        objective: 'control ECG-01',
        subjectId: 'ecg-01',
        controlVerified: false,
        authorized: true,
      ),
    );
    expect(d.status, DecisionStatus.blocked);
    expect(d.explanation.reasons, contains('CONTROL BLOCKED'));
    expect(d.executedByReasoning, isFalse);
    expect(d.clinicalInterpretation, isFalse);
  });

  test('reconnect candidate ready for execution only with policy and auth', () {
    final e = DeviceReasoningEngine();
    e.addObservation(
      Observation(
        id: 'o2',
        sourceId: 'ble',
        timestamp: DateTime.now(),
        subjectId: 'ecg-01',
        property: 'connectionState',
        value: 'disconnected',
      ),
    );
    e.addFact(
      Fact(
        id: 'f1',
        subjectId: 'ecg-01',
        predicate: 'HAS_CAPABILITY',
        value: 'READ_ECG',
        observedAt: DateTime.now(),
        sourceId: 'registry',
      ),
    );
    final d = e.evaluate(
      const ReasoningContext(
        objective: 'restore ECG stream',
        subjectId: 'ecg-01',
        mode: ReasoningMode.executionReady,
        authorized: true,
        supportsReconnect: true,
        readVerified: true,
        policyPrefer: 'reconnect',
      ),
    );
    expect(d.status, DecisionStatus.readyForExecution);
    expect(d.selectedOption!.id, 'reconnect');
    expect(d.executedByReasoning, isFalse);
    expect(e.createPlan(d).steps.length, 10);
    expect(e.createPlan(d).steps.first.action, 'verify_identity');
  });

  test('resource conflict and unknown risk is not safe; what-if does not execute', () {
    final e = DeviceReasoningEngine();
    e.addObservation(
      Observation(
        id: 'o3',
        sourceId: 'hub',
        timestamp: DateTime.now(),
        subjectId: 'cam',
        property: 'connectionState',
        value: 'connected',
      ),
    );
    final blocked = e.evaluate(
      const ReasoningContext(
        objective: 'use camera',
        subjectId: 'cam',
        resourceClaimants: ['blind_vision', 'video_call'],
        readVerified: true,
      ),
    );
    expect(blocked.status, DecisionStatus.blocked);
    final risk = e.assessRisk(
      const DeviceDecision(
        id: 'x',
        objective: 'send command',
        status: DecisionStatus.requiresInformation,
      ),
    );
    expect(risk.unknownMeansSafe, isFalse);
    final w = e.simulate(
      const WhatIfScenario(
        id: 's1',
        changes: {'connectionState': 'disconnected'},
      ),
    );
    expect(w.executed, isFalse);
    expect(w.projected, contains('stream_lost'));
  });
}
