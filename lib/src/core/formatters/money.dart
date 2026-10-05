/// Display only: never feed grouped values into requests or amount inputs.
String groupMoney(String value) {
  final parts = value.split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.join('.');
}

String moneyCents(Object cents) {
  final n = cents is BigInt ? cents : BigInt.parse(cents.toString());
  final a = n.abs();
  return '${n.isNegative ? '-' : ''}${groupMoney('${a ~/ BigInt.from(100)}')}.${(a % BigInt.from(100)).toString().padLeft(2, '0')}';
}

String moneyAmount(num value) => groupMoney(value.toStringAsFixed(2));
