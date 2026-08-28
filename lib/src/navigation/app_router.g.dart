// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $authBootstrapRoute,
  $mobileLoginRoute,
  $smsCodeRoute,
  $termsConsentRoute,
  $realNameAdultVerificationRoute,
  $membershipImageSubmissionRoute,
  $styleMusicPreferencesRoute,
  $drinkEventPreferencesRoute,
  $membershipReviewStatusRoute,
  $appShellRoute,
  $contentFeedRoute,
  $contactsRoute,
  $addFriendRoute,
  $friendRequestsRoute,
  $userProfileRoute,
  $sendFriendRequestRoute,
  $friendRemarkRoute,
  $relationshipPermissionsRoute,
  $blacklistRoute,
  $safeScannerRoute,
  $aaReservationsRoute,
  $vipPartyRoute,
  $admissionTicketRoute,
  $scanOrderingCartRoute,
  $scanOrderConfirmationRoute,
  $orderCenterRoute,
  $paymentResultRoute,
  $assetLedgerRoute,
  $editProfileRoute,
  $personalQrRoute,
  $settingsRoute,
];

RouteBase get $authBootstrapRoute => GoRouteData.$route(
  path: '/auth/bootstrap',
  hasOverriddenOnExit: false,
  factory: $AuthBootstrapRoute._fromState,
);

mixin $AuthBootstrapRoute on GoRouteData {
  static AuthBootstrapRoute _fromState(GoRouterState state) =>
      const AuthBootstrapRoute();

  @override
  String get location => GoRouteData.$location('/auth/bootstrap');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $mobileLoginRoute => GoRouteData.$route(
  path: '/auth/mobile',
  hasOverriddenOnExit: false,
  factory: $MobileLoginRoute._fromState,
);

mixin $MobileLoginRoute on GoRouteData {
  static MobileLoginRoute _fromState(GoRouterState state) =>
      const MobileLoginRoute();

  @override
  String get location => GoRouteData.$location('/auth/mobile');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $smsCodeRoute => GoRouteData.$route(
  path: '/auth/code',
  hasOverriddenOnExit: false,
  factory: $SmsCodeRoute._fromState,
);

mixin $SmsCodeRoute on GoRouteData {
  static SmsCodeRoute _fromState(GoRouterState state) =>
      SmsCodeRoute(state.extra as LoginFlowRouteArgs);

  SmsCodeRoute get _self => this as SmsCodeRoute;

  @override
  String get location => GoRouteData.$location('/auth/code');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $termsConsentRoute => GoRouteData.$route(
  path: '/auth/consent',
  hasOverriddenOnExit: false,
  factory: $TermsConsentRoute._fromState,
);

mixin $TermsConsentRoute on GoRouteData {
  static TermsConsentRoute _fromState(GoRouterState state) =>
      TermsConsentRoute(state.extra as ConsentRouteArgs);

  TermsConsentRoute get _self => this as TermsConsentRoute;

  @override
  String get location => GoRouteData.$location('/auth/consent');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $realNameAdultVerificationRoute => GoRouteData.$route(
  path: '/onboarding/identity',
  hasOverriddenOnExit: false,
  factory: $RealNameAdultVerificationRoute._fromState,
);

mixin $RealNameAdultVerificationRoute on GoRouteData {
  static RealNameAdultVerificationRoute _fromState(GoRouterState state) =>
      RealNameAdultVerificationRoute(state.extra as OnboardingFlowRouteArgs);

  RealNameAdultVerificationRoute get _self =>
      this as RealNameAdultVerificationRoute;

  @override
  String get location => GoRouteData.$location('/onboarding/identity');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $membershipImageSubmissionRoute => GoRouteData.$route(
  path: '/onboarding/images',
  hasOverriddenOnExit: false,
  factory: $MembershipImageSubmissionRoute._fromState,
);

mixin $MembershipImageSubmissionRoute on GoRouteData {
  static MembershipImageSubmissionRoute _fromState(GoRouterState state) =>
      MembershipImageSubmissionRoute(state.extra as OnboardingFlowRouteArgs);

  MembershipImageSubmissionRoute get _self =>
      this as MembershipImageSubmissionRoute;

  @override
  String get location => GoRouteData.$location('/onboarding/images');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $styleMusicPreferencesRoute => GoRouteData.$route(
  path: '/onboarding/style-music',
  hasOverriddenOnExit: false,
  factory: $StyleMusicPreferencesRoute._fromState,
);

mixin $StyleMusicPreferencesRoute on GoRouteData {
  static StyleMusicPreferencesRoute _fromState(GoRouterState state) =>
      StyleMusicPreferencesRoute(state.extra as OnboardingFlowRouteArgs);

  StyleMusicPreferencesRoute get _self => this as StyleMusicPreferencesRoute;

  @override
  String get location => GoRouteData.$location('/onboarding/style-music');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $drinkEventPreferencesRoute => GoRouteData.$route(
  path: '/onboarding/drink-events',
  hasOverriddenOnExit: false,
  factory: $DrinkEventPreferencesRoute._fromState,
);

mixin $DrinkEventPreferencesRoute on GoRouteData {
  static DrinkEventPreferencesRoute _fromState(GoRouterState state) =>
      DrinkEventPreferencesRoute(state.extra as OnboardingFlowRouteArgs);

  DrinkEventPreferencesRoute get _self => this as DrinkEventPreferencesRoute;

  @override
  String get location => GoRouteData.$location('/onboarding/drink-events');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $membershipReviewStatusRoute => GoRouteData.$route(
  path: '/onboarding/review',
  hasOverriddenOnExit: false,
  factory: $MembershipReviewStatusRoute._fromState,
);

mixin $MembershipReviewStatusRoute on GoRouteData {
  static MembershipReviewStatusRoute _fromState(GoRouterState state) =>
      MembershipReviewStatusRoute(state.extra as OnboardingFlowRouteArgs);

  MembershipReviewStatusRoute get _self => this as MembershipReviewStatusRoute;

  @override
  String get location => GoRouteData.$location('/onboarding/review');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $appShellRoute => GoRouteData.$route(
  path: '/home',
  hasOverriddenOnExit: false,
  factory: $AppShellRoute._fromState,
);

mixin $AppShellRoute on GoRouteData {
  static AppShellRoute _fromState(GoRouterState state) => const AppShellRoute();

  @override
  String get location => GoRouteData.$location('/home');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $contentFeedRoute => GoRouteData.$route(
  path: '/discover',
  hasOverriddenOnExit: false,
  factory: $ContentFeedRoute._fromState,
);

mixin $ContentFeedRoute on GoRouteData {
  static ContentFeedRoute _fromState(GoRouterState state) =>
      const ContentFeedRoute();

  @override
  String get location => GoRouteData.$location('/discover');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $contactsRoute => GoRouteData.$route(
  path: '/messages/contacts',
  hasOverriddenOnExit: false,
  factory: $ContactsRoute._fromState,
);

mixin $ContactsRoute on GoRouteData {
  static ContactsRoute _fromState(GoRouterState state) => const ContactsRoute();

  @override
  String get location => GoRouteData.$location('/messages/contacts');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $addFriendRoute => GoRouteData.$route(
  path: '/social/add',
  hasOverriddenOnExit: false,
  factory: $AddFriendRoute._fromState,
);

mixin $AddFriendRoute on GoRouteData {
  static AddFriendRoute _fromState(GoRouterState state) =>
      const AddFriendRoute();

  @override
  String get location => GoRouteData.$location('/social/add');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $friendRequestsRoute => GoRouteData.$route(
  path: '/social/requests',
  hasOverriddenOnExit: false,
  factory: $FriendRequestsRoute._fromState,
);

mixin $FriendRequestsRoute on GoRouteData {
  static FriendRequestsRoute _fromState(GoRouterState state) =>
      const FriendRequestsRoute();

  @override
  String get location => GoRouteData.$location('/social/requests');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $userProfileRoute => GoRouteData.$route(
  path: '/social/profile',
  hasOverriddenOnExit: false,
  factory: $UserProfileRoute._fromState,
);

mixin $UserProfileRoute on GoRouteData {
  static UserProfileRoute _fromState(GoRouterState state) =>
      UserProfileRoute(state.extra as UserProfileRouteArgs);

  UserProfileRoute get _self => this as UserProfileRoute;

  @override
  String get location => GoRouteData.$location('/social/profile');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $sendFriendRequestRoute => GoRouteData.$route(
  path: '/social/request/send',
  hasOverriddenOnExit: false,
  factory: $SendFriendRequestRoute._fromState,
);

mixin $SendFriendRequestRoute on GoRouteData {
  static SendFriendRequestRoute _fromState(GoRouterState state) =>
      SendFriendRequestRoute(state.extra as SendFriendRequestRouteArgs);

  SendFriendRequestRoute get _self => this as SendFriendRequestRoute;

  @override
  String get location => GoRouteData.$location('/social/request/send');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $friendRemarkRoute => GoRouteData.$route(
  path: '/social/friend/remark',
  hasOverriddenOnExit: false,
  factory: $FriendRemarkRoute._fromState,
);

mixin $FriendRemarkRoute on GoRouteData {
  static FriendRemarkRoute _fromState(GoRouterState state) =>
      FriendRemarkRoute(state.extra as FriendRemarkRouteArgs);

  FriendRemarkRoute get _self => this as FriendRemarkRoute;

  @override
  String get location => GoRouteData.$location('/social/friend/remark');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $relationshipPermissionsRoute => GoRouteData.$route(
  path: '/social/friend/permissions',
  hasOverriddenOnExit: false,
  factory: $RelationshipPermissionsRoute._fromState,
);

mixin $RelationshipPermissionsRoute on GoRouteData {
  static RelationshipPermissionsRoute _fromState(GoRouterState state) =>
      RelationshipPermissionsRoute(
        state.extra as RelationshipPermissionsRouteArgs,
      );

  RelationshipPermissionsRoute get _self =>
      this as RelationshipPermissionsRoute;

  @override
  String get location => GoRouteData.$location('/social/friend/permissions');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $blacklistRoute => GoRouteData.$route(
  path: '/social/blacklist',
  hasOverriddenOnExit: false,
  factory: $BlacklistRoute._fromState,
);

mixin $BlacklistRoute on GoRouteData {
  static BlacklistRoute _fromState(GoRouterState state) =>
      const BlacklistRoute();

  @override
  String get location => GoRouteData.$location('/social/blacklist');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $safeScannerRoute => GoRouteData.$route(
  path: '/scan',
  hasOverriddenOnExit: false,
  factory: $SafeScannerRoute._fromState,
);

mixin $SafeScannerRoute on GoRouteData {
  static SafeScannerRoute _fromState(GoRouterState state) =>
      SafeScannerRoute(state.extra as ScannerRouteArgs);

  SafeScannerRoute get _self => this as SafeScannerRoute;

  @override
  String get location => GoRouteData.$location('/scan');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $aaReservationsRoute => GoRouteData.$route(
  path: '/club/aa',
  hasOverriddenOnExit: false,
  factory: $AaReservationsRoute._fromState,
);

mixin $AaReservationsRoute on GoRouteData {
  static AaReservationsRoute _fromState(GoRouterState state) =>
      const AaReservationsRoute();

  @override
  String get location => GoRouteData.$location('/club/aa');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $vipPartyRoute => GoRouteData.$route(
  path: '/club/parties',
  hasOverriddenOnExit: false,
  factory: $VipPartyRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'create',
      hasOverriddenOnExit: false,
      factory: $VipPartyCreateRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'manage',
      hasOverriddenOnExit: false,
      factory: $VipPartyManagementRoute._fromState,
    ),
  ],
);

mixin $VipPartyRoute on GoRouteData {
  static VipPartyRoute _fromState(GoRouterState state) => const VipPartyRoute();

  @override
  String get location => GoRouteData.$location('/club/parties');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $VipPartyCreateRoute on GoRouteData {
  static VipPartyCreateRoute _fromState(GoRouterState state) =>
      VipPartyCreateRoute(state.uri.queryParameters['date']!);

  VipPartyCreateRoute get _self => this as VipPartyCreateRoute;

  @override
  String get location => GoRouteData.$location(
    '/club/parties/create',
    queryParams: {'date': _self.date},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $VipPartyManagementRoute on GoRouteData {
  static VipPartyManagementRoute _fromState(GoRouterState state) =>
      const VipPartyManagementRoute();

  @override
  String get location => GoRouteData.$location('/club/parties/manage');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $admissionTicketRoute => GoRouteData.$route(
  path: '/club/admission',
  hasOverriddenOnExit: false,
  factory: $AdmissionTicketRoute._fromState,
);

mixin $AdmissionTicketRoute on GoRouteData {
  static AdmissionTicketRoute _fromState(GoRouterState state) =>
      const AdmissionTicketRoute();

  @override
  String get location => GoRouteData.$location('/club/admission');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $scanOrderingCartRoute => GoRouteData.$route(
  path: '/commerce/ordering',
  hasOverriddenOnExit: false,
  factory: $ScanOrderingCartRoute._fromState,
);

mixin $ScanOrderingCartRoute on GoRouteData {
  static ScanOrderingCartRoute _fromState(GoRouterState state) =>
      const ScanOrderingCartRoute();

  @override
  String get location => GoRouteData.$location('/commerce/ordering');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $scanOrderConfirmationRoute => GoRouteData.$route(
  path: '/commerce/ordering/confirm',
  hasOverriddenOnExit: false,
  factory: $ScanOrderConfirmationRoute._fromState,
);

mixin $ScanOrderConfirmationRoute on GoRouteData {
  static ScanOrderConfirmationRoute _fromState(GoRouterState state) =>
      ScanOrderConfirmationRoute(state.extra as FakeOrderingQuote?);

  ScanOrderConfirmationRoute get _self => this as ScanOrderConfirmationRoute;

  @override
  String get location => GoRouteData.$location('/commerce/ordering/confirm');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $orderCenterRoute => GoRouteData.$route(
  path: '/commerce/orders',
  hasOverriddenOnExit: false,
  factory: $OrderCenterRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'detail',
      hasOverriddenOnExit: false,
      factory: $OrderDetailRoute._fromState,
    ),
  ],
);

mixin $OrderCenterRoute on GoRouteData {
  static OrderCenterRoute _fromState(GoRouterState state) =>
      const OrderCenterRoute();

  @override
  String get location => GoRouteData.$location('/commerce/orders');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $OrderDetailRoute on GoRouteData {
  static OrderDetailRoute _fromState(GoRouterState state) =>
      OrderDetailRoute(state.extra as FakeOrderRef?);

  OrderDetailRoute get _self => this as OrderDetailRoute;

  @override
  String get location => GoRouteData.$location('/commerce/orders/detail');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $paymentResultRoute => GoRouteData.$route(
  path: '/commerce/payment',
  hasOverriddenOnExit: false,
  factory: $PaymentResultRoute._fromState,
);

mixin $PaymentResultRoute on GoRouteData {
  static PaymentResultRoute _fromState(GoRouterState state) =>
      PaymentResultRoute(state.extra as FakePaymentIntentRef?);

  PaymentResultRoute get _self => this as PaymentResultRoute;

  @override
  String get location => GoRouteData.$location('/commerce/payment');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $assetLedgerRoute => GoRouteData.$route(
  path: '/me/assets',
  hasOverriddenOnExit: false,
  factory: $AssetLedgerRoute._fromState,
);

mixin $AssetLedgerRoute on GoRouteData {
  static AssetLedgerRoute _fromState(GoRouterState state) =>
      AssetLedgerRoute(state.extra as AssetLedgerType?);

  AssetLedgerRoute get _self => this as AssetLedgerRoute;

  @override
  String get location => GoRouteData.$location('/me/assets');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $editProfileRoute => GoRouteData.$route(
  path: '/me/edit',
  hasOverriddenOnExit: false,
  factory: $EditProfileRoute._fromState,
);

mixin $EditProfileRoute on GoRouteData {
  static EditProfileRoute _fromState(GoRouterState state) =>
      EditProfileRoute(state.extra as EditProfileRouteArgs);

  EditProfileRoute get _self => this as EditProfileRoute;

  @override
  String get location => GoRouteData.$location('/me/edit');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $personalQrRoute => GoRouteData.$route(
  path: '/me/qr',
  hasOverriddenOnExit: false,
  factory: $PersonalQrRoute._fromState,
);

mixin $PersonalQrRoute on GoRouteData {
  static PersonalQrRoute _fromState(GoRouterState state) =>
      const PersonalQrRoute();

  @override
  String get location => GoRouteData.$location('/me/qr');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $settingsRoute => GoRouteData.$route(
  path: '/me/settings',
  hasOverriddenOnExit: false,
  factory: $SettingsRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'payment-security',
      hasOverriddenOnExit: false,
      factory: $PaymentSecurityRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'delete-account',
      hasOverriddenOnExit: false,
      factory: $AccountDeletionRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'about',
      hasOverriddenOnExit: false,
      factory: $AboutLegalRoute._fromState,
    ),
  ],
);

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/me/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PaymentSecurityRoute on GoRouteData {
  static PaymentSecurityRoute _fromState(GoRouterState state) =>
      const PaymentSecurityRoute();

  @override
  String get location => GoRouteData.$location('/me/settings/payment-security');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AccountDeletionRoute on GoRouteData {
  static AccountDeletionRoute _fromState(GoRouterState state) =>
      const AccountDeletionRoute();

  @override
  String get location => GoRouteData.$location('/me/settings/delete-account');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AboutLegalRoute on GoRouteData {
  static AboutLegalRoute _fromState(GoRouterState state) =>
      const AboutLegalRoute();

  @override
  String get location => GoRouteData.$location('/me/settings/about');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'43a7bf200863a0a2d9e9d55992c7a6a70bd9dcad';
