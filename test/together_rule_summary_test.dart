import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_rule_summary.dart';

void main() {
  test(
    'no restriction stays empty and score zero is an explicit requirement',
    () {
      expect(togetherRuleSummary({}), '');
      expect(togetherRuleSummary({'minimumMaleScore': 0}), '男士颜值0分起');
    },
  );
  test('invalid requirements cannot become apparently unrestricted', () {
    for (final rules in [
      {'minAge': 40, 'maxAge': 20},
      {'overageCentsPerYear': '1000'},
      {'minimumMaleScore': double.nan},
      {'minimumFemaleScore': 101},
      {
        'excludedStarSigns': ['invalid'],
      },
    ]) {
      expect(() => togetherRuleSummary(rules), throwsFormatException);
    }
  });
}
