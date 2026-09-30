/// Server-owned offers only. A catalog is not payment authorization.
class MemberRechargeOffer {
  const MemberRechargeOffer._(
    this.ref,
    this.revision,
    this.principalCents,
    this.giftCents,
    this.availableUntil,
    this.giftExpiresAt,
    this.description,
    this.deductionOrder,
    this.maxGiftBasisPoints,
    this.eligibleProductRefs,
  );
  final String ref, description, deductionOrder;
  final int revision, principalCents, giftCents, maxGiftBasisPoints;
  final DateTime availableUntil;
  final DateTime? giftExpiresAt;
  final List<String>? eligibleProductRefs;
}

class MemberRechargeCatalog {
  const MemberRechargeCatalog._(
    this.storeRef,
    this.storeName,
    this.snapshotAt,
    this.offers,
  );
  final String storeRef, storeName;
  final DateTime snapshotAt;
  final List<MemberRechargeOffer> offers;
  factory MemberRechargeCatalog.parse(Object? raw, {required String storeRef}) {
    final root = _object(raw, {
      'version',
      'storeRef',
      'storeName',
      'currency',
      'snapshotAt',
      'campaigns',
    });
    if (root['version'] != 1 ||
        root['currency'] != 'CNY' ||
        _ref(root['storeRef']) != storeRef) {
      throw _invalid();
    }
    final name = _text(root['storeName'], 128), at = _time(root['snapshotAt']);
    final rows = root['campaigns'];
    if (rows is! List || rows.length > 100) throw _invalid();
    final offers = <MemberRechargeOffer>[], seen = <String>{};
    for (final rawOffer in rows) {
      final row = _object(rawOffer, {
        'campaignRef',
        'campaignRevision',
        'principalCents',
        'giftCents',
        'availableUntil',
        'giftExpiresAt',
        'rulesSnapshot',
      });
      final ref = _ref(row['campaignRef']), revision = row['campaignRevision'];
      if (revision is! int ||
          revision < 1 ||
          revision > 9007199254740991 ||
          !seen.add('$ref/$revision')) {
        throw _invalid();
      }
      final principal = _cents(row['principalCents']),
          gift = _cents(row['giftCents']);
      final until = _time(row['availableUntil']),
          expiry = row['giftExpiresAt'] == null
              ? null
              : _time(row['giftExpiresAt']);
      if (principal == 0 ||
          !until.isAfter(at) ||
          (expiry != null && !expiry.isAfter(at))) {
        throw _invalid();
      }
      final rules = _object(row['rulesSnapshot'], {
        'version',
        'description',
        'deductionOrder',
        'maxGiftBasisPoints',
        'eligibleProductRefs',
      });
      final order = rules['deductionOrder'], cap = rules['maxGiftBasisPoints'];
      if (rules['version'] != 1 ||
          !['principal_first', 'gift_first'].contains(order) ||
          cap is! int ||
          cap < 0 ||
          cap > 10000) {
        throw _invalid();
      }
      final products = rules['eligibleProductRefs'];
      List<String>? refs;
      if (products != null) {
        if (products is! List || products.length > 1000) throw _invalid();
        refs = products.map(_ref).toList();
        if (refs.toSet().length != refs.length) throw _invalid();
      }
      offers.add(
        MemberRechargeOffer._(
          ref,
          revision,
          principal,
          gift,
          until,
          expiry,
          _text(rules['description'], 4000),
          order as String,
          cap,
          refs == null ? null : List.unmodifiable(refs),
        ),
      );
    }
    return MemberRechargeCatalog._(
      storeRef,
      name,
      at,
      List.unmodifiable(offers),
    );
  }
}

FormatException _invalid() => const FormatException('Invalid recharge catalog');
Map<String, dynamic> _object(Object? raw, Set<String> keys) {
  if (raw is! Map<String, dynamic> ||
      raw.length != keys.length ||
      !raw.keys.every(keys.contains)) {
    throw _invalid();
  }
  return raw;
}

String _text(Object? raw, int max) {
  if (raw is! String ||
      raw.trim().isEmpty ||
      raw.length > max ||
      RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]').hasMatch(raw)) {
    throw _invalid();
  }
  return raw;
}

String _ref(Object? raw) {
  if (raw is! String || !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(raw)) {
    throw _invalid();
  }
  return raw;
}

int _cents(Object? raw) {
  if (raw is! String || !RegExp(r'^(0|[1-9][0-9]{0,8})$').hasMatch(raw)) {
    throw _invalid();
  }
  final value = int.parse(raw);
  if (value > 100000000) throw _invalid();
  return value;
}

DateTime _time(Object? raw) {
  if (raw is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$').hasMatch(raw)) {
    throw _invalid();
  }
  final value = DateTime.tryParse(raw);
  if (value == null || value.toIso8601String() != raw) throw _invalid();
  return value;
}
