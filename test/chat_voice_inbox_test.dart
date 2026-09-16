import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_inbox.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'chat_voice_prefetch_test.dart' show Store, rows, grant;

Map<String, dynamic> conversation(int sequence) => {
  'peer': 'peer',
  'lastSequence': sequence,
  'unreadCount': 1,
};

void main() {
  test(
    'initial backfill reaches older voice behind a text-only page',
    () async {
      final store = Store()..download.complete(File('voice.m4a'));
      final requests = <Map<String, dynamic>>[];
      final inbox = ChatVoiceInbox(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000638') return grant();
            expect(id, 'K260913000604');
            expect(params.containsKey('messageType'), false);
            requests.add(Map.of(params));
            if (requests.length == 1)
              return {
                'messages': [
                  for (var i = 51; i <= 100; i++)
                    {'sequence': i, 'messageType': 'text'},
                ],
                'hasMore': true,
              };
            if (requests.length == 2)
              return {
                'messages': [
                  {...rows.single, 'sequence': 1},
                ],
                'hasMore': false,
              };
            return {'messages': [], 'hasMore': false};
          },
        ),
        media: store,
      );
      addTearDown(inbox.dispose);
      inbox.update([conversation(100)]);
      await inbox.idle;
      expect(requests, hasLength(2));
      expect(requests[1]['before'], 51);
      expect(store.retained, hasLength(1));
      inbox.update([conversation(101)]);
      await inbox.idle;
      expect(requests.last['after'], 100);
    },
  );
  test('unopened unread conversation retains voice, same sequence does not refetch', () async {
    final store = Store()..download.complete(File('downloaded.m4a'));
    var histories = 0, grants = 0;
    final inbox = ChatVoiceInbox(
      MessagingRepository(
        account: 'me',
        call: (method, params) async {
          if (method == 'K260913000604') {
            histories++;
            expect(params.containsKey('messageType'), false);
            expect(params['limit'], 50);
            expect(params['peer'], 'peer');
            return {'messages': rows};
          }
          expect(method, 'K260913000638');
          grants++;
          return grant();
        },
      ),
      media: store,
    );
    addTearDown(inbox.dispose);
    inbox.update([
      conversation(1),
      {...conversation(1), 'peer': 'read', 'unreadCount': 0},
      {...conversation(1), 'peer': 'relay', 'localOnly': true},
    ]);
    await inbox.idle;
    expect(histories, 1);
    expect(grants, 2);
    expect(store.retained, hasLength(1));
    inbox.update([conversation(1)]);
    await inbox.idle;
    expect(histories, 1);
    inbox.update([conversation(2)]);
    await inbox.idle;
    expect(histories, 2);
    expect(store.downloads, 1);
  });

  test('sequence arriving during history fetch is processed next', () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final inbox = ChatVoiceInbox(
      MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          return calls == 1 ? pending.future : {'messages': []};
        },
      ),
    );
    addTearDown(inbox.dispose);
    inbox.update([conversation(1)]);
    inbox.update([conversation(2)]);
    pending.complete({'messages': []});
    await inbox.idle;
    expect(calls, 2);
  });

  test('disposal ignores late history result', () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final inbox = ChatVoiceInbox(
      MessagingRepository(
        account: 'me',
        call: (_, _) {
          calls++;
          return pending.future;
        },
      ),
    );
    inbox.update([conversation(1)]);
    inbox.dispose();
    pending.complete({'messages': rows});
    await inbox.idle;
    expect(calls, 1);
  });
}
