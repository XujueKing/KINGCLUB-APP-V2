import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

class StorageItem {
  const StorageItem({
    required this.ref,
    required this.name,
    required this.assetKey,
    this.category = 'wine',
    this.englishName = '',
    this.description = '',
    this.quantity = 1,
    this.remainingPercent = 100,
    this.storedAt = '',
    this.expiresAt = '',
    this.maximumValue,
    this.status = 'available',
    this.canPickup = true,
  });
  factory StorageItem.fromJson(Map<String, dynamic> j) => StorageItem(
    ref: j['itemRef'] as String,
    name: j['name'] as String,
    assetKey: j['assetKey'] as String,
    category: j['category'] as String,
    englishName: j['englishName'] as String? ?? '',
    description: j['description'] as String? ?? '',
    quantity: (j['quantity'] as num).toInt(),
    remainingPercent: (j['remainingPercent'] as num).toDouble(),
    storedAt: j['storedAt'] as String? ?? '',
    expiresAt: j['expiresAt'] as String? ?? '',
    maximumValue: (j['maximumValue'] as num?)?.toDouble(),
    status: j['status'] as String,
    canPickup: j['canPickup'] == true,
  );
  final String ref,
      name,
      assetKey,
      category,
      englishName,
      description,
      storedAt,
      expiresAt,
      status;
  final int quantity;
  final double remainingPercent;
  final double? maximumValue;
  final bool canPickup;
  String get image =>
      'assets/legacy/storage/${switch (assetKey) {
        'vodka' => 'vodka.png',
        'chivas' => 'CHIVAS12.png',
        'hennessy' => 'HennessyVSOP.png',
        'aa-ticket' => 'freeticket.png',
        _ => 'fail.png',
      }}';
  String get thumbnail => category == 'item'
      ? 'assets/legacy/storage/freeticket2.png'
      : ['vodka', 'chivas', 'hennessy'].contains(assetKey)
      ? image.replaceFirst('.png', '_mini.png')
      : image;
}

abstract class StorageRepository {
  Future<List<StorageItem>> list();
  Future<StorageItem> detail(String ref);
  Future<Map<String, dynamic>> issue(String ref);
}

class RealStorageRepository implements StorageRepository {
  final _client = KingclubSecureClient(kingclubApiBaseUrl);
  Future<Map<String, dynamic>> _call(
    String id,
    Map<String, dynamic> params,
  ) async {
    final session = await SecureSessionStore().readSession();
    if (session == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    return _client.call(id, params, session: session);
  }

  @override
  Future<List<StorageItem>> list() async {
    final items = <StorageItem>[];
    int? offset = 0;
    while (offset != null) {
      final page = await _call('K260912000401', {'offset': offset});
      items.addAll(
        (page['items'] as List).map(
          (e) => StorageItem.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      offset = (page['nextOffset'] as num?)?.toInt();
    }
    return items;
  }

  @override
  Future<StorageItem> detail(String ref) async => StorageItem.fromJson(
    Map<String, dynamic>.from(
      (await _call('K260912000402', {'itemRef': ref}))['item'] as Map,
    ),
  );
  @override
  Future<Map<String, dynamic>> issue(String ref) =>
      _call('K260912000403', {'itemRef': ref});
}

/// Explicit offline preview only. A real session never receives sample stock.
class PreviewStorageRepository implements StorageRepository {
  PreviewStorageRepository([this.items = const []]);
  final List<StorageItem> items;
  @override
  Future<List<StorageItem>> list() async => items;
  @override
  Future<StorageItem> detail(String ref) async =>
      items.firstWhere((i) => i.ref == ref);
  @override
  Future<Map<String, dynamic>> issue(String ref) async =>
      throw const AuthFailure('PREVIEW_ONLY', '预览不签发提取码');
}
