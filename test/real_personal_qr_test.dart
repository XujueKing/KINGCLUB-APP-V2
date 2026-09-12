import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_repository.dart';
import 'package:kingclub/src/features/profile_settings/presentation/real_personal_qr_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

void main() {
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
}
