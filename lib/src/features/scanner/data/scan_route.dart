import '../../commerce/data/table_ordering_code.dart';

enum ScanRouteKind {
  tableOrdering,
  member,
  group,
  partner,
  cashierLogin,
  unsupported,
}

/// Local dispatch only; the destination service still validates the code.
class ScanRoute {
  const ScanRoute(this.kind, {this.location, this.challengeId});

  final ScanRouteKind kind;
  final String? location;
  final String? challengeId;

  static ScanRoute parse(String raw) {
    const cashierPrefix = 'kingclub://cashier-login/v1/';
    if (raw.startsWith('kingclub://cashier-login')) {
      final match = RegExp(r'^kingclub://cashier-login/v1/[0-9a-f]{64}$')
          .firstMatch(raw);
      if (match == null || match.end != raw.length) {
        return const ScanRoute(ScanRouteKind.unsupported);
      }
      return ScanRoute(
        ScanRouteKind.cashierLogin,
        challengeId: raw.substring(cashierPrefix.length),
      );
    }
    if (RegExp(r'^KC:P:[0-9A-F]{32}$').hasMatch(raw)) {
      return const ScanRoute(ScanRouteKind.partner);
    }
    final table = TableOrderingCode.tryParse(raw);
    if (table != null) {
      return ScanRoute(
        ScanRouteKind.tableOrdering,
        location: table.orderingLocation,
      );
    }
    if (RegExp(r'^KC:G:[0-9A-F]{32}$').hasMatch(raw)) {
      return const ScanRoute(ScanRouteKind.group);
    }
    if (RegExp(r'^KC:M:[0-9A-F]{32}$').hasMatch(raw) ||
        (raw.length <= 2048 && raw.startsWith('kingclub://member/v1/'))) {
      return const ScanRoute(ScanRouteKind.member);
    }
    return const ScanRoute(ScanRouteKind.unsupported);
  }
}
