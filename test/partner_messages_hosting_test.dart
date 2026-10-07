import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/partners/data/partner_repository.dart';
import 'package:kingclub/src/features/partners/presentation/partner_dashboard.dart';
import 'package:kingclub/src/features/partners/presentation/partner_messages_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_tasks_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_platform_page.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_controller.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_repository.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

Widget app(Widget home) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  home: home,
);
Map<String, dynamic> contextData() => {
  'partner': {'status': 'active', 'level': 5, 'organizerBps': 1000},
  'profile': {'name': 'Synthetic name'},
  'stores': [],
  'teamCount': 0,
  'customerCount': 0,
  'messageUnreadCount': 1,
};
Map<String, dynamic> message({bool read = false}) => {
  'noticeRef': 'a' * 64,
  'kind': 'partner_message',
  'occurredAt': '2030-01-01T00:00:00.000Z',
  'read': read,
  'amountCents': null,
  'details': [
    {
      'label': 'title',
      'value': {
        'zh-CN': '测试通知',
        'en': 'Test notice',
        'zh-TW': '測試通知',
        'th': 'ทดสอบ',
      },
    },
    {
      'label': 'content',
      'value': {
        'zh-CN': '通知的完整内容',
        'en': 'Complete content',
        'zh-TW': '完整內容',
        'th': 'เนื้อหา',
      },
    },
  ],
  'target': {'kind': 'partner', 'reference': 'messages'},
};
void main() {
  testWidgets(
    'identity reuses supplied avatar at 60 and shows compact level without commission',
    (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: PartnerIdentityHeader(
              data: PartnerContext(contextData()),
              avatarPath: 'assets/legacy/messaging/notification_kingclub.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClipOval)), const Size(60, 60));
      expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
      expect(find.textContaining('带局提成'), findsNothing);
      expect(find.text('合作等级 L5'), findsOneWidget);
      final gap =
          tester.getTopLeft(find.text('合作等级 L5')).dy -
          tester.getBottomLeft(find.text('Synthetic name')).dy;
      expect(gap, lessThanOrEqualTo(4));
    },
  );
  testWidgets(
    'platform shows unread bell and does not acknowledge messages merely by opening',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerPlatformPage(
            call: (p) async {
              calls.add(p);
              return contextData();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('partner-message-dot')), findsOneWidget);
      expect(calls.map((p) => p['action']), ['context']);
      expect(find.text('任务大厅'), findsOneWidget);
    },
  );
  testWidgets(
    'partner inbox acknowledges only clicked notice and shows full message',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerMessagesPage(
            call: (p) async {
              calls.add(p);
              return {
                'items': [message(read: p['action'] == 'messages_read')],
                'canPublish': true,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.tap(find.text('测试通知'));
      await tester.pumpAndSettle();
      expect(calls.last['action'], 'messages_read');
      expect(calls.last['noticeRefs'], ['a' * 64]);
      expect(find.text('通知的完整内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hosting task uses consumption reward and automatic completion, without manual evidence',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          PartnerTasksPage(
            taskRef: 'task',
            call: (_) async => {
              'task': {
                'kind': 'organize',
                'title': '带局任务',
                'description': 'Synthetic hosting rules',
                'minimumCents': '0',
                'maximumCents': '0',
                'status': 'published',
                'available': true,
                'endsAt': '2030-01-01',
              },
              'claim': {
                'ref': 'claim',
                'status': 'claimed',
                'reason': '',
                'earnedCents': '123456',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('有效消费的6%–20%（按合作等级）'), findsOneWidget);
      expect(find.text('任务已获收益 ¥1,234.56'), findsOneWidget);
      expect(find.text('提交验收'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('取消本次领取'), findsOneWidget);
    },
  );
  testWidgets(
    'announcements drive profile and cooperation dots independently of approval',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final inbox = SystemNoticesController(
        SystemNoticesRepository(
          readSession: () async => {
            'sessionId': 'test',
            'apiKeyId': 'key',
            'apiKey': 'synthetic',
            'account': {'userAccount': 'synthetic'},
          },
          request: (_, p, s) async => {
            'result': {
              'unreadCount': 1,
              'partnerUnreadCount': 1,
              'partnerApprovalUnreadCount': 0,
              'highWaterSequence': '1',
              'latest': message(),
              'notices': [message()],
              'nextBeforeNotice': null,
            },
          },
        ),
      );
      addTearDown(inbox.dispose);
      await tester.pumpWidget(
        app(
          AppShellPage(
            initialIndex: 4,
            realChat: true,
            systemNotices: inbox,
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
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('new announcement emits exactly one foreground arrival across duplicate refreshes', () async {
    var rows = <Map<String, dynamic>>[];
    final arrivals = <SystemNotice>[];
    final sub = SystemNoticesController.arrivals.listen(
      (e) => arrivals.add(e.notice),
    );
    addTearDown(sub.cancel);
    final inbox = SystemNoticesController(
      SystemNoticesRepository(
        readSession: () async => {
          'sessionId': 'test',
          'apiKeyId': 'key',
          'apiKey': 'synthetic',
          'account': {'userAccount': 'synthetic'},
        },
        request: (_, p, s) async => {
          'result': {
            'unreadCount': rows.length,
            'partnerUnreadCount': rows.length,
            'highWaterSequence': rows.isEmpty ? null : '1',
            'latest': rows.isEmpty ? null : rows.first,
            'notices': rows,
            'nextBeforeNotice': null,
          },
        },
      ),
    );
    addTearDown(inbox.dispose);
    await inbox.refresh();
    rows = [message()];
    await inbox.refresh();
    await inbox.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(arrivals.map((n) => n.kind), ['partner_message']);
    expect(inbox.summary.partnerUnreadCount, 1);
  });
  testWidgets(
    'publishing requires all four languages and retries the same unknown request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerMessageComposer(
            call: (p) async {
              calls.add(Map.of(p));
              throw Exception('unknown');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '发布消息'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      for (var i = 0; i < 4; i++) {
        if (i > 0) {
          await tester.tap(find.byType(DropdownButton<int>));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(['简体中文', 'English', '繁體中文', 'ไทย'][i]).last,
          );
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byKey(ValueKey('message-title-$i')),
          'Synthetic title $i',
        );
        await tester.enterText(
          find.byKey(ValueKey('message-content-$i')),
          'Synthetic content $i',
        );
      }
      await tester.tap(find.widgetWithText(FilledButton, '发布消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '重试'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[0], calls[1]);
      expect((calls[0]['contents'] as Map).length, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
