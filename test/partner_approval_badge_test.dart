import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_controller.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_repository.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets(
    'server approval unread count drives both badges and only approved acknowledgement clears them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var approvedUnread = 1;
      final calls = <Map<String, dynamic>>[];
      final controller = SystemNoticesController(
        SystemNoticesRepository(
          readSession: () async => {
            'sessionId': 'test',
            'apiKeyId': 'key',
            'apiKey': 'secret',
            'account': {'userAccount': 'synthetic'},
          },
          request: (_, p, _) async {
            calls.add(p);
            if (p['partnerApproval'] == 1) approvedUnread = 0;
            return {
              'result': {
                'unreadCount': 2,
                'partnerApprovalUnreadCount': approvedUnread,
                'highWaterSequence': '2',
                'notices': [],
                'nextBeforeNotice': null,
                'latest': {
                  'noticeRef': 'a' * 64,
                  'kind': 'partner_application_result',
                  'occurredAt': '2030-01-01T00:00:00.000Z',
                  'read': false,
                  'amountCents': null,
                  'details': [],
                  'target': {
                    'kind': 'partner',
                    'reference': 'platform:approved',
                  },
                },
              },
            };
          },
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AppShellPage(
            initialIndex: 4,
            realChat: true,
            systemNotices: controller,
            onOpenScanner: (_, _) async => null,
            onOpenTogether: () {},
            onOpenParty: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shell-profile-unread-dot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('my-profile-partner-unread-dot')),
        findsOneWidget,
      );
      tester
          .widget<MyProfilePage>(find.byType(MyProfilePage))
          .onPartnerViewed!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shell-profile-unread-dot')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('my-profile-partner-unread-dot')),
        findsNothing,
      );
      expect(controller.summary.unreadCount, 2);
      expect(calls.where((p) => p['partnerApproval'] == 1).single, {
        'partnerNotices': 1,
        'applicationNotices': 1,
        'partnerApproval': 1,
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}
