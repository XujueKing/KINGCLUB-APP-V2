import 'package:kingclub/src/core/session/member_qr_memory.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_repository.dart';
import 'package:kingclub/src/features/profile_settings/presentation/real_personal_qr_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';

class _Repo extends ProfileRepository {
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> load() async => {
    'nickname': '测试会员',
    'memberId': 'TEST-ID',
  };
  @override
  Future<File?> image(Map? ref) async => null;
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params,
  ) async => pending == null
      ? {'code': 'kingclub://member/v1/test', 'ttlSeconds': 600}
      : pending!.future;
}

class _Storage extends PreviewStorageRepository {
  List<StorageItem> current = [];
  @override
  Future<List<StorageItem>> list() async => current;
}

void main() {
  setUp(MemberQrMemory.clear);
  testWidgets(
    'new wine deposit replaces member QR and completes back to original page',
    (tester) async {
      final storage = _Storage();
      storage.current = [
        const StorageItem(ref: 'old', name: 'Old bottle', assetKey: 'chivas'),
      ];
      final events = StreamController<Map<String, dynamic>>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RealPersonalQrPage(
                    repository: _Repo(),
                    storageRepository: storage,
                    events: events.stream,
                  ),
                ),
              ),
              child: const Text('origin'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('origin'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wine-deposit-success')), findsNothing);
      events.add({'eventType': 'storage.changed'});
      await tester.pump();
      expect(find.byKey(const ValueKey('wine-deposit-success')), findsNothing);
      storage.current = [
        ...storage.current,
        const StorageItem(
          ref: 'new',
          name: 'New bottle',
          storeName: 'Test store',
          assetKey: 'chivas',
        ),
      ];
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('wine-deposit-success')),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('origin'), findsOneWidget);
      expect(find.byType(RealPersonalQrPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
  testWidgets('legacy dimensions, real identity and seamless refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(home: RealPersonalQrPage(repository: repo)),
    );
    await tester.pump();
    expect(find.text('测试会员'), findsOneWidget);
    expect(find.text('TEST-ID'), findsOneWidget);
    final surface = find.byKey(const ValueKey('real-member-qr-surface'));
    expect(tester.getSize(surface), const Size(250, 250));
    repo.pending = Completer();
    await tester.tap(surface);
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    repo.pending!.complete({
      'code': 'kingclub://member/v1/next',
      'ttlSeconds': 600,
    });
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('short screen allows scrolling without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: RealPersonalQrPage(repository: _Repo())),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed refresh removes the previous scannable QR', (
    tester,
  ) async {
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(home: RealPersonalQrPage(repository: repo)),
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    repo.pending = Completer();
    await tester.tap(find.byKey(const ValueKey('real-member-qr-surface')));
    await tester.pump();
    repo.pending!.completeError(StateError('session expired'));
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
