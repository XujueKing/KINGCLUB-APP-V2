import 'package:flutter/material.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_context.dart';

void main() {
  Map<String, dynamic> message(int n) => {
    'sequence': n,
    'messageId': 'm$n',
    'text': 'text$n',
    'sender': 'me',
    'createdDate': DateTime(2020, 1, 2, 10).toUtc().toIso8601String(),
  };
  Map<String, dynamic> page(
    List<int> numbers, {
    int hidden = 0,
    int version = 1,
    int joined = 0,
  }) => {
    'messages': numbers.map(message).toList(),
    'settings': {'hiddenThrough': hidden},
    'membershipVersion': version,
    'joinedSequence': joined,
  };
  test('recall between context pages cannot expose the old message', () async {
    for (final group in [false, true]) {
      for (final revision in [2, null, -1, '1']) {
        await expectLater(
          readChatHistoryContext(
            messageId: 'm50',
            sequence: 50,
            read: ({before, after, required limit}) async => {
              'messages': before != null ? [message(50)] : [message(51)],
              'settings': {'hiddenThrough': 0},
              if (group) 'membershipVersion': 0,
              if (group) 'joinedSequence': 0,
              'historyVersion': before != null ? 1 : revision,
            },
          ),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
      }
    }
  });

  testWidgets('context opens at the selected message and clears on logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHistoryContextPage(
          account: 'me',
          messageId: 'm20',
          sequence: 20,
          read: ({before, after, required limit}) async =>
              page(after == null ? List.generate(20, (i) => i + 1) : [21, 22]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('text20').hitTestable(), findsOneWidget);
    expect(find.text('me · 2020年1月2日 10:00'), findsNWidgets(22));
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('text20'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'loads a bounded ordered window and requires the exact message id',
    () async {
      final calls = <String>[];
      Future<Map<String, dynamic>> read({
        int? before,
        int? after,
        required int limit,
      }) async {
        calls.add('$before/$after/$limit');
        return before != null ? page([48, 49, 50]) : page([51, 52]);
      }

      final result = await readChatHistoryContext(
        read: read,
        messageId: 'm50',
        sequence: 50,
      );
      expect(calls, ['51/null/21', 'null/50/20']);
      expect(result.map((m) => m['sequence']), [48, 49, 50, 51, 52]);
      await expectLater(
        readChatHistoryContext(read: read, messageId: 'foreign', sequence: 50),
        throwsStateError,
      );
    },
  );
  test(
    'clear or rejoin between requests cannot restore the selected message',
    () async {
      for (final change in ['clear', 'rejoin', 'removed']) {
        var count = 0;
        Future<Map<String, dynamic>> read({
          int? before,
          int? after,
          required int limit,
        }) async {
          if (count++ == 0) return page([50]);
          if (change == 'removed') throw StateError('denied');
          return page(
            [51],
            hidden: change == 'clear' ? 50 : 0,
            version: change == 'rejoin' ? 2 : 1,
            joined: change == 'rejoin' ? 50 : 0,
          );
        }

        await expectLater(
          readChatHistoryContext(read: read, messageId: 'm50', sequence: 50),
          throwsStateError,
        );
      }
    },
  );
}
