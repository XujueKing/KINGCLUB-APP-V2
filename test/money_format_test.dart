import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/formatters/money.dart';

void main() {
  test('money groups display and retains exact cents and negative values', () {
    expect(moneyCents(220000), '2,200.00');
    expect(moneyCents(-123456789), '-1,234,567.89');
    expect(
      moneyCents(BigInt.parse('99999999999999999999')),
      '999,999,999,999,999,999.99',
    );
    expect(moneyAmount(1000.5), '1,000.50');
    expect(moneyAmount(0.1), '0.10');
  });
}
