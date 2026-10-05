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
  test(
    'asset precision is explicit and never rounds through floating point',
    () {
      expect(moneyUnits('1234567', precision: 0), '1,234,567');
      expect(moneyUnits('1234567890', precision: 6), '1,234.567890');
      expect(moneyUnits('1', precision: 8), '0.00000001');
      expect(
        moneyUnits('1000000000000000001', precision: 18),
        '1.000000000000000001',
      );
      expect(moneyUnits('-1', precision: 18), '-0.000000000000000001');
      expect(() => moneyUnits(1.5, precision: 2), throwsFormatException);
      expect(() => moneyUnits('1.5', precision: 2), throwsFormatException);
      expect(() => moneyUnits('1', precision: 37), throwsRangeError);
    },
  );
}
