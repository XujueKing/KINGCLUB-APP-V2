import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_publication.dart';
import 'package:kingclub/src/features/club/data/together_party_draft.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/data/together_store.dart';
import 'package:kingclub/src/features/club/presentation/together_publish_confirmation_page.dart';

void main() {
  for (final official in [false, true]) {
    testWidgets(
      'publishes with correct deposit and stable retries official=$official',
      (tester) async {
        final calls = <Map<String, dynamic>>[];
        final session = <String, dynamic>{
          'account': {'userAccount': 'member'},
          'sessionId': 'session',
          'apiKeyId': 'key',
          'apiKey': 'test-key',
        };
        final service = SecureTogetherPublication(
          readSession: () async => session,
          request: (id, p, _) async {
            if (id == 'K261002001984') {
              expect(
                (p['draft'] as Map)['publisherType'],
                official ? 'official' : 'personal',
              );
              return {
                'result': {
                  'quoteRef': 'quote',
                  'totalCents': '100000',
                  'depositCents': official ? '0' : '100000',
                  'priceCents': '15000',
                  'genderPricing': {
                    'malePriceCents': '15000',
                    'femalePriceCents': '5000',
                  },
                  'expiresAt': DateTime.now()
                      .add(const Duration(minutes: 10))
                      .toIso8601String(),
                  'policyVersion': 'v1',
                },
              };
            }
            expect(id, 'K261002001982');
            calls.add(p);
            if (calls.length == 1) throw Exception('lost response');
            return {
              'result': {
                'partyRef': 'published-party',
                'frozenCents': official ? '0' : '100000',
              },
            };
          },
        );
        const artwork = TogetherArtwork(
          ref: 'art',
          name: '海报',
          url: 'https://example.test/art.png',
          status: TogetherArtworkStatus.approved,
        );
        const store = TogetherStore(
          ref: 'store',
          name: '门店',
          cityCode: '430200',
          address: '地址',
        );
        final draft = TogetherPartyDraft(
          official: official,
          theme: '活动',
          cityCode: '430200',
          store: store,
          place: '地点',
          startsAt: DateTime.now().add(const Duration(days: 3)),
          endsAt: DateTime.now().add(const Duration(days: 3, hours: 4)),
          capacity: 10,
          feeMode: TogetherFeeMode.aa,
          priceMinor: 15000,
          totalCostMinor: 100000,
          description: '说明',
          background: artwork,
          poster: artwork,
          package: const TogetherPackage(
            ref: 'package',
            storeRef: 'store',
            name: '套餐',
            baseTotalMinor: 100000,
          ),
        );
        String? published;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('发布'),
                  onPressed: () async {
                    published = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => TogetherPublishConfirmationPage(
                          draft: draft,
                          publication: service,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('发布'));
        await tester.pumpAndSettle();
        expect(
          find.text(official ? '商家官方活动 · 无需押金' : '冻结 APP 余额 ¥1,000.00'),
          findsOneWidget,
        );
        expect(find.text('男士 ¥150.00 / 位 · 女士 ¥50.00 / 位'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(calls, isEmpty);
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(published, isNull);
        expect(calls.length, 1);
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(calls[0], calls[1]);
        expect(published, 'published-party');
      },
    );
  }
}
