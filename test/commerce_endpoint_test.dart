import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/commerce_endpoint.dart';

void main() {
  test('commerce retains deployment prefix and does not replace auth base', () {
    expect(
      commerceEndpoint('https://example.test/kingclub-v2/'),
      'https://example.test/kingclub-v2/commerce',
    );
    expect(
      commerceEndpoint('https://example.test'),
      'https://example.test/commerce',
    );
    expect(commerceEndpoint(''), '');
    expect(
      commerceEndpoint(
        'https://example.test',
        override: 'https://commerce.example.test/',
      ),
      'https://commerce.example.test',
    );
  });
}
