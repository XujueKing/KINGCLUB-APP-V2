import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_controller.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/system_notifications_page.dart';

Map<String, dynamic> session(String member) => {
  'sessionId': 'test-session-$member',
  'apiKeyId': 'test-key',
  'apiKey': 'test-secret',
  'account': {'userAccount': member},
};
String id(int i) => i.toRadixString(16).padLeft(64, '0');
Map<String, dynamic> notice(int i, {bool read = false}) => {
  'noticeRef': id(i),
  'kind': 'purchase_paid',
  'occurredAt': '2030-01-01T12:${i.toString().padLeft(2, '0')}:00.000Z',
  'read': read,
  'amountCents': 38800,
  'details': [
    {'label': 'store', 'value': 'Test store'},
    {'label': 'order', 'value': 'test-order'},
  ],
  'target': {'kind': 'order', 'reference': 'test-order'},
};
Map<String, dynamic> page(
  List<Map<String, dynamic>> notices, {
  String? next,
  int? unread,
}) => {
  'notices': notices,
  'nextBeforeNotice': next,
  'unreadCount': unread ?? notices.where((n) => n['read'] == false).length,
  'highWaterSequence': notices.isEmpty ? null : '22',
  'latest': notices.isEmpty ? null : notices.first,
};

void main() {
  test(
    'uses authenticated list only, rejecting late results after account change',
    () async {
      var current = session('one');
      final pending = Completer<Map<String, dynamic>>();
      final repository = SystemNoticesRepository(
        readSession: () async => current,
        request: (api, params, s) {
          expect(api, 'K261002001960');
          expect(params, {});
          expect(s, current);
          return pending.future;
        },
      );
      final future = repository.list();
      await Future<void>.delayed(Duration.zero);
      current = session('two');
      pending.complete({
        'result': page([notice(1)]),
      });
      await expectLater(future, throwsA(anything));
    },
  );
  test('validates server data and read selectors before using them', () async {
    final repository = SystemNoticesRepository(
      readSession: () async => session('one'),
      request: (api, p, s) async => {
        'result': page([notice(1), notice(1)]),
      },
    );
    await expectLater(repository.list(), throwsA(anything));
    await expectLater(
      repository.markRead(ids: [id(1)], throughSequence: '1'),
      throwsA(anything),
    );
    await expectLater(
      repository.markRead(throughSequence: '0'),
      throwsA(anything),
    );
    expect(
      () => SystemNotice.parse({...notice(1), 'amountCents': 0}),
      throwsA(anything),
    );
    expect(
      () => SystemNoticePageData.parse(page([notice(1)], next: id(1))),
      throwsA(anything),
    );
  });
  test('loads earlier cards without duplicates and refreshes while retaining loaded history', () async {
    var calls = 0;
    final controller = SystemNoticesController(
      SystemNoticesRepository(
        readSession: () async => session('one'),
        request: (api, p, s) async {
          calls++;
          if (p['beforeNotice'] != null) {
            expect(p['beforeNotice'], id(2));
            return {
              'result': page([notice(1)]),
            };
          }
          return {
            'result': page(
              List.generate(20, (i) => notice(21 - i)),
              next: id(2),
            ),
          };
        },
      ),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.refresh(more: true);
    await controller.refresh();
    expect(calls, 3);
    expect(controller.notices.length, 21);
    expect(controller.notices.last.id, id(1));
    expect(controller.next, isNull);
    controller.invalidate();
    expect(controller.notices, isEmpty);
    expect(controller.summary.unreadCount, 0);
  });
  test(
    'queues a business refresh received while a list request is in progress',
    () async {
      final first = Completer<Map<String, dynamic>>();
      var calls = 0;
      final controller = SystemNoticesController(
        SystemNoticesRepository(
          readSession: () async => session('one'),
          request: (api, p, s) async {
            calls++;
            return calls == 1
                ? first.future
                : {
                    'result': page([notice(2), notice(1)]),
                  };
          },
        ),
      );
      addTearDown(controller.dispose);
      final initial = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      await controller.refresh();
      first.complete({
        'result': page([notice(1)]),
      });
      await initial;
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(controller.notices.length, 2);
    },
  );
  test('mark-all uses server snapshot and keeps a concurrently arriving notice unread', () async {
    final controller = SystemNoticesController(
      SystemNoticesRepository(
        readSession: () async => session('one'),
        request: (api, p, s) async {
          if (api == 'K261002001961') {
            expect(p, {'throughSequence': '22'});
            return {
              'result': page([notice(2)], unread: 1),
            };
          }
          return {
            'result': page([notice(1)]),
          };
        },
      ),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.markRead();
    expect(controller.notices.single.read, isTrue);
    expect(controller.summary.unreadCount, 1);
  });
  testWidgets(
    'real receipt uses legacy card geometry and opens its owned order',
    (tester) async {
      tester.view.physicalSize = const Size(750, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, String>? target;
      final controller = SystemNoticesController(
        SystemNoticesRepository(
          readSession: () async => session('one'),
          request: (api, p, s) async => {
            'result': page([notice(1, read: api == 'K261002001961')]),
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: KingTheme.dark,
          home: SystemNotificationsPage(
            demo: false,
            controller: controller,
            onOpenTarget: (value) => target = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('购买付款成功'), findsOneWidget);
      expect(find.text('签到获得'), findsNothing);
      expect(find.text('¥388.00'), findsOneWidget);
      final material = find
          .ancestor(of: find.text('¥388.00'), matching: find.byType(Material))
          .first;
      expect(tester.getSize(material).width, 660);
      final widget = tester.widget<Material>(material);
      expect(widget.color, const Color(0x0FFFFFFF));
      expect(widget.borderRadius, BorderRadius.circular(16));
      final money = tester.widget<Text>(find.text('¥388.00'));
      expect(money.style?.fontSize, 56);
      expect(money.style?.fontWeight, FontWeight.w500);
      expect(
        ((money.textSpan as TextSpan).children!.first as TextSpan)
            .style
            ?.fontSize,
        40,
      );
      await tester.tap(find.text('购买付款成功'));
      await tester.pumpAndSettle();
      expect(target, {'kind': 'order', 'reference': 'test-order'});
      expect(controller.summary.unreadCount, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
