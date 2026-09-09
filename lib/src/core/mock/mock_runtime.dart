import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mock_runtime.g.dart';

enum BootstrapOutcome { anonymous, authenticated, offline, fatal }

enum SmsRequestFailure { rateLimited, offline }

enum CodeVerificationOutcome { verified, invalid, expired, outcomeUnknown }

enum ReviewStatus {
  pending,
  appearanceReview,
  changesRequired,
  approved,
  rejected,
}

enum PhotoIdentityOutcome {
  verifiedAdult,
  identityMismatch,
  ageRestricted,
  retryableFailure,
  outcomeUnknown,
}

enum AppearanceAssessmentOutcome {
  qualified,
  manualReview,
  changesRequired,
  outcomeUnknown,
}

enum RegistrationPhotoSlot { selfie, portrait, outfit }

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

class MockOnboardingSnapshot {
  const MockOnboardingSnapshot({
    required this.id,
    this.identityVerified = false,
    this.photoSlots = const <RegistrationPhotoSlot>{},
    this.reviewStatus = ReviewStatus.pending,
    this.reviewUpdatedAt,
  });

  final String id;
  final bool identityVerified;
  final Set<RegistrationPhotoSlot> photoSlots;
  final ReviewStatus reviewStatus;
  final DateTime? reviewUpdatedAt;

  bool get hasBothMemberPhotos =>
      photoSlots.contains(RegistrationPhotoSlot.portrait) &&
      photoSlots.contains(RegistrationPhotoSlot.outfit);

  MockOnboardingSnapshot copyWith({
    bool? identityVerified,
    Set<RegistrationPhotoSlot>? photoSlots,
    ReviewStatus? reviewStatus,
    DateTime? reviewUpdatedAt,
  }) {
    return MockOnboardingSnapshot(
      id: id,
      identityVerified: identityVerified ?? this.identityVerified,
      photoSlots: Set<RegistrationPhotoSlot>.unmodifiable(
        photoSlots ?? this.photoSlots,
      ),
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewUpdatedAt: reviewUpdatedAt ?? this.reviewUpdatedAt,
    );
  }
}

class MockRuntime {
  final Map<String, LoginFlowSnapshot> _flows = {};
  final Map<String, String> _flowMobiles = {};
  final Map<String, MockOnboardingSnapshot> _onboardingFlows = {};
  final Set<String> _approvedMemberMobiles = {};
  int _flowSequence = 0;
  int _onboardingSequence = 0;
  PhotoIdentityOutcome _nextIdentityOutcome =
      PhotoIdentityOutcome.verifiedAdult;
  AppearanceAssessmentOutcome _nextAppearanceOutcome =
      AppearanceAssessmentOutcome.qualified;

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
    _flowMobiles[id] = mobile;
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

  void clearFlow(String id) {
    _flows.remove(id);
    _flowMobiles.remove(id);
  }

  String startOnboarding({String? loginFlowId}) {
    final id = 'mock-onboarding-${++_onboardingSequence}';
    final isExistingApprovedMember =
        loginFlowId != null &&
        _approvedMemberMobiles.contains(_flowMobiles[loginFlowId]);
    _onboardingFlows[id] = MockOnboardingSnapshot(
      id: id,
      identityVerified: isExistingApprovedMember,
      reviewStatus: isExistingApprovedMember
          ? ReviewStatus.approved
          : ReviewStatus.pending,
      reviewUpdatedAt: isExistingApprovedMember ? DateTime.now() : null,
    );
    return id;
  }

  void seedApprovedMember(String mobile) {
    _approvedMemberMobiles.add(mobile);
  }

  bool hasOnboardingFlow(String id) => _onboardingFlows.containsKey(id);

  MockOnboardingSnapshot? onboardingSnapshot(String id) => _onboardingFlows[id];

  void setNextIdentityOutcome(PhotoIdentityOutcome outcome) {
    _nextIdentityOutcome = outcome;
  }

  Future<PhotoIdentityOutcome> submitPhotoIdentity({
    required String flowId,
    required String name,
    required String identityNumber,
  }) async {
    await completeMockStep();
    final current = _onboardingFlows[flowId];
    if (current == null) return PhotoIdentityOutcome.outcomeUnknown;
    final outcome = _nextIdentityOutcome;
    _nextIdentityOutcome = PhotoIdentityOutcome.verifiedAdult;
    if (outcome == PhotoIdentityOutcome.verifiedAdult) {
      _onboardingFlows[flowId] = current.copyWith(
        identityVerified: true,
        photoSlots: {...current.photoSlots, RegistrationPhotoSlot.selfie},
      );
    }
    return outcome;
  }

  Future<bool> stageRegistrationPhoto({
    required String flowId,
    required RegistrationPhotoSlot slot,
  }) async {
    await completeMockStep();
    final current = _onboardingFlows[flowId];
    if (current == null) return false;
    _onboardingFlows[flowId] = current.copyWith(
      photoSlots: {...current.photoSlots, slot},
      reviewStatus: ReviewStatus.pending,
      reviewUpdatedAt: DateTime.now(),
    );
    return true;
  }

  void setNextAppearanceOutcome(AppearanceAssessmentOutcome outcome) {
    _nextAppearanceOutcome = outcome;
  }

  Future<AppearanceAssessmentOutcome> submitAppearanceAssessment(
    String flowId,
  ) async {
    await completeMockStep();
    final current = _onboardingFlows[flowId];
    if (current == null ||
        !current.identityVerified ||
        !current.hasBothMemberPhotos) {
      if (current != null) {
        _onboardingFlows[flowId] = current.copyWith(
          reviewStatus: ReviewStatus.changesRequired,
          reviewUpdatedAt: DateTime.now(),
        );
      }
      return AppearanceAssessmentOutcome.changesRequired;
    }
    final outcome = _nextAppearanceOutcome;
    _nextAppearanceOutcome = AppearanceAssessmentOutcome.qualified;
    final status = switch (outcome) {
      AppearanceAssessmentOutcome.qualified => ReviewStatus.approved,
      AppearanceAssessmentOutcome.manualReview => ReviewStatus.appearanceReview,
      AppearanceAssessmentOutcome.changesRequired =>
        ReviewStatus.changesRequired,
      AppearanceAssessmentOutcome.outcomeUnknown => ReviewStatus.pending,
    };
    _onboardingFlows[flowId] = current.copyWith(
      reviewStatus: status,
      reviewUpdatedAt: DateTime.now(),
    );
    return outcome;
  }

  void setReviewFixture(String flowId, ReviewStatus status) {
    final current = _onboardingFlows[flowId];
    if (current == null) return;
    _onboardingFlows[flowId] = current.copyWith(
      reviewStatus: status,
      reviewUpdatedAt: DateTime.now(),
    );
  }

  Future<MockOnboardingSnapshot?> refreshOnboarding(String flowId) async {
    await completeMockStep();
    return _onboardingFlows[flowId];
  }

  bool canEnterApp(String flowId) =>
      _onboardingFlows[flowId]?.reviewStatus == ReviewStatus.approved;

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
