import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/private_storage_page.dart';
import 'package:kingclub/src/features/club/presentation/storage_pickup_code_page.dart';

void main() {
  Widget pickup(StoragePickupScenario scenario) => MaterialApp(
    theme: KingTheme.dark,
    home: StoragePickupCodePage(scenario: scenario),
  );

  testWidgets('legacy cabinet opens the pickup credential and returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const PrivateStoragePage()),
    );
    await tester.pump();

    expect(find.text('私人储物柜'), findsOneWidget);
    expect(find.byKey(const ValueKey('storage-grid-酒-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('storage-tab-物-idle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('storage-grid-物-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('storage-empty-info')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('storage-open-pickup-demo')));
    await tester.pumpAndSettle();
    expect(find.text('取件凭证'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('storage-pickup-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('storage-grid-物-1')), findsOneWidget);
  });

  testWidgets('ready credential rotates and background always covers it', (
    tester,
  ) async {
    await tester.pumpWidget(pickup(StoragePickupScenario.ready));
    await tester.pump();
    expect(find.byKey(const ValueKey('storage-pickup-code-1')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('storage-pickup-code-2')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining('凭证已隐藏'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('storage-pickup-code-3')), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.byKey(const ValueKey('storage-pickup-code-4')), findsOneWidget);
  });

  testWidgets('expired credential cannot scan and can be reissued', (
    tester,
  ) async {
    await tester.pumpWidget(pickup(StoragePickupScenario.expired));
    await tester.pump();
    expect(find.text('取件凭证已过期'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsNothing);
    await tester.tap(find.text('重新签发凭证'));
    await tester.pump();
    expect(find.text('可取'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
  });

  testWidgets('replay rejection preserves stock and requires a new code', (
    tester,
  ) async {
    await tester.pumpWidget(pickup(StoragePickupScenario.replayRejected));
    await tester.pump();
    expect(find.textContaining('凭证已使用或失效'), findsOneWidget);
    expect(find.text('重放已拒绝，剩余量未变化'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsNothing);
    await tester.tap(find.text('重新签发凭证'));
    await tester.pump();
    expect(find.text('65%'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
  });

  testWidgets('unknown verification never reports success before reconcile', (
    tester,
  ) async {
    await tester.pumpWidget(pickup(StoragePickupScenario.resultUnknown));
    await tester.pump();
    expect(find.textContaining('核验结果确认中'), findsNWidgets(2));
    expect(find.text('已取出'), findsNothing);
    expect(find.byIcon(Icons.qr_code_2), findsNothing);
    await tester.tap(find.text('刷新核验状态'));
    await tester.pump();
    expect(find.text('35%（部分交付）'), findsOneWidget);
    expect(find.text('部分交付，剩余可取'), findsOneWidget);
  });

  testWidgets('partial stock survives background and credential rotation', (
    tester,
  ) async {
    await tester.pumpWidget(pickup(StoragePickupScenario.partial));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.textContaining('凭证已隐藏'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('35%（部分交付）'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('35%（部分交付）'), findsOneWidget);
    expect(find.text('部分交付，剩余可取'), findsOneWidget);
  });

  testWidgets('every blocked state hides the scannable credential', (
    tester,
  ) async {
    for (final scenario in <StoragePickupScenario>[
      StoragePickupScenario.collected,
      StoragePickupScenario.unavailable,
      StoragePickupScenario.offline,
    ]) {
      await tester.pumpWidget(pickup(scenario));
      await tester.pump();
      expect(find.byIcon(Icons.qr_code_2), findsNothing, reason: scenario.name);
    }
  });

  testWidgets('hidden audit picker exposes every documented state', (
    tester,
  ) async {
    await tester.pumpWidget(pickup(StoragePickupScenario.ready));
    await tester.pump();
    await tester.longPress(find.byKey(const ValueKey('storage-pickup-title')));
    await tester.pumpAndSettle();
    for (final scenario in StoragePickupScenario.values.take(5)) {
      expect(
        find.byKey(ValueKey('storage-scenario-${scenario.name}')),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('storage-scenario-resultUnknown')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    for (final scenario in StoragePickupScenario.values.skip(5)) {
      expect(
        find.byKey(ValueKey('storage-scenario-${scenario.name}')),
        findsOneWidget,
      );
    }
  });
}
