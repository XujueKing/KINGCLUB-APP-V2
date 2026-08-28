import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/navigation/app_router.dart';

void main() {
  test('profile and settings typed routes stay contract-aligned', () {
    expect(const PersonalQrRoute().location, '/me/qr');
    expect(const SettingsRoute().location, '/me/settings');
    expect(
      const PaymentSecurityRoute().location,
      '/me/settings/payment-security',
    );
    expect(
      const AccountDeletionRoute().location,
      '/me/settings/delete-account',
    );
    expect(const AboutLegalRoute().location, '/me/settings/about');
  });
}
