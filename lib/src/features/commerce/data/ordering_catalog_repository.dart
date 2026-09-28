import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_context.dart';
import 'ordering_table_repository.dart';

class OrderingCatalogCategory {
  const OrderingCatalogCategory(this.reference, this.majorCategory, this.names);
  final String reference;
  final String majorCategory;
  final Map<String, String> names;
}

class OrderingCatalogProduct {
  const OrderingCatalogProduct(
    this.reference,
    this.categoryRef,
    this.names,
    this.specifications,
    this.priceCents,
    this.revision,
    this.available, {
    this.thumbnailUrl,
    this.imageCacheKey,
  });
  final String reference;
  final String categoryRef;
  final Map<String, String> names;
  final Map<String, String> specifications;
  final int priceCents;
  final int revision;
  final int available;
  final String? thumbnailUrl;
  final String? imageCacheKey;
  bool get soldOut => available == 0;
  String get priceText =>
      '${priceCents ~/ 100}.${(priceCents % 100).toString().padLeft(2, '0')}';
}

class OrderingCatalog {
  const OrderingCatalog(this.context, this.categories, this.products);
  final OrderingContext context;
  final List<OrderingCatalogCategory> categories;
  final List<OrderingCatalogProduct> products;
}

class OrderingCatalogRepository {
  OrderingCatalogRepository({
    required this.readSession,
    required this.request,
    this.mediaBaseUrl,
  });
  factory OrderingCatalogRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return OrderingCatalogRepository(
      mediaBaseUrl: baseUrl,
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final String? mediaBaseUrl;
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  static final _ref = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _sessionReference = RegExp(
    r'^(?:H[0-9]{11}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
  );
  static Never _invalid() =>
      throw const AuthFailure('CATALOG_RESPONSE_INVALID', '商品资料异常，请刷新');
  static Map _map(dynamic value) {
    if (value is! Map) _invalid();
    return value;
  }

  static String _id(dynamic value) {
    if (value is! String || !_ref.hasMatch(value)) _invalid();
    return value;
  }

  static int _integer(dynamic value, int min, int max) {
    if (value is! int || value < min || value > max) _invalid();
    return value;
  }

  static Map<String, String> _names(dynamic value) {
    final map = _map(value), output = <String, String>{};
    for (final locale in ['zh-CN', 'zh-TW', 'en', 'th']) {
      final name = map[locale];
      if (name is! String || name.trim().isEmpty || name.length > 128) {
        _invalid();
      }
      output[locale] = name;
    }
    return Map.unmodifiable(output);
  }

  static List<String>? _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final values = [
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
      account is Map ? account['userAccount'] : null,
    ];
    if (values.any((value) => value is! String || value.isEmpty)) return null;
    return values.cast<String>();
  }

  (String, String)? _image(dynamic raw, String storeRef) {
    if (raw == null) return null;
    final material = _map(raw);
    if (material['storeRef'] != storeRef) _invalid();
    final digest = material['sourceSha256'];
    final version = material['version'];
    if (digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
        version != 'png-contour-v1') {
      _invalid();
    }
    final link = _map(material['files'])['thumbnail'];
    if (link is! String) _invalid();
    final uri = Uri.tryParse(link);
    final base = Uri.tryParse(mediaBaseUrl ?? '');
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasFragment ||
        !RegExp(r'^/attachments/[a-fA-F0-9-]{36}$').hasMatch(uri.path) ||
        !_uuid.hasMatch(uri.pathSegments.last) ||
        uri.queryParametersAll.length != 1 ||
        uri.queryParametersAll['token']?.length != 1 ||
        (uri.queryParameters['token']?.isEmpty ?? true) ||
        base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      _invalid();
    }
    final root = mediaBaseUrl!.replaceFirst(RegExp(r'/+$'), '');
    return ('$root$link', 'bottle:$storeRef:$version:$digest:thumbnail');
  }

  Future<OrderingCatalog> read(OrderingContext context) async {
    if (context.tableId == null ||
        !_ref.hasMatch(context.tableId!) ||
        !_sessionReference.hasMatch(context.tableSessionRef)) {
      _invalid();
    }
    final session = await readSession(), before = <String>[];
    final identity = _identity(session);
    if (identity == null || identity.last != context.memberRef) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    before.addAll(identity);
    final response = await request('K260919000809', {
      'tableId': context.tableId,
      'tableSessionRef': context.tableSessionRef,
    }, session!);
    final after = _identity(await readSession());
    if (after == null ||
        List.generate(
          before.length,
          (i) => before[i] != after[i],
        ).any((changed) => changed)) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变更，请重新扫码');
    }
    final result = _map(response['result']), scope = _map(result['context']);
    final expected = {
      'tableId': context.tableId,
      'contextRef': context.contextRef,
      'memberRef': context.memberRef,
      'storeRef': context.storeRef,
      'tenantRef': context.tenantRef,
      'brandRef': context.brandRef,
      'cityId': context.cityId,
      'tableSessionRef': context.tableSessionRef,
      'businessDate': context.businessDate,
      'currency': context.currency,
      'timeZone': context.timeZone,
      'paymentTiming': context.paymentTiming,
    };
    if (expected.entries.any(
      (entry) => entry.value == null || scope[entry.key] != entry.value,
    )) {
      throw const AuthFailure('ORDERING_SESSION_CHANGED', '桌台信息已变化，请重新扫码');
    }
    final rawCategories = result['categories'],
        rawProducts = result['products'];
    if (rawCategories is! List ||
        rawProducts is! List ||
        rawCategories.length > 100 ||
        rawProducts.length > 500) {
      _invalid();
    }
    final categories = <OrderingCatalogCategory>[],
        products = <OrderingCatalogProduct>[];
    final categoryIds = <String>{}, productIds = <String>{};
    for (final raw in rawCategories) {
      final row = _map(raw),
          id = _id(row['categoryRef']),
          major = row['majorCategory'];
      if (!categoryIds.add(id) ||
          !['liquor', 'drinks', 'snacks'].contains(major)) {
        _invalid();
      }
      categories.add(
        OrderingCatalogCategory(id, major as String, _names(row['names'])),
      );
    }
    for (final raw in rawProducts) {
      final row = _map(raw),
          id = _id(row['productRef']),
          category = _id(row['categoryRef']);
      if (!productIds.add(id) || !categoryIds.contains(category)) _invalid();
      final available = _integer(row['available'], 0, 4294967295);
      if (row['soldOut'] is! bool || row['soldOut'] != (available == 0)) {
        _invalid();
      }
      final image = _image(row['bottleMaterial'], context.storeRef);
      products.add(
        OrderingCatalogProduct(
          id,
          category,
          _names(row['names']),
          _names(row['specifications']),
          _integer(row['priceCents'], 1, 100000000),
          _integer(row['revision'], 1, 1000001),
          available,
          thumbnailUrl: image?.$1,
          imageCacheKey: image?.$2,
        ),
      );
    }
    return OrderingCatalog(
      context,
      List.unmodifiable(categories),
      List.unmodifiable(products),
    );
  }
}
