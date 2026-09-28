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
    this.cityId,
    this.cityName,
    this.tableId,
    this.tenantRef,
    this.brandRef,
    this.currency,
    this.timeZone,
    this.paymentTiming,
  });

  final String contextRef;
  final String memberRef;
  final String storeRef;
  final String tableSessionRef;
  final String storeName;
  final String storeAddress;
  final String tableName;
  final String businessDate;
  // A bar is the operating store in commerce, not a separate duplicate ID.
  String get barId => storeRef;
  final String? cityId;
  final String? cityName;
  final String? tableId;
  final String? tenantRef;
  final String? brandRef;
  final String? currency;
  final String? timeZone;
  final String? paymentTiming;

  bool hasSameScope(OrderingContext other) =>
      contextRef == other.contextRef &&
      memberRef == other.memberRef &&
      storeRef == other.storeRef &&
      cityId == other.cityId &&
      tableId == other.tableId &&
      tenantRef == other.tenantRef &&
      brandRef == other.brandRef &&
      currency == other.currency &&
      timeZone == other.timeZone &&
      paymentTiming == other.paymentTiming &&
      tableSessionRef == other.tableSessionRef &&
      businessDate == other.businessDate;
}
