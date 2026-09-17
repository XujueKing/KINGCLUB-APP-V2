/// Display/routing context supplied by the ordering resolver.
///
/// This is not a payment or seating authorization. Production use must resolve
/// and revalidate these references on the server; raw QR labels are untrusted.
class OrderingContext {
  const OrderingContext({
    required this.contextRef,
    required this.memberRef,
    required this.storeRef,
    required this.tableSessionRef,
    required this.storeName,
    required this.storeAddress,
    required this.tableName,
    required this.businessDate,
  });

  final String contextRef;
  final String memberRef;
  final String storeRef;
  final String tableSessionRef;
  final String storeName;
  final String storeAddress;
  final String tableName;
  final String businessDate;

  bool hasSameScope(OrderingContext other) =>
      contextRef == other.contextRef &&
      memberRef == other.memberRef &&
      storeRef == other.storeRef &&
      tableSessionRef == other.tableSessionRef &&
      businessDate == other.businessDate;
}
