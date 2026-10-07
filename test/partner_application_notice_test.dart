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
        expect(
          find.byType(TextField),
          status == 'pending' ? findsNWidgets(2) : findsNothing,
        );
        if (status != 'pending') {
          expect(find.text('Review notes'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
