import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/about_legal_page.dart';

Widget _frame(
  AboutLegalScenario scenario, {
  int? initialDocumentIndex,
  VoidCallback? onBack,
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: AboutLegalPage(
      initialScenario: scenario,
      initialDocumentIndex: initialDocumentIndex,
      onBack: onBack,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

void main() {
  testWidgets('catalog exposes all required legal documents', (tester) async {
    await tester.pumpWidget(_frame(AboutLegalScenario.catalog));
    expect(find.byKey(const ValueKey('about-legal-catalog')), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(ValueKey('about-legal-document-$index')),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'document reader shows title version date and returns to catalog',
    (tester) async {
      await tester.pumpWidget(_frame(AboutLegalScenario.catalog));
      await tester.tap(find.byKey(const ValueKey('about-legal-document-0')));
      await tester.pumpAndSettle();
      expect(find.text('《KING CLUB 会员服务协议》'), findsOneWidget);
      expect(find.text('版本：预发布版'), findsOneWidget);
      expect(find.text('生效日期：待权威目录确认'), findsOneWidget);

      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('about-legal-catalog')), findsOneWidget);
    },
  );

  testWidgets('valid deep document reference opens directly', (tester) async {
    await tester.pumpWidget(
      _frame(AboutLegalScenario.catalog, initialDocumentIndex: 1),
    );
    expect(find.text('《KingClub 隐私政策》'), findsOneWidget);
  });

  testWidgets('offline trusted cache is marked in catalog and reader', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(AboutLegalScenario.offlineCached));
    expect(find.byKey(const ValueKey('about-offline-cached')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about-legal-document-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('about-reader-offline-cached')),
      findsOneWidget,
    );
    expect(find.text('版本：预发布版'), findsOneWidget);
  });

  testWidgets('expired cache refuses to show blank or stale content', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(AboutLegalScenario.offlineExpired));
    expect(find.byKey(const ValueKey('about-offline-expired')), findsOneWidget);
    expect(find.textContaining('离线缓存已过期'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-legal-catalog')), findsNothing);
  });

  testWidgets('invalid reference is rejected and can recover to catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(AboutLegalScenario.catalog, initialDocumentIndex: 99),
    );
    expect(find.byKey(const ValueKey('about-invalid-ref')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about-legal-catalog')), findsOneWidget);
  });

  testWidgets('catalog error never substitutes an empty legal body', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(AboutLegalScenario.loadingError));
    expect(find.byKey(const ValueKey('about-loading-error')), findsOneWidget);
    expect(find.textContaining('不会以空白正文代替'), findsOneWidget);
    expect(find.text('本页为 UI Mock，不是正式法律文本。'), findsNothing);
  });

  testWidgets('catalog back delegates to the settings route', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      _frame(AboutLegalScenario.catalog, onBack: () => backCount++),
    );
    await tester.tap(find.byType(IconButton).first);
    expect(backCount, 1);
  });

  testWidgets('session invalid clears reference and requests auth reset', (
    tester,
  ) async {
    var resetCount = 0;
    await tester.pumpWidget(
      _frame(
        AboutLegalScenario.sessionInvalid,
        onSessionResetRequested: () => resetCount++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about-session-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about-session-confirm')));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
  });
}
