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
    this.isNew = false,
    this.isRecommended = false,
    this.isHot = false,
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
  final bool isNew;
  final bool isRecommended;
  final bool isHot;
  bool get soldOut => available == 0;
  String get priceText =>
      '${priceCents ~/ 100}.${(priceCents % 100).toString().padLeft(2, '0')}';
}

class OrderingCatalog {
  const OrderingCatalog(this.context, this.categories, this.products);
  final OrderingContext context;
  final List<OrderingCatalogCategory> categories;
  final List<OrderingCatalogProduct> products;

  /// Present one package section, while retaining real product IDs and prices.
  OrderingCatalog forAppMenu() {
    const packageNames = {'套餐', '活动套餐', '精选套餐'};
    final aliases = <String, String>{};
    final result = <OrderingCatalogCategory>[];
    String? packageRef;
    for (final category in categories) {
      if (category.majorCategory == 'liquor' &&
          packageNames.contains(category.names['zh-CN'])) {
        packageRef ??= category.reference;
        aliases[category.reference] = packageRef;
        if (category.reference != packageRef) continue;
        result.add(
          OrderingCatalogCategory(packageRef, 'liquor', const {
            'zh-CN': '套餐',
            'zh-TW': '套餐',
            'en': 'Packages',
            'th': 'แพ็กเกจ',
          }),
        );
      } else {
        result.add(category);
      }
    }
    final liquorRefs = categories
        .where((c) => c.majorCategory == 'liquor')
        .map((c) => c.reference)
        .toSet();
    final tagged = <OrderingCatalogProduct>[];
    for (final tag in ['new', 'recommended']) {
      final selected = products
          .where(
            (p) =>
                liquorRefs.contains(p.categoryRef) &&
                (tag == 'new' ? p.isNew : p.isRecommended),
          )
          .toList();
      if (selected.isEmpty) continue;
      final name = tag == 'new' ? '新品' : '推荐';
      final existing = result
          .where((c) => c.majorCategory == 'liquor' && c.names['zh-CN'] == name)
          .firstOrNull;
      final ref = existing?.reference ?? '__app_$tag';
      if (existing == null) {
        result.add(
          OrderingCatalogCategory(
            ref,
            'liquor',
            tag == 'new'
                ? const {
                    'zh-CN': '新品',
                    'zh-TW': '新品',
                    'en': 'New',
                    'th': 'สินค้าใหม่',
                  }
                : const {
                    'zh-CN': '推荐',
                    'zh-TW': '推薦',
                    'en': 'Recommended',
                    'th': 'แนะนำ',
                  },
          ),
        );
      }
      for (final p in selected) {
        if (p.categoryRef == ref) continue;
        tagged.add(
          OrderingCatalogProduct(
            p.reference,
            ref,
            p.names,
            p.specifications,
            p.priceCents,
            p.revision,
            p.available,
            thumbnailUrl: p.thumbnailUrl,
            imageCacheKey: p.imageCacheKey,
            isNew: p.isNew,
            isRecommended: p.isRecommended,
            isHot: p.isHot,
          ),
        );
      }
    }
    int rank(OrderingCatalogCategory c) => c.majorCategory != 'liquor'
        ? 4
        : switch (c.names['zh-CN']) {
            '新品' => 0,
            '推荐' => 1,
            '套餐' => 2,
            _ => 3,
          };
    final originalOrder = {
      for (var i = 0; i < result.length; i++) result[i].reference: i,
    };
    result.sort((a, b) {
      final priority = rank(a).compareTo(rank(b));
      return priority != 0
          ? priority
          : originalOrder[a.reference]!.compareTo(originalOrder[b.reference]!);
    });
    final order = {
      for (var i = 0; i < result.length; i++) result[i].reference: i,
    };
    final mapped = [
      ...products.map(
        (p) => OrderingCatalogProduct(
          p.reference,
          aliases[p.categoryRef] ?? p.categoryRef,
          p.names,
          p.specifications,
          p.priceCents,
          p.revision,
          p.available,
          thumbnailUrl: p.thumbnailUrl,
          imageCacheKey: p.imageCacheKey,
          isNew: p.isNew,
          isRecommended: p.isRecommended,
          isHot: p.isHot,
        ),
      ),
      ...tagged,
    ];
    final productOrder = {
      for (var i = 0; i < products.length; i++) products[i].reference: i,
    };
    mapped.sort((a, b) {
      final priority = order[a.categoryRef]!.compareTo(order[b.categoryRef]!);
      return priority != 0
          ? priority
          : productOrder[a.reference]!.compareTo(productOrder[b.reference]!);
    });
    return OrderingCatalog(context, result, mapped);
  }
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
      for (final field in ['isNew', 'isRecommended', 'isHot']) {
        if (row[field] != null && row[field] is! bool) _invalid();
      }
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
          isNew: row['isNew'] == true,
          isRecommended: row['isRecommended'] == true,
          isHot: row['isHot'] == true,
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
