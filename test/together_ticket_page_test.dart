import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/presentation/together_ticket_page.dart';

import 'together_play_test.dart' show fixture;

void main() {
  testWidgets(
    'selected ticket uses its own table, date, seats and credential',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final party = fixture(
        state: TogetherJoinState.joined,
        assignedTable: 'V15',
        ticketNumber: 'TEST-0002',
        admissionCode: 'TEST-ONLY-0002',
        day: 3,
        capacity: 14,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherTicketPage(
            party: party,
            clock: () => DateTime(2026, 10, 3, 21),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('V15'), findsOneWidget);
      expect(find.text('2026-10-03 21:00–02:00'), findsOneWidget);
      expect(find.text('TEST-0002'), findsOneWidget);
      expect(find.text(party.theme), findsOneWidget);
      expect(find.text(party.storeName), findsOneWidget);
      expect(find.textContaining('票价'), findsNothing);
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
        '${party.theme}入场二维码',
      );
      for (var i = 0; i < 14; i++) {
        expect(find.byKey(ValueKey('seat-night-$i')), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('together-ticket-sheet')))
            .width,
        closeTo(402 * 690 / 750, .1),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('together-ticket-qr-frame')))
            .width,
        closeTo(402 * 440 / 750, .1),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('入场码已遮盖'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('入场须知'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('入场须知').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unpaid, missing or used credentials do not produce a QR', (
    tester,
  ) async {
    for (final party in [
      fixture(admissionCode: 'not-paid'),
      fixture(state: TogetherJoinState.joined),
      fixture(
        state: TogetherJoinState.joined,
        admissionCode: 'used-code',
        admissionUsed: true,
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherTicketPage(
            party: party,
            clock: () => DateTime(2026, 10, 2, 21),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.text(party.admissionUsed ? '已入场' : '入场码暂不可用'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('overnight ticket expires while its page stays open', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 3, 1, 59, 59);
    await tester.pumpWidget(
      MaterialApp(
        home: TogetherTicketPage(
          party: fixture(
            state: TogetherJoinState.joined,
            admissionCode: 'ticket',
          ),
          clock: () => now,
        ),
      ),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    now = DateTime(2026, 10, 3, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('已过期'), findsOneWidget);
  });

  testWidgets('resume waits for verification and removes a used credential', (
    tester,
  ) async {
    final party = fixture(
      state: TogetherJoinState.joined,
      admissionCode: 'ticket',
    );
    var pending = Completer<TogetherParty>();
    await tester.pumpWidget(
      MaterialApp(
        home: TogetherTicketPage(
          party: party,
          clock: () => DateTime(2026, 10, 2, 21),
          reload: () => pending.future,
        ),
      ),
    );
    expect(find.byType(QrImageView), findsNothing);
    pending.complete(party);
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    pending = Completer<TogetherParty>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    pending.complete(
      fixture(
        state: TogetherJoinState.joined,
        admissionCode: 'ticket',
        admissionUsed: true,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('已入场'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('periodic verification observes cancellation', (tester) async {
    final party = fixture(
      state: TogetherJoinState.joined,
      admissionCode: 'ticket',
    );
    var updated = party;
    await tester.pumpWidget(
      MaterialApp(
        home: TogetherTicketPage(
          party: party,
          clock: () => DateTime(2026, 10, 2, 21),
          reload: () async => updated,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    updated = fixture(
      state: TogetherJoinState.cancelled,
      admissionCode: 'ticket',
    );
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('活动已取消'), findsOneWidget);
  });

  testWidgets(
    'wrong ticket and failed refresh stay hidden until retry succeeds',
    (tester) async {
      final party = fixture(
        state: TogetherJoinState.joined,
        admissionCode: 'ticket',
      );
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherTicketPage(
            party: party,
            clock: () => DateTime(2026, 10, 2, 21),
            reload: () async {
              attempts++;
              if (attempts == 1) {
                return fixture(
                  ref: 'other',
                  state: TogetherJoinState.joined,
                  admissionCode: 'wrong',
                );
              }
              if (attempts == 2) throw StateError('offline');
              return party;
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      await tester.ensureVisible(find.text('重新加载'));
      await tester.tap(find.text('重新加载'));
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.text('重新加载'));
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );
}
