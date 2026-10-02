/// Public store projection. Payment credentials must never be included here.
class TogetherStore {
  const TogetherStore({
    required this.ref,
    required this.name,
    required this.cityCode,
    required this.address,
  });

  final String ref, name, cityCode, address;
}

/// Capacity and ownership are supplied by the service, not a typed table name.
class TogetherTable {
  const TogetherTable({
    required this.ref,
    required this.storeRef,
    required this.name,
    required this.maximumSeats,
  });

  final String ref, storeRef, name;
  final int maximumSeats;
}

abstract interface class TogetherStoreRepository {
  Future<List<TogetherStore>> list({required String cityCode});
  Future<List<TogetherTable>> tables({required String storeRef});
}
