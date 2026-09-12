import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/club/presentation/storage_liquid_bottle.dart';

const expired = StorageItem(
  ref: 'test-expired',
  name: '测试存酒',
  assetKey: 'vodka',
  status: 'expired',
  canPickup: false,
);

class ExpiredRepo extends PreviewStorageRepository {
  ExpiredRepo() : super([expired]);
  int issued = 0;
  @override
  Future<Map<String, dynamic>> issue(String ref) async {
    issued++;
    throw StateError('Expired stock must not issue credentials');
  }
}

void main() {
  testWidgets(
    'same wine stored in different batches keeps separate cells, levels and detail dates',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const first = StorageItem(
        ref: 'batch-a',
        name: '同款存酒',
        assetKey: 'vodka',
        quantity: 2,
        remainingPercent: 50,
        storedAt: '2026-08-01T12:00:00',
        expiresAt: '2026-08-31T12:00:00',
        status: 'available',
        canPickup: false,
      );
      const second = StorageItem(
        ref: 'batch-b',
        name: '同款存酒',
        assetKey: 'vodka',
        quantity: 1,
        remainingPercent: 100,
        storedAt: '2026-08-10T12:00:00',
        expiresAt: '2026-09-09T12:00:00',
        status: 'available',
        canPickup: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(
            repository: PreviewStorageRepository([first, second]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final item in [first, second]) {
        final cell = find.byKey(ValueKey('storage-select-${item.ref}'));
        expect(cell, findsOneWidget);
        expect(
          find.descendant(of: cell, matching: find.text('${item.quantity}')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: cell,
            matching: find.text('${item.remainingPercent.toStringAsFixed(0)}%'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('3'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('storage-select-batch-b')));
      await tester.tap(find.byKey(const ValueKey('storage-pickup')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-09 12:00:00'), findsOneWidget);
      expect(find.text('2026-08-31 12:00:00'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('storage-select-batch-a')));
      await tester.tap(find.byKey(const ValueKey('storage-pickup')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('2026-08-31 12:00:00'), findsOneWidget);
      expect(find.text('50%'), findsWidgets);
    },
  );
  testWidgets(
    'expired storage lists wine and items, excluding available stock',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateStoragePage(
            repository: PreviewStorageRepository([
              expired,
              const StorageItem(
                ref: 'expired-coupon',
                name: '过期券',
                assetKey: 'aa-ticket',
                category: 'item',
                status: 'expired',
                canPickup: false,
              ),
              const StorageItem(
                ref: 'available-wine',
                name: '有效存酒',
                assetKey: 'vodka',
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('storage-expired-items')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('expired-item-test-expired')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expired-item-expired-coupon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expired-item-available-wine')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('expired-item-expired-coupon')),
      );
      await tester.pumpAndSettle();
      expect(find.text('物品已过期，请联系工作人员核实'), findsOneWidget);
      expect(find.byKey(const ValueKey('storage-real-code')), findsNothing);
    },
  );
  testWidgets('expired wine QR icon opens details without issuing a code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = ExpiredRepo();
    await tester.pumpWidget(
      MaterialApp(home: PrivateStoragePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('storage-select-test-expired')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('storage-expired-items')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expired-item-test-expired')));
    await tester.pumpAndSettle();
    expect(find.text('ITEM PICKUP CODE'), findsOneWidget);
    expect(find.text('存酒已过期，请联系工作人员核实'), findsOneWidget);
    expect(find.byKey(const ValueKey('storage-real-code')), findsNothing);
    expect(repo.issued, 0);
    expect(find.text('刷新状态'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('storage-delete')));
    await tester.pumpAndSettle();
    expect(find.text('私人储物柜'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('storage-expired-items')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('expired-item-test-expired')),
      findsNothing,
    );
    expect(repo.items, isEmpty);
  });
  testWidgets(
    'full bottle keeps headspace and its liquid still moves; inactive pauses',
    (tester) async {
      Widget frame(bool active) => MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 200,
            child: StorageLiquidBottle(item: expired, active: active),
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      await tester.pump(const Duration(milliseconds: 650));
      Path surface() => tester
          .widget<ClipPath>(
            find.byKey(const ValueKey('storage-liquid-surface')),
          )
          .clipper!
          .getClip(const Size(100, 200));
      final first = surface();
      expect(first.getBounds().top, greaterThan(10));
      expect(first.contains(const Offset(50, 20)), isTrue);
      expect(find.text('100%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(surface().contains(const Offset(50, 20)), isFalse);
      await tester.pumpWidget(frame(false));
      final paused = surface().contains(const Offset(50, 20));
      await tester.pump(const Duration(milliseconds: 650));
      expect(surface().contains(const Offset(50, 20)), paused);
    },
  );
}
