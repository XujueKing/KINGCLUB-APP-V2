import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/data/auth_repository_provider.dart';
import '../core/session/secure_session_store.dart';

import '../features/auth/presentation/auth_bootstrap_page.dart';
import '../features/auth/presentation/legacy_welcome_page.dart';
import '../features/auth/presentation/welcome_video_background.dart';
import '../features/auth/presentation/mobile_login_page.dart';
import '../features/auth/presentation/sms_verification_page.dart';
import '../features/auth/presentation/terms_consent_page.dart';
import '../features/club/presentation/aa_reservations_page.dart';
import '../features/club/presentation/aa_positioning_card_page.dart';
import '../features/club/presentation/admission_ticket_page.dart';
import '../features/club/presentation/vip_party_page.dart';
import '../features/club/presentation/vip_party_create_page.dart';
import '../features/club/presentation/vip_party_management_page.dart';
import '../features/commerce/presentation/order_detail_page.dart';
import '../features/commerce/data/fake_commerce_repository.dart';
import '../features/commerce/presentation/order_center_page.dart';
import '../features/commerce/presentation/payment_result_page.dart';
import '../features/commerce/presentation/scan_ordering_cart_page.dart';
import '../features/commerce/presentation/scan_order_confirmation_page.dart';
import '../features/contacts/presentation/blacklist_page.dart';
import '../features/contacts/presentation/friend_remark_page.dart';
import '../features/contacts/presentation/friendship_pages.dart';
import '../features/contacts/presentation/relationship_permissions_page.dart';
import '../features/contacts/presentation/send_friend_request_page.dart';
import '../features/contacts/presentation/user_profile_page.dart';
import '../features/membership_wallet/presentation/asset_ledger_page.dart';
import '../features/profile_settings/presentation/edit_profile_page.dart';
import '../features/profile_settings/data/profile_cover_store.dart';
import '../features/profile_settings/presentation/about_legal_page.dart';
import '../features/profile_settings/presentation/account_deletion_page.dart';
import '../features/profile_settings/presentation/payment_security_page.dart';
import '../features/profile_settings/presentation/personal_qr_page.dart';
import '../features/profile_settings/presentation/settings_page.dart';
import '../features/onboarding/presentation/drink_event_preferences_page.dart';
import '../features/onboarding/presentation/membership_image_submission_page.dart';
import '../features/onboarding/presentation/membership_review_status_page.dart';
import '../features/onboarding/presentation/real_name_adult_verification_page.dart';
import '../features/onboarding/presentation/real_membership_status_page.dart';
import '../features/onboarding/presentation/style_music_preferences_page.dart';
import '../features/scanner/presentation/safe_scanner_page.dart';
import '../features/shell/presentation/app_shell_page.dart';

part 'app_router.g.dart';

FakeCommerceRepository _commerce(BuildContext context) =>
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(fakeCommerceRepositoryProvider);

Future<void> _clearCommerceAndLogin(BuildContext context) async {
  _commerce(context).clear();
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(authenticatedMemberProvider.notifier).clear();
  await SecureSessionStore().clearSession();
  if (!context.mounted) return;
  const MobileLoginRoute().go(context);
}

void _continueRealRegistration(BuildContext context) {
  final member = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(authenticatedMemberProvider);
  const args = OnboardingFlowRouteArgs('real-registration');
  if (member == null) {
    const AuthBootstrapRoute().go(context);
  } else if (member.canEnterApp) {
    const AppShellRoute().go(context);
  } else if (member.needsIdentity) {
    const RealNameAdultVerificationRoute(args).go(context);
  } else if (member.needsImages) {
    const MembershipImageSubmissionRoute(args).go(context);
  } else {
    const MembershipReviewStatusRoute(args).go(context);
  }
}

Page<void> _authFlowPage({
  required GoRouterState state,
  required Widget child,
}) {
  return MaterialPage<void>(key: state.pageKey, child: child);
}

Page<void> _horizontalEntryPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: child,
      );
    },
    child: child,
  );
}

Page<void> _bottomUpPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            ),
        child: child,
      );
    },
    child: child,
  );
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  const previewLocation = String.fromEnvironment(
    'KINGCLUB_INITIAL_LOCATION',
    defaultValue: '/auth/bootstrap',
  );
  final router = GoRouter(
    initialLocation: previewLocation,
    routes: $appRoutes,
    observers: [welcomeMediaRouteObserver],
    redirect: (context, state) {
      final realMode = ref.read(authRepositoryProvider) is RealAuthRepository;
      final member = ref.read(authenticatedMemberProvider);
      if (realMode &&
          member != null &&
          (member.canEnterApp || member.needsImages) &&
          {
            '/auth/mobile',
            '/auth/welcome',
            '/onboarding/identity',
          }.contains(state.uri.path)) {
        return '/auth/bootstrap';
      }
      if (realMode &&
          state.uri.path == '/home' &&
          ref.read(authenticatedMemberProvider)?.canEnterApp != true) {
        return '/auth/bootstrap';
      }
      return null;
    },
  );
  ref.onDispose(router.dispose);
  return router;
}

@TypedGoRoute<AuthBootstrapRoute>(path: '/auth/bootstrap')
class AuthBootstrapRoute extends GoRouteData with $AuthBootstrapRoute {
  const AuthBootstrapRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return _ControlledRouteBackScope(
      onBack: () {},
      child: AuthBootstrapPage(
        onAnonymous: () => const LegacyWelcomeRoute().go(context),
        onAuthenticated: () {
          if (ProviderScope.containerOf(
            context,
            listen: false,
          ).read(authRepositoryProvider) is RealAuthRepository) {
            _continueRealRegistration(context);
          } else {
            const AppShellRoute().go(context);
          }
        },
      ),
    );
  }
}

@TypedGoRoute<LegacyWelcomeRoute>(path: '/auth/welcome')
class LegacyWelcomeRoute extends GoRouteData with $LegacyWelcomeRoute {
  const LegacyWelcomeRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: SystemNavigator.pop,
        child: LegacyWelcomePage(
          onNext: () => const MobileLoginRoute().push<void>(context),
          onOpenTerms: () =>
              TermsConsentRoute(const ConsentRouteArgs(AgreementKind.terms))
                  .push<void>(context),
          onOpenPrivacy: () =>
              TermsConsentRoute(const ConsentRouteArgs(AgreementKind.privacy))
                  .push<void>(context),
        ),
      ),
    );
  }
}

@TypedGoRoute<MobileLoginRoute>(path: '/auth/mobile')
class MobileLoginRoute extends GoRouteData with $MobileLoginRoute {
  const MobileLoginRoute();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    void back() => context.canPop()
        ? context.pop()
        : const LegacyWelcomeRoute().go(context);
    return _horizontalEntryPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: back,
        child: MobileLoginPage(
          onBack: back,
          onRegistrationStatus: () => _continueRealRegistration(context),
          onAuthenticatedMember: () => const AppShellRoute().go(context),
          onVerified: (flowId) =>
              RealNameAdultVerificationRoute(OnboardingFlowRouteArgs(flowId))
                  .push<void>(context),
        ),
      ),
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
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    void back() =>
        context.canPop() ? context.pop() : const MobileLoginRoute().go(context);
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: back,
        child: SmsVerificationPage(
          flowId: $extra.flowId,
          onBack: back,
          onAuthenticatedMember: () => const AppShellRoute().go(context),
          onVerified: (flowId) =>
              RealNameAdultVerificationRoute(OnboardingFlowRouteArgs(flowId))
                  .push<void>(context),
        ),
      ),
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
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return _bottomUpPage(
      state: state,
      child: TermsConsentPage(
        initialAgreement: $extra.initialAgreement,
        onClose: () => context.pop(),
      ),
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
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    void back() =>
        context.canPop() ? context.pop() : const MobileLoginRoute().go(context);
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: back,
        child: RealNameAdultVerificationPage(
          flowId: $extra.flowId,
          onBack: back,
          onNext: () {
            if ($extra.flowId == 'real-registration') {
              _continueRealRegistration(context);
            } else {
              MembershipImageSubmissionRoute($extra).push<void>(context);
            }
          },
          onInvalidFlow: () => $extra.flowId == 'real-registration'
              ? _continueRealRegistration(context)
              : const MobileLoginRoute().go(context),
        ),
      ),
    );
  }
}

@TypedGoRoute<MembershipImageSubmissionRoute>(path: '/onboarding/images')
class MembershipImageSubmissionRoute extends GoRouteData
    with $MembershipImageSubmissionRoute {
  const MembershipImageSubmissionRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    void back() => $extra.flowId == 'real-registration'
        ? SystemNavigator.pop()
        : context.canPop()
        ? context.pop()
        : RealNameAdultVerificationRoute($extra).go(context);
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: back,
        child: MembershipImageSubmissionPage(
          flowId: $extra.flowId,
          onBack: back,
          onNext: () => MembershipReviewStatusRoute($extra).push<void>(context),
          onInvalidFlow: () => $extra.flowId == 'real-registration'
              ? _continueRealRegistration(context)
              : const MobileLoginRoute().go(context),
        ),
      ),
    );
  }
}

@TypedGoRoute<StyleMusicPreferencesRoute>(path: '/onboarding/style-music')
class StyleMusicPreferencesRoute extends GoRouteData
    with $StyleMusicPreferencesRoute {
  const StyleMusicPreferencesRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    void back() => context.canPop()
        ? context.pop()
        : MembershipImageSubmissionRoute($extra).go(context);
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: back,
        child: StyleMusicPreferencesPage(
          flowId: $extra.flowId,
          onBack: back,
          onNext: () => DrinkEventPreferencesRoute($extra).push<void>(context),
          onInvalidFlow: () => const MobileLoginRoute().go(context),
        ),
      ),
    );
  }
}

@TypedGoRoute<DrinkEventPreferencesRoute>(path: '/onboarding/drink-events')
class DrinkEventPreferencesRoute extends GoRouteData
    with $DrinkEventPreferencesRoute {
  const DrinkEventPreferencesRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    void back() => context.canPop()
        ? context.pop()
        : StyleMusicPreferencesRoute($extra).go(context);
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: back,
        child: DrinkEventPreferencesPage(
          flowId: $extra.flowId,
          onBack: back,
          onSubmitted: () =>
              MembershipReviewStatusRoute($extra).push<void>(context),
          onInvalidFlow: () => const MobileLoginRoute().go(context),
        ),
      ),
    );
  }
}

@TypedGoRoute<MembershipReviewStatusRoute>(path: '/onboarding/review')
class MembershipReviewStatusRoute extends GoRouteData
    with $MembershipReviewStatusRoute {
  const MembershipReviewStatusRoute(this.$extra);

  final OnboardingFlowRouteArgs $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    if ($extra.flowId == 'real-registration') {
      return _authFlowPage(
        state: state,
        child: _ControlledRouteBackScope(
          onBack: () => const MobileLoginRoute().go(context),
          child: RealMembershipStatusPage(
            onImages: () => MembershipImageSubmissionRoute($extra).go(context),
            onApproved: () => const AppShellRoute().go(context),
            onIdentity: () =>
                RealNameAdultVerificationRoute($extra).go(context),
            onBack: () => const MobileLoginRoute().go(context),
          ),
        ),
      );
    }
    return _authFlowPage(
      state: state,
      child: _ControlledRouteBackScope(
        onBack: SystemNavigator.pop,
        child: MembershipReviewStatusPage(
          flowId: $extra.flowId,
          onApproved: () => const AppShellRoute().go(context),
          onFixImages: () => context.canPop()
              ? context.pop()
              : MembershipImageSubmissionRoute($extra).go(context),
          onExit: () => const MobileLoginRoute().go(context),
          onInvalidFlow: () => const MobileLoginRoute().go(context),
        ),
      ),
    );
  }
}

class _ControlledRouteBackScope extends StatelessWidget {
  const _ControlledRouteBackScope({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: child,
    );
  }
}

@TypedGoRoute<AppShellRoute>(path: '/home')
class AppShellRoute extends GoRouteData with $AppShellRoute {
  const AppShellRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AppShellPage(
    profileCoverStore: LocalProfileCoverStore.instance,
    onOpenTogether: () => const AaReservationsRoute().push<void>(context),
    onOpenParty: () => const VipPartyRoute().push<void>(context),
    onOpenOrdering: () => const ScanOrderingCartRoute().push<void>(context),
    onOpenAssets: (type) => AssetLedgerRoute(type).push<void>(context),
    onOpenEditProfile: (nickname, signature, coverAsset) =>
        EditProfileRoute(EditProfileRouteArgs(nickname, signature, coverAsset))
            .push<EditableProfileResult>(context),
    onOpenPersonalQr: () => const PersonalQrRoute().push<void>(context),
    onOpenSettings: () => const SettingsRoute().push<void>(context),
    onOpenOrders: () => const OrderCenterRoute().push<void>(context),
    onOpenFriendRequests: () => const FriendRequestsRoute().push<void>(context),
    onOpenAddFriend: () => const AddFriendRoute().push<void>(context),
    onOpenBlacklist: () => const BlacklistRoute().push<void>(context),
    onOpenUserProfile: (targetRef) =>
        UserProfileRoute(UserProfileRouteArgs(targetRef)).push<void>(context),
    onOpenContentAuthor: (targetRef) =>
        UserProfileRoute(UserProfileRouteArgs(targetRef)).push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
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
    profileCoverStore: LocalProfileCoverStore.instance,
    initialIndex: 2,
    onOpenTogether: () => const AaReservationsRoute().push<void>(context),
    onOpenParty: () => const VipPartyRoute().push<void>(context),
    onOpenOrdering: () => const ScanOrderingCartRoute().push<void>(context),
    onOpenAssets: (type) => AssetLedgerRoute(type).push<void>(context),
    onOpenEditProfile: (nickname, signature, coverAsset) =>
        EditProfileRoute(EditProfileRouteArgs(nickname, signature, coverAsset))
            .push<EditableProfileResult>(context),
    onOpenPersonalQr: () => const PersonalQrRoute().push<void>(context),
    onOpenSettings: () => const SettingsRoute().push<void>(context),
    onOpenOrders: () => const OrderCenterRoute().push<void>(context),
    onOpenFriendRequests: () => const FriendRequestsRoute().push<void>(context),
    onOpenAddFriend: () => const AddFriendRoute().push<void>(context),
    onOpenBlacklist: () => const BlacklistRoute().push<void>(context),
    onOpenUserProfile: (targetRef) =>
        UserProfileRoute(UserProfileRouteArgs(targetRef)).push<void>(context),
    onOpenContentAuthor: (targetRef) =>
        UserProfileRoute(UserProfileRouteArgs(targetRef)).push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
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
    profileCoverStore: LocalProfileCoverStore.instance,
    initialIndex: 1,
    onOpenTogether: () => const AaReservationsRoute().push<void>(context),
    onOpenParty: () => const VipPartyRoute().push<void>(context),
    onOpenOrdering: () => const ScanOrderingCartRoute().push<void>(context),
    onOpenAssets: (type) => AssetLedgerRoute(type).push<void>(context),
    onOpenEditProfile: (nickname, signature, coverAsset) =>
        EditProfileRoute(EditProfileRouteArgs(nickname, signature, coverAsset))
            .push<EditableProfileResult>(context),
    onOpenPersonalQr: () => const PersonalQrRoute().push<void>(context),
    onOpenSettings: () => const SettingsRoute().push<void>(context),
    onOpenOrders: () => const OrderCenterRoute().push<void>(context),
    onOpenFriendRequests: () => const FriendRequestsRoute().push<void>(context),
    onOpenAddFriend: () => const AddFriendRoute().push<void>(context),
    onOpenBlacklist: () => const BlacklistRoute().push<void>(context),
    onOpenUserProfile: (targetRef) =>
        UserProfileRoute(UserProfileRouteArgs(targetRef)).push<void>(context),
    onOpenContentAuthor: (targetRef) =>
        UserProfileRoute(UserProfileRouteArgs(targetRef)).push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
    onOpenScanner: (shellContext, originIndex) =>
        SafeScannerRoute(ScannerRouteArgs(originIndex))
            .push<SafeScanDestination>(shellContext),
  );
}

@TypedGoRoute<AddFriendRoute>(path: '/social/add')
class AddFriendRoute extends GoRouteData with $AddFriendRoute {
  const AddFriendRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AddFriendPage(
    onBack: () => context.pop(),
    onOpenPersonalQr: () => const PersonalQrRoute().push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
    onOpenScanner: () async {
      final destination = await SafeScannerRoute(const ScannerRouteArgs(1))
          .push<SafeScanDestination>(context);
      if (destination == SafeScanDestination.friendProfile && context.mounted) {
        await UserProfileRoute(
          const UserProfileRouteArgs(
            'contact-alice',
            relationship: UserProfileRelationship.stranger,
          ),
        ).push<void>(context);
      }
    },
  );
}

@TypedGoRoute<FriendRequestsRoute>(path: '/social/requests')
class FriendRequestsRoute extends GoRouteData with $FriendRequestsRoute {
  const FriendRequestsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => FriendRequestsPage(
    onBack: () => context.pop(),
    onOpenAddFriend: () => const AddFriendRoute().push<void>(context),
    onOpenChat: (peerName) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已打开与 $peerName 的 Fake 会话入口'))),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

class UserProfileRouteArgs {
  const UserProfileRouteArgs(
    this.targetRef, {
    this.relationship = UserProfileRelationship.friend,
  });

  final String targetRef;
  final UserProfileRelationship relationship;
}

@TypedGoRoute<UserProfileRoute>(path: '/social/profile')
class UserProfileRoute extends GoRouteData with $UserProfileRoute {
  const UserProfileRoute(this.$extra);

  final UserProfileRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => UserProfilePage(
    targetRef: $extra.targetRef,
    initialRelationship: $extra.relationship,
    onBack: () => context.pop(),
    onOpenSelfProfile: () => const AppShellRoute().go(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

class SendFriendRequestRouteArgs {
  const SendFriendRequestRouteArgs(this.targetRef, this.targetName);

  final String targetRef;
  final String targetName;
}

@TypedGoRoute<SendFriendRequestRoute>(path: '/social/request/send')
class SendFriendRequestRoute extends GoRouteData with $SendFriendRequestRoute {
  const SendFriendRequestRoute(this.$extra);

  final SendFriendRequestRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      SendFriendRequestPage(
        targetRef: $extra.targetRef,
        targetName: $extra.targetName,
        onBack: () => context.pop(),
        onSent: () => context.pop(),
        onSessionResetRequested: () => _clearCommerceAndLogin(context),
      );
}

class FriendRemarkRouteArgs {
  const FriendRemarkRouteArgs(
    this.targetRef,
    this.initialRemark,
    this.signature,
  );

  final String targetRef;
  final String initialRemark;
  final String signature;
}

@TypedGoRoute<FriendRemarkRoute>(path: '/social/friend/remark')
class FriendRemarkRoute extends GoRouteData with $FriendRemarkRoute {
  const FriendRemarkRoute(this.$extra);

  final FriendRemarkRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => FriendRemarkPage(
    targetRef: $extra.targetRef,
    initialRemark: $extra.initialRemark,
    signature: $extra.signature,
    onBack: () => context.pop(),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

class RelationshipPermissionsRouteArgs {
  const RelationshipPermissionsRouteArgs(this.targetRef, this.displayName);

  final String targetRef;
  final String displayName;
}

@TypedGoRoute<RelationshipPermissionsRoute>(path: '/social/friend/permissions')
class RelationshipPermissionsRoute extends GoRouteData
    with $RelationshipPermissionsRoute {
  const RelationshipPermissionsRoute(this.$extra);

  final RelationshipPermissionsRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RelationshipPermissionsPage(
        targetRef: $extra.targetRef,
        displayName: $extra.displayName,
        onBack: () => context.pop(),
        onSessionResetRequested: () => _clearCommerceAndLogin(context),
      );
}

@TypedGoRoute<BlacklistRoute>(path: '/social/blacklist')
class BlacklistRoute extends GoRouteData with $BlacklistRoute {
  const BlacklistRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => BlacklistPage(
    onBack: () => context.pop(),
    onOpenAddFriend: () => const AddFriendRoute().push<void>(context),
    onOpenUserProfile: (targetRef) => UserProfileRoute(
      UserProfileRouteArgs(
        targetRef,
        relationship: UserProfileRelationship.blockedByMe,
      ),
    ).push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
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
  Widget build(BuildContext context, GoRouterState state) {
    final canPop = context.canPop();
    void back() => canPop ? context.pop() : const AppShellRoute().go(context);

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) const AppShellRoute().go(context);
      },
      child: AaReservationsPage(
        repository: _commerce(context),
        onBack: back,
        onSessionResetRequested: () => _clearCommerceAndLogin(context),
        onOpenAdmissionTicket: () =>
            const AaPositioningCardRoute().push<void>(context),
      ),
    );
  }
}

@TypedGoRoute<AaPositioningCardRoute>(path: '/club/aa/positioning-card')
class AaPositioningCardRoute extends GoRouteData with $AaPositioningCardRoute {
  const AaPositioningCardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final canPop = context.canPop();
    void back() =>
        canPop ? context.pop() : const AaReservationsRoute().go(context);

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) const AaReservationsRoute().go(context);
      },
      child: AaPositioningCardPage(onBack: back),
    );
  }
}

@TypedGoRoute<VipPartyRoute>(
  path: '/club/parties',
  routes: [
    TypedGoRoute<VipPartyCreateRoute>(path: 'create'),
    TypedGoRoute<VipPartyManagementRoute>(path: 'manage'),
  ],
)
class VipPartyRoute extends GoRouteData with $VipPartyRoute {
  const VipPartyRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => VipPartyPage(
    onBack: () => context.pop(),
    onCreateParty: (date) => VipPartyCreateRoute(date).push<void>(context),
    onManageParty: () => const VipPartyManagementRoute().push<void>(context),
    onOpenTicket: () => const AdmissionTicketRoute().push<void>(context),
  );
}

class VipPartyCreateRoute extends GoRouteData with $VipPartyCreateRoute {
  const VipPartyCreateRoute(this.date);

  final String date;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VipPartyCreatePage(onBack: () => context.pop(), initialDate: date);
}

class VipPartyManagementRoute extends GoRouteData
    with $VipPartyManagementRoute {
  const VipPartyManagementRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VipPartyManagementPage(onBack: () => context.pop());
}

@TypedGoRoute<AdmissionTicketRoute>(path: '/club/admission')
class AdmissionTicketRoute extends GoRouteData with $AdmissionTicketRoute {
  const AdmissionTicketRoute([this.$extra]);

  final FakeAdmissionRef? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AdmissionTicketPage(admissionRef: $extra, onBack: () => context.pop());
}

@TypedGoRoute<ScanOrderingCartRoute>(path: '/commerce/ordering')
class ScanOrderingCartRoute extends GoRouteData with $ScanOrderingCartRoute {
  const ScanOrderingCartRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ScanOrderingCartPage(
        onBack: () => context.canPop()
            ? context.pop()
            : const AppShellRoute().go(context),
        onQuoteReady: (quote) =>
            ScanOrderConfirmationRoute(quote).push<void>(context),
        onOpenOrders: () => const OrderCenterRoute().push<void>(context),
      );
}

@TypedGoRoute<ScanOrderConfirmationRoute>(path: '/commerce/ordering/confirm')
class ScanOrderConfirmationRoute extends GoRouteData
    with $ScanOrderConfirmationRoute {
  const ScanOrderConfirmationRoute([this.$extra]);

  final FakeOrderingQuote? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ScanOrderConfirmationPage(
        repository: _commerce(context),
        quote: $extra,
        onBack: () => context.canPop()
            ? context.pop()
            : const ScanOrderingCartRoute().go(context),
        onModify: () => context.canPop()
            ? context.pop()
            : const ScanOrderingCartRoute().go(context),
        onOrderCreated: (intent) =>
            PaymentResultRoute(FakePaymentIntentRef(intent.paymentIntentId))
                .go(context),
        onSessionResetRequested: () => _clearCommerceAndLogin(context),
        onOpenOrders: () => const OrderCenterRoute().go(context),
      );
}

@TypedGoRoute<OrderCenterRoute>(
  path: '/commerce/orders',
  routes: [TypedGoRoute<OrderDetailRoute>(path: 'detail')],
)
class OrderCenterRoute extends GoRouteData with $OrderCenterRoute {
  const OrderCenterRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => OrderCenterPage(
    repository: _commerce(context),
    onBack: () =>
        context.canPop() ? context.pop() : const AppShellRoute().go(context),
    onOpenHome: () => const AppShellRoute().go(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
    onOpenOrder: (orderRef) => OrderDetailRoute(orderRef).push<void>(context),
  );
}

class OrderDetailRoute extends GoRouteData with $OrderDetailRoute {
  const OrderDetailRoute([this.$extra]);

  final FakeOrderRef? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => OrderDetailPage(
    repository: _commerce(context),
    orderRef: $extra ?? const FakeOrderRef(''),
    onBack: () =>
        context.canPop() ? context.pop() : const OrderCenterRoute().go(context),
    onAdmission: (admissionRef) =>
        AdmissionTicketRoute(FakeAdmissionRef(admissionRef))
            .push<void>(context),
    onPaymentIntent: (intentId) =>
        PaymentResultRoute(FakePaymentIntentRef(intentId)).push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

@TypedGoRoute<PaymentResultRoute>(path: '/commerce/payment')
class PaymentResultRoute extends GoRouteData with $PaymentResultRoute {
  const PaymentResultRoute([this.$extra]);

  final FakePaymentIntentRef? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => PaymentResultPage(
    repository: _commerce(context),
    intentRef: $extra ?? const FakePaymentIntentRef(''),
    onClose: () {
      final order = _commerce(context).payment($extra?.opaqueId ?? '');
      if (order == null) {
        const OrderCenterRoute().go(context);
      } else if (context.canPop()) {
        context.pop();
      } else {
        OrderDetailRoute(FakeOrderRef(order.id)).go(context);
      }
    },
    onOpenOrder: (orderRef) => OrderDetailRoute(orderRef).go(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

@TypedGoRoute<AssetLedgerRoute>(path: '/me/assets')
class AssetLedgerRoute extends GoRouteData with $AssetLedgerRoute {
  const AssetLedgerRoute([this.$extra]);

  final AssetLedgerType? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => AssetLedgerPage(
    initialType: $extra ?? AssetLedgerType.cashBalance,
    onBack: () =>
        context.canPop() ? context.pop() : const AppShellRoute().go(context),
    onOpenOrder: (orderRef) => OrderDetailRoute(orderRef).push<void>(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

class EditProfileRouteArgs {
  const EditProfileRouteArgs(this.nickname, this.signature, this.coverAsset);

  final String nickname;
  final String signature;
  final String coverAsset;
}

@TypedGoRoute<EditProfileRoute>(path: '/me/edit')
class EditProfileRoute extends GoRouteData with $EditProfileRoute {
  const EditProfileRoute(this.$extra);

  final EditProfileRouteArgs $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) => EditProfilePage(
    nickname: $extra.nickname,
    signature: $extra.signature,
    coverAsset: $extra.coverAsset,
    onBack: () => context.pop(),
    onSaved: (result) => context.pop(result),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

@TypedGoRoute<PersonalQrRoute>(path: '/me/qr')
class PersonalQrRoute extends GoRouteData with $PersonalQrRoute {
  const PersonalQrRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => PersonalQrPage(
    onBack: () =>
        context.canPop() ? context.pop() : const AppShellRoute().go(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

@TypedGoRoute<SettingsRoute>(
  path: '/me/settings',
  routes: [
    TypedGoRoute<PaymentSecurityRoute>(path: 'payment-security'),
    TypedGoRoute<AccountDeletionRoute>(path: 'delete-account'),
    TypedGoRoute<AboutLegalRoute>(path: 'about'),
  ],
)
class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => SettingsPage(
    onBack: () =>
        context.canPop() ? context.pop() : const AppShellRoute().go(context),
    onOpenPaymentSecurity: () =>
        const PaymentSecurityRoute().push<void>(context),
    onOpenAccountDeletion: () =>
        const AccountDeletionRoute().push<void>(context),
    onOpenAboutLegal: () => const AboutLegalRoute().push<void>(context),
    onLogoutCompleted: () => _clearCommerceAndLogin(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}

class PaymentSecurityRoute extends GoRouteData with $PaymentSecurityRoute {
  const PaymentSecurityRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PaymentSecurityPage(
        onBack: () => context.canPop()
            ? context.pop()
            : const SettingsRoute().go(context),
        onSessionResetRequested: () => _clearCommerceAndLogin(context),
      );
}

class AccountDeletionRoute extends GoRouteData with $AccountDeletionRoute {
  const AccountDeletionRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AccountDeletionPage(
        onBack: () => context.canPop()
            ? context.pop()
            : const SettingsRoute().go(context),
        onCompleted: () => _clearCommerceAndLogin(context),
        onSessionResetRequested: () => _clearCommerceAndLogin(context),
      );
}

class AboutLegalRoute extends GoRouteData with $AboutLegalRoute {
  const AboutLegalRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => AboutLegalPage(
    onBack: () =>
        context.canPop() ? context.pop() : const SettingsRoute().go(context),
    onSessionResetRequested: () => _clearCommerceAndLogin(context),
  );
}
