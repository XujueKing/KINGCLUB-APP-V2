/// Client capabilities only; server authorization remains authoritative.
enum UnavailableLiveFeature {
  paymentSecurity,
  accountDeletion,
  orders,
  assets,
  reservation,
  party,
  admission,
  ordering,
}

UnavailableLiveFeature? unavailableLiveFeature(
  Uri location, {
  required bool liveMode,
  bool hasLiveOrderingContext = false,
}) {
  if (!liveMode) return null;
  final path = location.path;
  if (path == '/me/settings/payment-security') {
    return UnavailableLiveFeature.paymentSecurity;
  }
  if (path == '/me/settings/delete-account') {
    return UnavailableLiveFeature.accountDeletion;
  }
  if (path == '/me/assets') return UnavailableLiveFeature.assets;
  if (path == '/commerce/orders' ||
      path.startsWith('/commerce/orders/') ||
      path == '/commerce/payment') {
    return UnavailableLiveFeature.orders;
  }
  if (path == '/club/aa' || path.startsWith('/club/aa/')) {
    return UnavailableLiveFeature.reservation;
  }
  if (path == '/club/parties' || path.startsWith('/club/parties/')) {
    return UnavailableLiveFeature.party;
  }
  if (path == '/club/admission') return UnavailableLiveFeature.admission;
  if ((path == '/commerce/ordering' &&
          (location.queryParameters['tableId']?.trim().isEmpty ?? true)) ||
      (path == '/commerce/ordering/confirm' && !hasLiveOrderingContext)) {
    return UnavailableLiveFeature.ordering;
  }
  return null;
}
