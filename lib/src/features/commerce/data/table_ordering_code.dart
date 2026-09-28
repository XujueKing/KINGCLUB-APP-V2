/// A legacy table-card locator, not authorization or verified venue data.
class TableOrderingCode {
  const TableOrderingCode({
    required this.tableId,
    this.legacyShopId,
    this.barId,
    this.cityId,
    this.tableName,
  });

  final String tableId;
  final String? legacyShopId;
  final String? barId;
  final String? cityId;
  final String? tableName;

  /// Table ID selects the record; optional tableName is an unverified UI label.
  /// Venue/city come from lookup.
  String get orderingLocation => Uri(
    path: '/commerce/ordering',
    queryParameters: {
      'tableId': tableId,
      'tableName': ?tableName,
    },
  ).toString();

  /// Supports legacy type=9 links, including a once-encoded whole URL.
  /// No navigation or network requests are performed by this parser.
  static TableOrderingCode? tryParse(String raw) {
    if (raw.length > 4096) return null;
    try {
      var text = raw.trim();
      if (!text.contains('=') && text.contains('%')) {
        text = Uri.decodeComponent(text);
      }
      final uri = Uri.tryParse(text);
      if (uri == null || uri.hasFragment) return null;
      if (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http') {
        return null;
      }
      // Also accept a query-only payload printed by a card generator.
      final query = uri.hasQuery ? uri.query : (uri.hasScheme ? '' : text);
      if (query.isEmpty || RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(query)) {
        return null;
      }
      final values = Uri(query: query).queryParametersAll;
      const keys = [
        'type',
        'tableId',
        'tableld',
        'shopId',
        'shopld',
        'barId',
        'cityId',
        'tableName',
      ];
      if (keys.any((key) => (values[key]?.length ?? 0) > 1)) return null;
      if (values['type']?.single != '9') return null;
      String? read(String key) {
        final value = values[key]?.single;
        if (value == null) return null;
        if (value.trim().isEmpty ||
            value.length > 128 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
          throw const FormatException('Invalid table locator field');
        }
        return value;
      }

      String? readAlias(String canonical, String legacy) {
        final primary = read(canonical);
        final alias = read(legacy);
        if (primary != null && alias != null && primary != alias) {
          throw const FormatException('Conflicting table locator aliases');
        }
        return primary ?? alias;
      }

      // Existing printed cards use lowercase l, not uppercase I, in "ld".
      final tableId = readAlias('tableId', 'tableld');
      if (tableId == null) return null;
      return TableOrderingCode(
        tableId: tableId,
        legacyShopId: readAlias('shopId', 'shopld'),
        barId: read('barId'),
        cityId: read('cityId'),
        tableName: read('tableName'),
      );
    } on FormatException {
      return null;
    }
  }
}
