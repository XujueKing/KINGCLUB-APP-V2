import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_keyboard_dismiss.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/partners/presentation/partner_notice_destination.dart';
import 'package:kingclub/src/features/partners/presentation/partner_platform_page.dart';
import 'package:kingclub/src/features/partners/data/partner_repository.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_repository.dart';

const reference = 'b5b04542-8151-4e28-9983-616e243adf61';
void main() {
  test(
    'application card retains its review destination and no invented amount',
    () {
      final notice = SystemNotice.parse({
        'noticeRef': 'a' * 64,
        'kind': 'partner_application',
        'occurredAt': '2030-01-01T00:00:00.000Z',
        'read': false,
        'amountCents': null,
        'details': [
          {'label': 'applicant', 'value': 'Test'},
          {'label': 'city', 'value': 'City'},
        ],
        'target': {'kind': 'partner', 'reference': 'application:$reference'},
      });
      expect(notice.amountCents, isNull);
      expect(notice.target!['reference'], 'application:$reference');
    },
  );
  for (final status in ['pending', 'approved', 'rejected']) {
    testWidgets(
      'notice opens current $status application and gates review controls',
      (tester) async {
        final requests = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: kingLocalizationDelegates,
            supportedLocales: kingSupportedLocales,
            theme: KingTheme.dark,
            builder: (_, child) => KingKeyboardDismiss(child: child!),
            home: partnerNoticeDestination(
              'application:$reference',
              call: (p) async {
                requests.add(p);
                return {
                  'item': {
                    'ref': reference,
                    'name': 'Test applicant',
                    'city': 'City',
                    'introduction': 'Experience',
                    'directions': ['organize'],
                    'status': status,
                    'reason': 'Review notes',
                    'referrer': {
                      'memberId': 'KM123',
                      'name': 'Test referrer',
                      'level': 7,
                    },
                  },
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests, [
          {'action': 'application', 'applicationRef': reference},
        ]);
        expect(find.text('Test applicant'), findsOneWidget);
        expect(find.textContaining('Test referrer'), findsOneWidget);
        expect(
          find.byType(TextField),
          status == 'pending' ? findsOneWidget : findsNothing,
        );
        if (status != 'pending') {
          expect(find.text('Review notes'), findsOneWidget);
        } else {
          await tester.ensureVisible(
            find.byKey(const ValueKey('partner-review-reject')),
          );
          final approve = tester.getRect(
            find.widgetWithText(FilledButton, '通过'),
          );
          final reject = tester.getRect(
            find.byKey(const ValueKey('partner-review-reject')),
          );
          expect(reject.height, approve.height);
          expect(reject.width, approve.width);
          expect(reject.top - approve.bottom, greaterThanOrEqualTo(32));
          expect(find.widgetWithText(OutlinedButton, '拒绝'), findsOneWidget);
          RoundedRectangleBorder renderedShape(Finder button) {
            final material = tester.widget<Material>(
              find
                  .descendant(of: button, matching: find.byType(Material))
                  .first,
            );
            return material.shape! as RoundedRectangleBorder;
          }

          final approveShape = renderedShape(
            find.widgetWithText(FilledButton, '通过'),
          );
          final rejectShape = renderedShape(
            find.byKey(const ValueKey('partner-review-reject')),
          );
          expect(rejectShape.borderRadius, approveShape.borderRadius);
          expect(
            approveShape.borderRadius,
            const BorderRadius.all(Radius.circular(12)),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'approve with blank note submits once and returns after success',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      final result = Completer<Map<String, dynamic>>();
      await openReview(tester, (p) {
        requests.add(Map.of(p));
        return result.future;
      });
      final approve = find.widgetWithText(FilledButton, '通过');
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(requests.single['decision'], 'approved');
      expect(requests.single['reason'], '审核通过');
      expect(requests.single['applicationRef'], reference);
      final submitting = find.widgetWithText(FilledButton, '正在提交…');
      expect(tester.widget<FilledButton>(submitting).onPressed, isNull);
      await tester.tap(submitting);
      expect(requests, hasLength(1));
      result.complete({});
      await tester.pumpAndSettle();
      expect(find.text('打开审核'), findsOneWidget);
      expect(find.byType(PartnerApplicationReviewForm), findsNothing);
    },
  );

  testWidgets('reject explains missing note and submits the entered reason', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    await openReview(tester, (p) async {
      requests.add(Map.of(p));
      return {};
    });
    final reject = find.byKey(const ValueKey('partner-review-reject'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('请填写拒绝原因'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('partner-review-reason')),
      '  资料不完整  ',
    );
    await tester.pumpAndSettle();
    expect(find.text('请填写拒绝原因'), findsNothing);
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(requests.single['decision'], 'rejected');
    expect(requests.single['reason'], '资料不完整');
    expect(find.text('打开审核'), findsOneWidget);
  });

  testWidgets(
    'uncertain approval retries the same request and shows feedback',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await openReview(tester, (p) async {
        requests.add(Map.of(p));
        if (requests.length == 1) throw StateError('timeout');
        return {};
      });
      await tester.enterText(
        find.byKey(const ValueKey('partner-review-reason')),
        '  资料已核实  ',
      );
      final approve = find.widgetWithText(FilledButton, '通过');
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(find.text('未确认操作结果，请重试原请求'), findsOneWidget);
      expect(requests.single['reason'], '资料已核实');
      expect(find.byKey(const ValueKey('partner-review-reject')), findsNothing);
      final retry = find.widgetWithText(FilledButton, '重试');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last, requests.first);
      expect(find.text('打开审核'), findsOneWidget);
    },
  );
}

Future<void> openReview(WidgetTester tester, PartnerCall call) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: kingLocalizationDelegates,
      supportedLocales: kingSupportedLocales,
      theme: KingTheme.dark,
      builder: (_, child) => KingKeyboardDismiss(child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PartnerApplicationReviewForm(
                  item: const {
                    'ref': reference,
                    'name': 'Test applicant',
                    'city': 'City',
                    'introduction': 'Experience',
                    'directions': ['organize'],
                    'status': 'pending',
                  },
                  call: call,
                ),
              ),
            ),
            child: const Text('打开审核'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开审核'));
  await tester.pumpAndSettle();
}
