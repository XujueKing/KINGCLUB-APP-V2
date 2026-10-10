import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/product_listing_page.dart';

void main() {
  testWidgets(
    'phone review is visible only for the trusted superadministrator and uses one action response',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      var superadmin = false;
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
        calls.add(p);
        return {
          'storeRef': 'test-store',
          'listingPermissions': {
            'submit': true,
            'direct': superadmin,
            'review': superadmin,
          },
          'products': [
            {
              'productRef': 'sku',
              'names': {'en': 'Test product'},
              'specifications': {'en': '500ml'},
              'listed': true,
              'revision': 1,
            },
          ],
          if (p['action'] == 'listing_context')
            'requests': [
              {
                'applicationRef': '00000000-0000-4000-8000-000000000001',
                'productRef': 'sku',
                'listed': false,
                'status': 'pending',
              },
            ]
          else
            'listingRequests': [],
        };
      }

      Widget page() => MaterialApp(home: ProductListingPage(call: call));
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('Approve'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      superadmin = true;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(calls.last['action'], 'review_listing');
      expect(calls.last['approved'], true);
      expect(
        calls.where((c) => c['action'] == 'listing_context'),
        hasLength(2),
      );
      expect(find.text('No pending applications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
