import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_call_history.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' as fixture;
import 'group_chat_controller_test.dart' as group_fixture;

import 'package:kingclub/src/features/messaging/presentation/group_call_page.dart';

const callId = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> record(String media) => {
  'callId': callId,
  'mediaKind': media,
  'endReason': 'hangup',
  'durationMs': 15000,
};

void main() {
  const groupId = '00000000-0000-4000-8000-000000000002';
  Map<String, dynamic> groupRecord(String media) => {
    ...record(media),
    'groupId': groupId,
    'endReason': 'ended',
    'durationMs': null,
  };
  test('group metadata requires matching scope and never invents duration', () {
    final data = groupRecord('video');
    expect(ChatCallHistory.tryParse(data), isNull);
    expect(ChatCallHistory.tryParse(data, expectedGroupId: callId), isNull);
    expect(
      ChatCallHistory.tryParse(record('audio'), expectedGroupId: groupId),
      isNull,
    );
    expect(
      ChatCallHistory.tryParse({
        ...data,
        'durationMs': 1000,
      }, expectedGroupId: groupId),
      isNull,
    );
    final parsed = ChatCallHistory.tryParse(data, expectedGroupId: groupId)!;
    expect(parsed.toJson(), data);
    expect(parsed.displayText(outgoing: true), '群视频通话 · 通话已结束');
  });
  for (final media in ['audio', 'video']) {
    testWidgets(
      'group $media record opens participant chooser without dialing',
      (tester) async {
        final methods = <String>[];
        final repo = MessagingRepository(
          account: 'me',
          call: (id, params) async {
            methods.add(id);
            if (id == 'K260913000621') {
              return group_fixture.history([
                {
                  ...group_fixture.message('call'),
                  'groupId': groupId,
                  'call': groupRecord(media),
                },
              ]);
            }
            if (id == 'K260913000619') return {'members': <dynamic>[]};
            return {};
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: DirectChatPage(
              groupId: groupId,
              repository: repo,
              chatOutbox: fixture.MemoryOutbox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('chat-call-record-$callId'));
        expect(card, findsOneWidget);
        methods.clear();
        await tester.tap(card);
        await tester.pumpAndSettle();
        final page = tester.widget<GroupCallPage>(find.byType(GroupCallPage));
        expect(page.groupId, groupId);
        expect(page.media.name, media);
        expect(methods, contains('K260913000619'));
        expect(
          methods.where((id) => id == 'K260913000643' || id == 'K260915000678'),
          isEmpty,
        );
        Navigator.of(tester.element(find.byType(GroupCallPage))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'call status is relative to the viewer and retains connected duration',
    () {
      for (final entry in {
        'cancelled': ['已取消', '对方已取消'],
        'declined': ['对方已拒绝', '已拒绝'],
        'missed': ['对方未接听', '未接听'],
        'failed': ['连接中断', '连接中断'],
        'revoked': ['通话已结束', '通话已结束'],
        'hangup': ['通话已结束', '通话已结束'],
      }.entries) {
        final call = ChatCallHistory.tryParse({
          ...record('audio'),
          'durationMs': null,
          'endReason': entry.key,
        })!;
        expect(call.displayText(outgoing: true), '语音通话 · ${entry.value[0]}');
        expect(call.displayText(outgoing: false), '语音通话 · ${entry.value[1]}');
      }
      final connected = ChatCallHistory.tryParse({
        ...record('video'),
        'durationMs': 65000,
        'endReason': 'failed',
      })!;
      expect(connected.displayText(outgoing: false), '视频通话 · 01:05 · 连接中断');
    },
  );
  test('rejects plain text and malformed call metadata', () {
    expect(ChatCallHistory.tryParse('语音通话 · 00:15'), isNull);
    for (final override in [
      {'callId': 'not-a-call'},
      {'mediaKind': 'unknown'},
      {'durationMs': -1},
      {'durationMs': 1.5},
      {'endReason': 'ringing'},
    ]) {
      expect(
        ChatCallHistory.tryParse({...record('audio'), ...override}),
        isNull,
      );
    }
    expect(
      ChatCallHistory.tryParse({...record('audio'), 'durationMs': null}),
      isNotNull,
    );
  });
  for (final media in ['audio', 'video']) {
    testWidgets('tapping $media record starts same media once', (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      final queue = fixture.MemoryOutbox();
      final repo = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000604') {
            return fixture.history([
              {
                ...fixture.ack({'clientMessageId': 'msg', 'text': '通话记录'}),
                'call': record(media),
              },
            ]);
          }
          if (id == 'K260913000643') {
            requests.add(params);
            return pending.future;
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            repository: repo,
            chatOutbox: queue,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('chat-call-record-$callId'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('${media == 'audio' ? '语音通话' : '视频通话'} · 00:15'),
        ),
        findsOneWidget,
      );
      await tester.tap(card);
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(requests.single['peer'], 'peer');
      expect(requests.single['mediaKind'], media);
      await tester.pumpWidget(const SizedBox());
      pending.completeError(Exception('test call cancelled'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
