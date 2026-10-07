import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/procurement_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/procurement_page.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

void main() {
  test(
    'changed member session cannot accept an earlier procurement response',
    () async {
      var session = {
        'sessionId': 's',
        'apiKeyId': 'k',
        'apiKey': 'private-test-key',
        'account': {'userAccount': 'test-user'},
      };
      final repository = ProcurementRepository(
        readSession: () async => session,
        request: (id, p, s) async {
          session = {...session, 'sessionId': 'other-session'};
          return {
            'result': {'storeRef': 'store'},
          };
        },
      );
      await expectLater(
        repository.call({'action': 'context', 'storeRef': 'store'}),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test('rejects another store response', () async {
    final repository = ProcurementRepository(
      readSession: () async => {
        'sessionId': 's',
        'apiKeyId': 'k',
        'apiKey': 'test-key',
        'account': {'userAccount': 'user'},
      },
      request: (id, p, s) async => {
        'result': {'storeRef': 'other'},
      },
    );
    await expectLater(
      repository.call({'action': 'context', 'storeRef': 'store'}),
      throwsA(isA<AuthFailure>()),
    );
  });
  for (final owner in [true, false]) {
    testWidgets(
      'only an owner sees approval actions, touch layout owner=$owner',
      (tester) async {
        final requests = <Map<String, dynamic>>[];
        var status = 'pending', revision = 2;
        Map<String, dynamic> batch() => {
          'storeRef': 'store',
          'batchRef': 'batch',
          'batchNumber': 'CG20261007-1',
          'applicationNumber': 'SQ20261007-1',
          'title': 'Weekly purchase',
          'status': status,
          'revision': revision,
          'items': [
            {
              'productRef': 'wine',
              'supplierRef': 'supplier',
              'supplierName': 'Supplier',
              'names': {'en': 'Wine'},
              'quantity': 2,
              'unitCostCents': 3500,
              'received': 0,
              'locations': [],
            },
          ],
        };
        Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
          requests.add(p);
          if (p['action'] == 'context')
            return {
              'storeRef': 'store',
              'permissions': [owner ? 'cashbook.review' : 'purchase.buy'],
              'stores': [
                {'storeRef': 'store', 'name': 'Store'},
              ],
              'batches': [
                {
                  ...batch(),
                  'rowId': 1,
                  'itemCount': 1,
                  'totalCostCents': 7000,
                },
              ],
            };
          if (p['action'] == 'purchase_batch') return batch();
          status = 'approved';
          revision++;
          return {
            'storeRef': 'store',
            'receipt': {'batch': batch()},
          };
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: ProcurementPage(call: call),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weekly purchase'));
        await tester.pumpAndSettle();
        expect(find.text('Approve'), owner ? findsOneWidget : findsNothing);
        expect(find.text('Confirm purchased'), findsNothing);
        if (owner) {
          await tester.tap(find.text('Approve'));
          await tester.pumpAndSettle();
          expect(
            requests.last,
            containsPair('action', 'purchase_batch_review'),
          );
          expect(requests.last, containsPair('revision', 2));
          expect(find.text('Confirm purchased'), findsOneWidget);
          expect(find.text('Wine '), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
