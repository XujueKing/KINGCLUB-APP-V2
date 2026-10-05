import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/storage_attention.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/foreground_message_banner.dart';

class Repo extends PreviewStorageRepository {
  List<StorageItem> rows = [];
  Completer<List<StorageItem>>? pending;
  @override
  Future<List<StorageItem>> list() async =>
      pending == null ? rows : pending!.future;
}

const bottle = StorageItem(ref: 'deposit-1', name: 'Wine', assetKey: 'chivas');
void main() {
  test('unseen storage survives restart; viewing clears it; a new deposit restores it', () async {
    final saved = <String, String>{}, repo = Repo()..rows = [bottle];
    StorageAttention make() => StorageAttention(
      repo,
      account: () async => 'member-a',
      read: (key) async => saved[key],
      write: (key, value) async {
        saved[key] = value;
      },
    );
    final first = make();
    await first.refresh();
    expect(first.unread, isTrue);
    await first.viewed(repo.rows);
    expect(first.unread, isFalse);
    first.dispose();
    final next = make();
    await next.refresh();
    expect(next.unread, isFalse);
    repo.rows = [
      bottle,
      const StorageItem(ref: 'deposit-2', name: 'Wine', assetKey: 'chivas'),
    ];
    await next.refresh();
    expect(next.unread, isTrue);
    next.dispose();
  });
  test('late response from previous account cannot restore its dot', () async {
    final repo = Repo()..pending = Completer<List<StorageItem>>();
    var owner = 'member-a';
    final state = StorageAttention(
      repo,
      account: () async => owner,
      read: (_) async => null,
      write: (_, _) async {},
    );
    final loading = state.refresh();
    await Future<void>.delayed(Duration.zero);
    owner = 'member-b';
    state.reset();
    repo.pending!.complete([bottle]);
    await loading;
    expect(state.unread, isFalse);
    state.dispose();
  });
  test(
    'acknowledging an older visible snapshot leaves a newer deposit unread',
    () async {
      final saved = <String, String>{}, repo = Repo()..rows = [bottle];
      final state = StorageAttention(
        repo,
        account: () async => 'member',
        read: (key) async => saved[key],
        write: (key, value) async {
          saved[key] = value;
        },
      );
      await state.viewed([bottle]);
      repo.rows = [
        bottle,
        const StorageItem(ref: 'new', name: 'Wine', assetKey: 'chivas'),
      ];
      await state.refresh();
      expect(state.unread, isTrue);
      state.dispose();
    },
  );
  testWidgets('storage reuses the chat banner with deposit text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForegroundMessageBanner(
            visible: true,
            message: '存酒成功，酒水已存入储物袋',
            onTap: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.text('存酒成功，酒水已存入储物袋'), findsOneWidget);
    expect(find.textContaining('核销'), findsNothing);
  });
}
