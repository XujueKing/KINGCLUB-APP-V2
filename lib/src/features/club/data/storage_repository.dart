import 'dart:ui' show Rect;

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
    this.storeName = '',
    this.description = '',
    this.quantity = 1,
    this.remainingPercent = 100,
    this.storedAt = '',
    this.expiresAt = '',
    this.maximumValue,
    this.status = 'available',
    this.canPickup = true,
    this.pickupConfirmed = false,
    this.bottleMaterial,
  });
  factory StorageItem.fromJson(Map<String, dynamic> j) => StorageItem(
    ref: j['itemRef'] as String,
    name: j['name'] as String,
    assetKey: j['assetKey'] as String,
    category: j['category'] as String,
    englishName: j['englishName'] as String? ?? '',
    storeName: j['storeName'] as String? ?? '',
    description: j['description'] as String? ?? '',
    quantity: (j['quantity'] as num).toInt(),
    remainingPercent: (j['remainingPercent'] as num).toDouble(),
    storedAt: j['storedAt'] as String? ?? '',
    expiresAt: j['expiresAt'] as String? ?? '',
    maximumValue: (j['maximumValue'] as num?)?.toDouble(),
    status: j['status'] as String,
    canPickup: j['canPickup'] == true,
    pickupConfirmed: j['pickupConfirmed'] == true,
    bottleMaterial: StorageBottleMaterial.parse(
      j['bottleMaterial'],
      j['storeRef'],
    ),
  );
  final String ref,
      name,
      assetKey,
      category,
      englishName,
      storeName,
      description,
      storedAt,
      expiresAt,
      status;
  final int quantity;
  final double remainingPercent;
  final double? maximumValue;
  final bool canPickup;
  final bool pickupConfirmed;
  final StorageBottleMaterial? bottleMaterial;
  String get expiresLabel {
    final date = DateTime.tryParse(expiresAt)?.toLocal();
    return date == null ? '' : date.toString().split('.').first;
  }

  String get image =>
      'assets/legacy/storage/${switch (assetKey) {
        'vodka' => 'vodka.png',
        'chivas' => 'CHIVAS12.png',
        'hennessy' => 'HennessyVSOP.png',
        'aa-ticket' => 'freeticket.png',
        _ => 'fail.png',
      }}';
  // Existing AA coupons are returned as item; explicit coupon types are also supported.
  bool get isCoupon =>
      category == 'coupon' || category == 'ticket' || assetKey == 'aa-ticket';
  String get storageCategory => isCoupon
      ? 'coupon'
      : category == 'wine'
      ? 'wine'
      : 'item';
  String get thumbnail => isCoupon
      ? 'assets/legacy/storage/freeticket2.png'
      : ['vodka', 'chivas', 'hennessy'].contains(assetKey)
      ? image.replaceFirst('.png', '_mini.png')
      : image;
}

/// Store-bound, signed source material. Token renewal retains the content cache.
class StorageBottleMaterial {
  const StorageBottleMaterial({
    required this.storeRef,
    required this.digest,
    required this.aspectRatio,
    required this.imageAspectRatio,
    required this.files,
    this.bodyBounds = const Rect.fromLTWH(0, 0, 1, 1),
  });
  final String storeRef, digest;
  final double aspectRatio, imageAspectRatio;
  final Map<String, String> files;
  final Rect bodyBounds;
  String cacheKey(String role) =>
      'bottle:$storeRef:png-contour-v1:$digest:$role';

  static StorageBottleMaterial? parse(
    dynamic raw,
    dynamic storeRef, {
    String mediaBaseUrl = kingclubApiBaseUrl,
  }) {
    if (raw is! Map ||
        storeRef is! String ||
        storeRef.isEmpty ||
        raw['storeRef'] != storeRef ||
        raw['version'] != 'png-contour-v1') {
      return null;
    }
    final digest = raw['sourceSha256'],
        ratio = raw['aspectRatio'],
        imageRatio = raw['imageAspectRatio'];
    if (digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        ratio is! num ||
        !ratio.isFinite ||
        ratio <= 0 ||
        imageRatio is! num ||
        !imageRatio.isFinite ||
        imageRatio <= 0) {
      return null;
    }
    final base = Uri.tryParse(mediaBaseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      return null;
    }
    final values = raw['files'];
    if (values is! Map) return null;
    final files = <String, String>{};
    for (final role in [
      'image',
      'thumbnail',
      'mask',
      'outline',
      'frame',
      'backFrame',
    ]) {
      final link = values[role];
      if (link is! String) return null;
      final uri = Uri.tryParse(link);
      if (uri == null ||
          uri.hasScheme ||
          uri.hasAuthority ||
          uri.hasFragment ||
          !RegExp(
            r'^/attachments/[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
          ).hasMatch(uri.path) ||
          uri.queryParametersAll.length != 1 ||
          uri.queryParametersAll['token']?.length != 1 ||
          (uri.queryParameters['token']?.isEmpty ?? true)) {
        return null;
      }
      files[role] = '${mediaBaseUrl.replaceFirst(RegExp(r'/+$'), '')}$link';
    }
    var bodyBounds = const Rect.fromLTWH(0, 0, 1, 1);
    final bounds = raw['bodyBounds'];
    if (bounds is Map) {
      final values = [
        'x',
        'y',
        'width',
        'height',
      ].map((k) => bounds[k]).toList();
      if (values.every((v) => v is num && v.isFinite)) {
        final b = Rect.fromLTWH(
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
          (values[2] as num).toDouble(),
          (values[3] as num).toDouble(),
        );
        if (b.left >= 0 &&
            b.top >= 0 &&
            b.width > 0 &&
            b.height > 0 &&
            b.right <= 1.000001 &&
            b.bottom <= 1.000001) {
          bodyBounds = b;
        }
      }
    }
    return StorageBottleMaterial(
      storeRef: storeRef,
      digest: digest,
      aspectRatio: ratio.toDouble(),
      imageAspectRatio: imageRatio.toDouble(),
      files: Map.unmodifiable(files),
      bodyBounds: bodyBounds,
    );
  }
}

abstract class StorageRepository {
  Future<void> removeExpired(String ref);
  Future<List<StorageItem>> list();
  Future<StorageItem> detail(String ref);
  Future<Map<String, dynamic>> issue(String ref);
}

class RealStorageRepository implements StorageRepository {
  @override
  Future<void> removeExpired(String ref) async {
    await _call('K260912000404', {'itemRef': ref});
  }

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
  PreviewStorageRepository([List<StorageItem> items = const []])
    : items = List.of(items);
  final List<StorageItem> items;
  @override
  Future<void> removeExpired(String ref) async {
    final item = await detail(ref);
    if (item.status != 'expired') throw StateError('仅可删除已过期的储物');
    items.removeWhere((i) => i.ref == ref);
  }

  @override
  Future<List<StorageItem>> list() async => items;
  @override
  Future<StorageItem> detail(String ref) async =>
      items.firstWhere((i) => i.ref == ref);
  @override
  Future<Map<String, dynamic>> issue(String ref) async =>
      throw const AuthFailure('PREVIEW_ONLY', '预览不签发提取码');
}
