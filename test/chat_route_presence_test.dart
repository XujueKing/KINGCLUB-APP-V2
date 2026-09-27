import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_route_presence.dart';

void main() {
  const identity = (account: 'recipient', target: 'sender', group: false);

  testWidgets('consecutive events reuse current route without losing draft', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final presence = ChatRoutePresence();
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const Text('home')),
    );
    var pushed = 0;
    void open() {
      final navigator = key.currentState!;
      if (presence.isCurrent(navigator, identity)) return;
      pushed++;
      final route = MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: TextField(controller: draft)),
      );
      final release = presence.register(route, () => identity);
      navigator.push(route).whenComplete(release);
    }

    open();
    open(); // Second distinct click arrives before the first page builds.
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unsent draft');
    open();
    await tester.pumpAndSettle();
    expect(pushed, 1);
    expect(draft.text, 'unsent draft');
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(presence.isCurrent(key.currentState!, identity), isFalse);
    open();
    await tester.pumpAndSettle();
    expect(pushed, 2); // Leaving the page must not suppress a future click.
    key.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('identity is scoped to account, kind, target and visible route', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final presence = ChatRoutePresence();
    ChatRouteIdentity? current = identity;
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const Text('home')),
    );
    final navigator = key.currentState!;
    final chat = MaterialPageRoute<void>(builder: (_) => const Text('chat'));
    final release = presence.register(chat, () => current);
    navigator.push(chat);
    await tester.pumpAndSettle();
    expect(presence.isCurrent(navigator, identity), isTrue);
    for (final other in [
      (account: 'other', target: 'sender', group: false),
      (account: 'recipient', target: 'other', group: false),
      (account: 'recipient', target: 'sender', group: true),
    ]) {
      expect(presence.isCurrent(navigator, other), isFalse);
    }
    current = null; // Repository no longer belongs to a ready session.
    expect(presence.isCurrent(navigator, identity), isFalse);
    current = identity;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('editor')),
    );
    await tester.pumpAndSettle();
    expect(presence.isCurrent(navigator, identity), isFalse);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(presence.isCurrent(navigator, identity), isTrue);
    release();
    release();
    expect(presence.isCurrent(navigator, identity), isFalse);
  });
}
