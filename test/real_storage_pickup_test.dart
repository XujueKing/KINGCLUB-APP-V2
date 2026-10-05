import 'dart:async';

import 'package:qr_flutter/qr_flutter.dart';
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

class DelayedRepo extends Repo {
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> issue(String ref) {
    if (calls == 0) return super.issue(ref);
    calls++;
    pending = Completer<Map<String, dynamic>>();
    return pending!.future;
  }
}

void main() {
  for (final notify in [true, false]) {
    testWidgets(
      'collection succeeds and returns directly to bag notify=$notify',
      (tester) async {
        final repo = Repo();
        final events = StreamController<Map<String, dynamic>>.broadcast();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RealStoragePickupPage(
                        item: fixture.first,
                        repository: repo,
                        events: events.stream,
                      ),
                    ),
                  ),
                  child: const Text('Storage bag'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Storage bag'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        // An event alone never asserts collection; the server remains authority.
        events.add({'eventType': 'storage.changed'});
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('storage-pickup-success')),
          findsNothing,
        );
        repo.available = false;
        if (notify)
          events.add({'eventType': 'storage.changed'});
        else
          await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('storage-pickup-success')),
          findsOneWidget,
        );
        expect(find.byType(QrImageView), findsNothing);
        final issued = repo.calls;
        await tester.pump(const Duration(seconds: 35));
        expect(repo.calls, issued);
        await tester.tap(find.text('Back to storage'));
        await tester.pumpAndSettle();
        expect(find.text('Storage bag'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('storage-pickup-success')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        await events.close();
      },
    );
  }

  testWidgets(
    'refresh keeps code and white panel until atomic replacement, expires on slow network',
    (tester) async {
      final repo = DelayedRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: RealStoragePickupPage(item: fixture.first, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 26));
      await tester.pump();
      expect(repo.calls, 2);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.pending!.complete({
        'token': 'next-test-token',
        'expiresInSeconds': 30,
      });
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.pump(const Duration(seconds: 26));
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('storage-real-code')), findsNothing);
      expect(
        find.byKey(const ValueKey('storage-code-background')),
        findsOneWidget,
      );
      repo.pending!.completeError(StateError('offline'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('storage-code-background')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
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
      expect(
        find.byKey(const ValueKey('storage-pickup-success')),
        findsOneWidget,
      );
      expect(repo.calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
