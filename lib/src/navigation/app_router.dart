import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/auth_bootstrap_page.dart';
import '../features/auth/presentation/mobile_login_page.dart';
import '../features/auth/presentation/sms_verification_page.dart';
import '../features/auth/presentation/terms_consent_page.dart';
import '../features/club/presentation/aa_reservations_page.dart';
import '../features/club/presentation/vip_party_page.dart';
import '../features/onboarding/presentation/drink_event_preferences_page.dart';
import '../features/onboarding/presentation/membership_image_submission_page.dart';
import '../features/onboarding/presentation/membership_review_status_page.dart';
import '../features/onboarding/presentation/real_name_adult_verification_page.dart';
import '../features/onboarding/presentation/style_music_preferences_page.dart';
import '../features/scanner/presentation/safe_scanner_page.dart';
import '../features/shell/presentation/app_shell_page.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: const AuthBootstrapRoute().location,
    routes: $appRoutes,
  );
  ref.onDispose(router.dispose);
  return router;
}

@TypedGoRoute<AuthBootstrapRoute>(path: '/auth/bootstrap')
class AuthBootstrapRoute extends GoRouteData with $AuthBootstrapRoute {
  const AuthBootstrapRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AuthBootstrapPage(
      onAnonymous: () => const MobileLoginRoute().go(context),
      onAuthenticated: () => const AppShellRoute().go(context),
    );
  }
}

@TypedGoRoute<MobileLoginRoute>(path: '/auth/mobile')
class MobileLoginRoute extends GoRouteData with $MobileLoginRoute {
  const MobileLoginRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return MobileLoginPage(
      onFlowCreated: (flow) =>
          SmsCodeRoute(LoginFlowRouteArgs(flow.id)).go(context),
      onOpenTerms: () =>
          TermsConsentRoute(const ConsentRouteArgs(AgreementKind.terms))
              .push<void>(context),
      onOpenPrivacy: () =>
          TermsConsentRoute(const ConsentRouteArgs(AgreementKind.privacy))
              .push<void>(context),
    );
  }
}

class LoginFlowRouteArgs {
  const LoginFlowRouteArgs(this.flowId);

  final String flowId;
}

@TypedGoRoute<SmsCodeRoute>(path: '/auth/code')
class SmsCodeRoute extends GoRouteData with $SmsCodeRoute {
  const SmsCodeRoute(this.$extra);

  final LoginFlowRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SmsVerificationPage(
      flowId: $extra.flowId,
      onBack: () => const MobileLoginRoute().go(context),
      onVerified: (flowId) =>
          RealNameAdultVerificationRoute(OnboardingFlowRouteArgs(flowId))
              .go(context),
    );
  }
}

class ConsentRouteArgs {
  const ConsentRouteArgs(this.initialAgreement);

  final AgreementKind initialAgreement;
}

@TypedGoRoute<TermsConsentRoute>(path: '/auth/consent')
class TermsConsentRoute extends GoRouteData with $TermsConsentRoute {
  const TermsConsentRoute(this.$extra);

  final ConsentRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TermsConsentPage(
      initialAgreement: $extra.initialAgreement,
      onClose: () => context.pop(),
    );
  }
}

class OnboardingFlowRouteArgs {
  const OnboardingFlowRouteArgs(this.flowId);

  final String flowId;
}

@TypedGoRoute<RealNameAdultVerificationRoute>(path: '/onboarding/identity')
class RealNameAdultVerificationRoute extends GoRouteData
    with $RealNameAdultVerificationRoute {
  const RealNameAdultVerificationRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return RealNameAdultVerificationPage(
      flowId: $extra.flowId,
      onNext: () => MembershipImageSubmissionRoute($extra).go(context),
      onInvalidFlow: () => const MobileLoginRoute().go(context),
    );
  }
}

@TypedGoRoute<MembershipImageSubmissionRoute>(path: '/onboarding/images')
class MembershipImageSubmissionRoute extends GoRouteData
    with $MembershipImageSubmissionRoute {
  const MembershipImageSubmissionRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return MembershipImageSubmissionPage(
      flowId: $extra.flowId,
      onBack: () => RealNameAdultVerificationRoute($extra).go(context),
      onNext: () => StyleMusicPreferencesRoute($extra).go(context),
      onInvalidFlow: () => const MobileLoginRoute().go(context),
    );
  }
}

@TypedGoRoute<StyleMusicPreferencesRoute>(path: '/onboarding/style-music')
class StyleMusicPreferencesRoute extends GoRouteData
    with $StyleMusicPreferencesRoute {
  const StyleMusicPreferencesRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return StyleMusicPreferencesPage(
      flowId: $extra.flowId,
      onBack: () => MembershipImageSubmissionRoute($extra).go(context),
      onNext: () => DrinkEventPreferencesRoute($extra).go(context),
      onInvalidFlow: () => const MobileLoginRoute().go(context),
    );
  }
}

@TypedGoRoute<DrinkEventPreferencesRoute>(path: '/onboarding/drink-events')
class DrinkEventPreferencesRoute extends GoRouteData
    with $DrinkEventPreferencesRoute {
  const DrinkEventPreferencesRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return DrinkEventPreferencesPage(
      flowId: $extra.flowId,
      onBack: () => StyleMusicPreferencesRoute($extra).go(context),
      onSubmitted: () => MembershipReviewStatusRoute($extra).go(context),
      onInvalidFlow: () => const MobileLoginRoute().go(context),
    );
  }
}

@TypedGoRoute<MembershipReviewStatusRoute>(path: '/onboarding/review')
class MembershipReviewStatusRoute extends GoRouteData
    with $MembershipReviewStatusRoute {
  const MembershipReviewStatusRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return MembershipReviewStatusPage(
      flowId: $extra.flowId,
      onApproved: () => const AppShellRoute().go(context),
      onFixImages: () => MembershipImageSubmissionRoute($extra).go(context),
      onExit: () => const MobileLoginRoute().go(context),
      onInvalidFlow: () => const MobileLoginRoute().go(context),
    );
  }
}

@TypedGoRoute<AppShellRoute>(path: '/home')
class AppShellRoute extends GoRouteData with $AppShellRoute {
  const AppShellRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AppShellPage(
    onOpenTogether: () => const AaReservationsRoute().push<void>(context),
    onOpenParty: () => const VipPartyRoute().push<void>(context),
    onOpenScanner: (shellContext, originIndex) =>
        SafeScannerRoute(ScannerRouteArgs(originIndex))
            .push<SafeScanDestination>(shellContext),
  );
}

@TypedGoRoute<ContentFeedRoute>(path: '/discover')
class ContentFeedRoute extends GoRouteData with $ContentFeedRoute {
  const ContentFeedRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AppShellPage(
    initialIndex: 2,
    onOpenTogether: () => const AaReservationsRoute().push<void>(context),
    onOpenParty: () => const VipPartyRoute().push<void>(context),
    onOpenScanner: (shellContext, originIndex) =>
        SafeScannerRoute(ScannerRouteArgs(originIndex))
            .push<SafeScanDestination>(shellContext),
  );
}

@TypedGoRoute<ContactsRoute>(path: '/messages/contacts')
class ContactsRoute extends GoRouteData with $ContactsRoute {
  const ContactsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AppShellPage(
    initialIndex: 1,
    onOpenTogether: () => const AaReservationsRoute().push<void>(context),
    onOpenParty: () => const VipPartyRoute().push<void>(context),
    onOpenScanner: (shellContext, originIndex) =>
        SafeScannerRoute(ScannerRouteArgs(originIndex))
            .push<SafeScanDestination>(shellContext),
  );
}

class ScannerRouteArgs {
  const ScannerRouteArgs(this.originIndex);

  final int originIndex;
}

@TypedGoRoute<SafeScannerRoute>(path: '/scan')
class SafeScannerRoute extends GoRouteData with $SafeScannerRoute {
  const SafeScannerRoute(this.$extra);

  final ScannerRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => SafeScannerPage(
    onClose: () => context.pop(),
    onResolved: (destination) => context.pop(destination),
  );
}

@TypedGoRoute<AaReservationsRoute>(path: '/club/aa')
class AaReservationsRoute extends GoRouteData with $AaReservationsRoute {
  const AaReservationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AaReservationsPage(onBack: () => context.pop());
}

@TypedGoRoute<VipPartyRoute>(path: '/club/parties')
class VipPartyRoute extends GoRouteData with $VipPartyRoute {
  const VipPartyRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VipPartyPage(onBack: () => context.pop());
}
