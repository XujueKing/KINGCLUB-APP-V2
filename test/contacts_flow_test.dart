import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';

Widget _app(
  ContactsDemoState state, {
  ValueChanged<ContactRouteIntent>? onIntent,
  VoidCallback? onOpenChat,
  VoidCallback? onSessionResetRequested,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: Colors.black,
      body: ContactsPage(
        key: ValueKey('contacts-${state.name}-$textScale'),
        active: true,
        initialState: state,
        onIntent: onIntent ?? (_) {},
        onOpenChat: onOpenChat,
        onSessionResetRequested: onSessionResetRequested,
      ),
    ),
  );
}

void main() {
  testWidgets('ready contacts expose every approved exit', (tester) async {
    final intents = <ContactRouteIntent>[];
    var chatOpened = false;
    await tester.pumpWidget(
      _app(
        ContactsDemoState.ready,
        onIntent: intents.add,
        onOpenChat: () => chatOpened = true,
      ),
    );

    await tester.tap(find.text('聊天'));
    expect(chatOpened, isTrue);
    await tester.tap(find.text('新的朋友'));
    await tester.tap(find.byKey(const ValueKey('contacts-blacklist')));
    await tester.tap(find.text('艾琳'));

    expect(
      intents.map((intent) => intent.kind),
      containsAll([
        ContactIntentKind.friendRequests,
        ContactIntentKind.blacklist,
        ContactIntentKind.userProfile,
      ]),
    );
    expect(intents.last.targetRef, 'contact-alice');
  });

  testWidgets('empty and fatal states recover without exposing contacts', (
    tester,
  ) async {
    ContactRouteIntent? intent;
    await tester.pumpWidget(
      _app(ContactsDemoState.empty, onIntent: (value) => intent = value),
    );
    expect(find.text('还没有好友'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '添加好友'));
    expect(intent?.kind, ContactIntentKind.addFriend);

    await tester.pumpWidget(_app(ContactsDemoState.fatalError));
    expect(find.text('通讯录加载失败'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('艾琳'), findsOneWidget);
  });

  testWidgets('cached and partial states retain usable friend rows', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ContactsDemoState.offlineCached));
    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('艾琳'), findsOneWidget);

    await tester.pumpWidget(_app(ContactsDemoState.partialError));
    expect(find.text('更多好友加载失败'), findsOneWidget);
    expect(find.text('艾琳'), findsOneWidget);
  });

  testWidgets('relationship and avatar changes do not leak stale identity', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ContactsDemoState.relationshipChanged));
    expect(find.text('好友关系已更新'), findsOneWidget);
    expect(find.text('卡座搭子'), findsNothing);
    expect(find.text('Lucas'), findsNothing);

    await tester.pumpWidget(_app(ContactsDemoState.avatarFailure));
    expect(find.byIcon(Icons.person_outline), findsWidgets);
    expect(find.text('艾琳'), findsOneWidget);
  });

  testWidgets('search is limited to nickname and private remark', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ContactsDemoState.ready));
    final search = find.byType(TextField);
    await tester.enterText(search, '13800000000');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('没有匹配的好友'), findsOneWidget);

    await tester.enterText(search, 'K45600000199');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('没有匹配的好友'), findsOneWidget);
    expect(find.textContaining('13800000000'), findsNothing);
  });

  testWidgets('large text stays scrollable and removes side index', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ContactsDemoState.ready, textScale: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('#'), findsNothing);
  });

  testWidgets('invalid session clears data, disables actions and resets', (
    tester,
  ) async {
    var reset = false;
    var intents = 0;
    await tester.pumpWidget(
      _app(
        ContactsDemoState.sessionInvalid,
        onIntent: (_) => intents++,
        onSessionResetRequested: () => reset = true,
      ),
    );
    await tester.pump();
    expect(find.text('好友快照和搜索词已清除，请重新登录。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('contacts-session-confirm')));
    await tester.pumpAndSettle();
    expect(reset, isTrue);
    expect(find.text('艾琳'), findsNothing);
    expect(intents, 0);
  });
}
