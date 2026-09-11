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
    await tester.tap(find.byKey(const ValueKey('storage-pickup')));
    await tester.pumpAndSettle();
    expect(find.text('ITEM PICKUP CODE'), findsOneWidget);
    expect(find.text('存酒已过期，请联系工作人员核实'), findsOneWidget);
    expect(find.byKey(const ValueKey('storage-real-code')), findsNothing);
    expect(repo.issued, 0);
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
