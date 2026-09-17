import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

void main() {
  for (final panel in [null, 'attachments', 'emoji']) {
    testWidgets('router system back handles chat panel=$panel', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  KingPageRoute<void>(builder: (_) => const DirectChatPage()),
                ),
                child: const Text('open chat'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: KingTheme.dark),
      );
      await tester.tap(find.text('open chat'));
      await tester.pumpAndSettle();
      expect(find.byType(DirectChatPage), findsOneWidget);
      if (panel != null) {
        await tester.tap(find.byKey(ValueKey('direct-chat-$panel')));
        await tester.pumpAndSettle();
        expect(await tester.binding.handlePopRoute(), true);
        await tester.pumpAndSettle();
        expect(find.byType(DirectChatPage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('direct-chat-attachment-panel')),
          findsNothing,
        );
      }
      expect(await tester.binding.handlePopRoute(), true);
      await tester.pumpAndSettle();
      expect(find.byType(DirectChatPage), findsNothing);
      expect(find.text('open chat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
