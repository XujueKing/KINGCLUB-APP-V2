import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/reservation_deposits.dart';
import 'package:kingclub/src/features/club/presentation/reservation_deposit_status_page.dart';
import 'package:kingclub/src/features/club/presentation/reservation_discovery_page.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';

import 'reservation_products_test.dart' show pumpPage, product;

const depositRef = '00000000-0000-4000-8000-000000000007';
Map<String, dynamic> original({String status = 'reserved', String? refund}) => {
  'userAccount': 'U00000000001',
  'depositRef': depositRef,
  'status': status,
  'amountCents': '120000',
  'startsAt': product()['startsAt'],
  'endsAt': product()['endsAt'],
  'partySize': 3,
  'canCancel': status == 'reserved' || status == 'paying',
  'snapshot': {
    'title': 'Test booth',
    'storeName': 'Test store',
    'tableName': 'V1',
    'currency': 'CNY',
    'depositCents': '120000',
  },
  'reservation': status == 'paying'
      ? null
      : {
          'ref': depositRef,
          'status': status == 'reserved' ? 'reserved' : 'cancelled',
        },
  'refund': refund == null
      ? null
      : {
          'status': refund,
          'amountCents': '120000',
          'reason': 'customer_cancelled',
        },
};

void main() {
  test(
    'SDK flags, another original order and incomplete refunds are rejected',
    () {
      expect(
        reservationDepositResult(original(), depositRef)['status'],
        'reserved',
      );
      for (final invalid in [
        {'paid': true},
        {...original(), 'depositRef': 'another'},
        {...original(), 'reservation': null},
        original(status: 'refunded', refund: 'sending'),
        {
          ...original(status: 'refunded', refund: 'refunded'),
          'refund': {'status': 'refunded', 'amountCents': '1'},
        },
      ]) {
        expect(
          () => reservationDepositResult(invalid, depositRef),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets(
    'one full page request shows lost position and refund without confirmation',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await pumpPage(
        t,
        ReservationDepositStatusPage(
          depositRef: depositRef,
          call: (p) async {
            calls.add(p);
            return {
              ...original(status: 'refund_pending', refund: 'sending'),
              'reservation': null,
            };
          },
        ),
      );
      expect(calls, [
        {'action': 'detail', 'depositRef': depositRef},
      ]);
      expect(find.text('原渠道退款处理中'), findsOneWidget);
      expect(find.textContaining('本次未取得位置'), findsOneWidget);
      expect(find.text('预约已确认'), findsNothing);
      expect(find.text('定金已退回'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancellation uses returned page, refund is shown only after verified query',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await pumpPage(
        t,
        ReservationDepositStatusPage(
          depositRef: depositRef,
          initialResult: original(),
          call: (p) async {
            calls.add(p);
            return p['operation'] == 'cancel'
                ? original(status: 'refund_pending', refund: 'sending')
                : original(status: 'refunded', refund: 'refunded');
          },
        ),
      );
      expect(calls, isEmpty);
      await t.tap(find.text('取消预约'));
      await t.pumpAndSettle();
      expect(find.textContaining('原渠道退回'), findsOneWidget);
      final keep = t.getSize(find.widgetWithText(OutlinedButton, '保留预约'));
      final confirm = t.getSize(find.widgetWithText(FilledButton, '确认取消'));
      expect(keep.height, 52);
      expect(confirm.height, 52);
      await t.tap(find.text('确认取消'));
      await t.pumpAndSettle();
      expect(calls, [
        {'action': 'payment', 'depositRef': depositRef, 'operation': 'cancel'},
      ]);
      expect(find.text('原渠道退款处理中'), findsOneWidget);
      expect(find.text('定金已退回'), findsNothing);
      expect(find.text('取消预约'), findsNothing);
      await t.ensureVisible(find.text('核对原单'));
      await t.tap(find.text('核对原单'));
      await t.pumpAndSettle();
      expect(calls.last, {
        'action': 'payment',
        'depositRef': depositRef,
        'operation': 'query',
      });
      expect(find.text('定金已退回'), findsOneWidget);
      await t.pump(const Duration(seconds: 25));
      expect(calls.length, 2); // Terminal refunds stop polling.
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed or wrong-order response keeps original facts and retry reference',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await pumpPage(
        t,
        ReservationDepositStatusPage(
          depositRef: depositRef,
          initialResult: original(),
          call: (p) async {
            calls.add(p);
            if (calls.length == 1) throw StateError('temporary failure');
            return {
              ...original(status: 'refunded', refund: 'refunded'),
              'depositRef': 'wrong',
            };
          },
        ),
      );
      for (var i = 0; i < 2; i++) {
        await t.ensureVisible(find.widgetWithText(OutlinedButton, '核对原单'));
        await t.pumpAndSettle();
        await t.tap(find.text('核对原单'));
        await t.pumpAndSettle();
        expect(find.text('预约已确认'), findsOneWidget);
        expect(find.text('CNY 1,200.00'), findsOneWidget);
        expect(find.text('定金已退回'), findsNothing);
      }
      expect(calls.length, 2);
      expect(calls[0], calls[1]);
    },
  );

  testWidgets(
    'background stops polling, foreground reconciles and disposed page ignores late result',
    (t) async {
      final result = Completer<Map<String, dynamic>>();
      var calls = 0;
      await pumpPage(
        t,
        ReservationDepositStatusPage(
          depositRef: depositRef,
          initialResult: original(status: 'paying'),
          call: (_) {
            calls++;
            return result.future;
          },
        ),
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 25));
      expect(calls, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(calls, 1);
      await t.pump(const Duration(seconds: 20));
      expect(calls, 1); // An in-flight query is never duplicated.
      await t.pumpWidget(const SizedBox());
      result.complete(original());
      await t.pump();
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'paid reservations open the original-deposit page without free booking calls',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      final receipt = original();
      await pumpPage(
        t,
        MemberReservationsPage(
          call: (p) async {
            expect(p['action'], 'reservations');
            return {
              'hasMore': false,
              'items': [
                {
                  'ref': depositRef,
                  'status': 'reserved',
                  'startsAt': product()['startsAt'],
                  'snapshot': receipt['snapshot'],
                },
              ],
            };
          },
          depositCall: (p) async {
            calls.add(p);
            return receipt;
          },
        ),
      );
      await t.tap(find.text('Test store'));
      await t.pumpAndSettle();
      expect(find.byType(ReservationDepositStatusPage), findsOneWidget);
      expect(calls, [
        {'action': 'detail', 'depositRef': depositRef},
      ]);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'original deposit layout at ${width.toInt()} with larger text',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment(
          'SAVE_RESERVATION_DEPOSIT_PREVIEW',
        );
        if (capture) {
          await t.runAsync(() async {
            final loader = FontLoader('DepositVisualChinese')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('C:/Windows/Fonts/msyh.ttc').readAsBytes(),
                  ),
                ),
              );
            await loader.load();
          });
        }
        final boundary = GlobalKey();
        await pumpPage(
          t,
          RepaintBoundary(
            key: boundary,
            child: Theme(
              data: capture
                  ? KingTheme.dark.copyWith(
                      textTheme: KingTheme.dark.textTheme.apply(
                        fontFamily: 'DepositVisualChinese',
                      ),
                    )
                  : KingTheme.dark,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: const TextScaler.linear(1.25),
                ),
                child: ReservationDepositStatusPage(
                  depositRef: depositRef,
                  initialResult: original(
                    status: 'refund_pending',
                    refund: 'review',
                  ),
                  call: (_) async =>
                      throw StateError('No automatic review polling'),
                ),
              ),
            ),
          ),
        );
        expect(t.takeException(), null);
        if (capture) {
          await t.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/reservation-deposit-preview');
            await directory.create(recursive: true);
            await File('${directory.path}/refund-${width.toInt()}.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
