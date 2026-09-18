import '../../commerce/data/table_ordering_code.dart';

enum ScanRouteKind { tableOrdering, member, group, unsupported }

/// Local dispatch only; the destination service still validates the code.
class ScanRoute {
  const ScanRoute(this.kind, {this.location});

  final ScanRouteKind kind;
  final String? location;

  static ScanRoute parse(String raw) {
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
