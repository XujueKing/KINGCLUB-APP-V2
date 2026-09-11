import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/club/presentation/real_storage_pickup_page.dart';

import 'storage_replica_test.dart' show fixture;

class Repo extends PreviewStorageRepository {
  Repo() : super(fixture);
  int calls = 0;
  bool available = true;
  @override
  Future<StorageItem> detail(String ref) async => available
      ? fixture.first
      : const StorageItem(
          ref: 'wine-1',
          name: '测试',
          assetKey: 'vodka',
          status: 'collected',
          canPickup: false,
        );
  @override
  Future<Map<String, dynamic>> issue(String ref) async => {
    'token': 'opaque-test-token-${++calls}',
    'expiresInSeconds': 30,
  };
}

void main() {
  testWidgets(
    'real credential rotates, hides in background and stops after collection',
    (tester) async {
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: RealStoragePickupPage(item: fixture.first, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.byKey(const ValueKey('storage-real-code')), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const ValueKey('storage-real-code')), findsNothing);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls, 2);
      repo.available = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('已取出'), findsOneWidget);
      expect(repo.calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
