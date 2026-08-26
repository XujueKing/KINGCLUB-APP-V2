import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mock_runtime.g.dart';

enum BootstrapOutcome { anonymous, authenticated, offline, fatal }

enum SmsRequestFailure { rateLimited, offline }

enum CodeVerificationOutcome { verified, invalid, expired, outcomeUnknown }

enum ReviewStatus { pending, changesRequired, approved, rejected }

class MockSmsRequestException implements Exception {
  const MockSmsRequestException(this.failure);

  final SmsRequestFailure failure;
}

class LoginFlowSnapshot {
  const LoginFlowSnapshot({
    required this.id,
    required this.maskedMobile,
    required this.expiresAt,
    required this.resendAt,
  });

  final String id;
  final String maskedMobile;
  final DateTime expiresAt;
  final DateTime resendAt;
}

class MockRuntime {
  final Map<String, LoginFlowSnapshot> _flows = {};
  final Set<String> _onboardingFlows = {};
  int _flowSequence = 0;
  int _onboardingSequence = 0;

  Future<BootstrapOutcome> bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return BootstrapOutcome.anonymous;
  }

  Future<LoginFlowSnapshot> requestSms(String mobile) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mobile.endsWith('001')) {
      throw const MockSmsRequestException(SmsRequestFailure.rateLimited);
    }
    if (mobile.endsWith('002')) {
      throw const MockSmsRequestException(SmsRequestFailure.offline);
    }
    final now = DateTime.now();
    final id = 'mock-flow-${++_flowSequence}';
    final flow = LoginFlowSnapshot(
      id: id,
      maskedMobile: '${mobile.substring(0, 3)}****${mobile.substring(7)}',
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAt: now.add(const Duration(seconds: 60)),
    );
    _flows[id] = flow;
    return flow;
  }

  LoginFlowSnapshot? flow(String id) => _flows[id];

  Future<CodeVerificationOutcome> verifyCode({
    required String flowId,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final flow = _flows[flowId];
    if (flow == null || DateTime.now().isAfter(flow.expiresAt)) {
      return CodeVerificationOutcome.expired;
    }
    return switch (code) {
      '888888' => CodeVerificationOutcome.verified,
      '222222' => CodeVerificationOutcome.outcomeUnknown,
      '333333' => CodeVerificationOutcome.expired,
      _ => CodeVerificationOutcome.invalid,
    };
  }

  void clearFlow(String id) => _flows.remove(id);

  String startOnboarding() {
    final id = 'mock-onboarding-${++_onboardingSequence}';
    _onboardingFlows.add(id);
    return id;
  }

  bool hasOnboardingFlow(String id) => _onboardingFlows.contains(id);

  Future<void> completeMockStep() =>
      Future<void>.delayed(const Duration(milliseconds: 650));

  void clearOnboarding(String id) => _onboardingFlows.remove(id);
}

@Riverpod(keepAlive: true)
MockRuntime mockRuntime(Ref ref) => MockRuntime();

@riverpod
Future<BootstrapOutcome> bootstrapOutcome(Ref ref) {
  return ref.watch(mockRuntimeProvider).bootstrap();
}
