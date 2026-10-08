import 'together_party_draft.dart';
import 'together_store.dart';

/// One server projection shared by every picker in the publication wizard.
class PartyPublisherWorkspace implements TogetherStoreRepository {
  const PartyPublisherWorkspace({
    required this.store,
    required this.cityName,
    required this.tablesList,
    required this.packages,
    required this.artwork,
    this.contractStartsAt,
    this.contractEndsAt,
  });
  final TogetherStore store;
  final String cityName;
  final List<TogetherTable> tablesList;
  final List<TogetherPackage> packages;
  final List<TogetherArtwork> artwork;
  final DateTime? contractStartsAt, contractEndsAt;
  @override
  Future<List<TogetherStore>> list({required String cityCode}) async =>
      cityCode == store.cityCode ? [store] : [];
  @override
  Future<List<TogetherTable>> tables({required String storeRef}) async =>
      storeRef == store.ref ? tablesList : [];
}
