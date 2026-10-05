/// Display only: never feed grouped values into requests or amount inputs.
String groupMoney(String value) {
  final parts = value.split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.join('.');
}

/// Exact display of integer asset units. Precision comes from the asset
/// contract; never infer it from a ticker or convert units through double.
String moneyUnits(Object units, {required int precision}) {
  if (precision < 0 || precision > 36) {
    throw RangeError.range(precision, 0, 36, 'precision');
  }
  if (units is! BigInt && units is! int && units is! String) {
    throw const FormatException('Asset units must be an exact integer');
  }
  final text = units.toString();
  if (!RegExp(r'^-?(0|[1-9][0-9]*)$').hasMatch(text)) {
    throw const FormatException('Invalid integer asset units');
  }
  final n = units is BigInt ? units : BigInt.parse(text);
  final a = n.abs(), scale = BigInt.from(10).pow(precision);
  final whole = '${n.isNegative ? '-' : ''}${groupMoney('${a ~/ scale}')}';
  if (precision == 0) return whole;
  return '$whole.${(a % scale).toString().padLeft(precision, '0')}';
}

String moneyCents(Object cents) => moneyUnits(cents, precision: 2);

String moneyAmount(num value) => groupMoney(value.toStringAsFixed(2));
