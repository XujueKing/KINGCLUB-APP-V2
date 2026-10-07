import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_keyboard_dismiss.dart';
import 'package:kingclub/src/features/partners/presentation/partner_notice_destination.dart';
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
            theme: ThemeData.dark(),
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
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
