import 'package:kingclub/src/features/messaging/data/chat_file_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/forward_text_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

class RecordingOutbox extends MemoryOutbox {
  final attempts = <String>[];
  @override
  Future<void> put(Map<String, dynamic> message) async {
    attempts.add(message['clientMessageId'] as String);
    await super.put(message);
  }
}

class PreparedImage extends ChatImageForwarder {
  PreparedImage(MessagingRepository repository)
    : super(repository: repository, messageId: 'source');
  int prepared = 0;
  @override
  Future<UploadedChatImage> prepare() async {
    prepared++;
    return const UploadedChatImage(
      '11111111-1111-4111-8111-111111111111',
      2,
      2,
      'f',
      'r',
    );
  }
}

class PreparedFile extends ChatFileForwarder {
  PreparedFile(MessagingRepository repository)
    : super(repository: repository, reference: fileReference);
  static final fileReference = ChatFileReference(
    messageId: 'source',
    assetId: 'original',
    fileName: 'test.bin',
    size: 3,
    sha256: 'a' * 64,
  );
  int prepared = 0;
  @override
  Future<UploadedChatFile> prepare() async {
    prepared++;
    return UploadedChatFile(
      '11111111-1111-4111-8111-111111111111',
      'test.bin',
      3,
      'a' * 64,
      'f',
      'r',
    );
  }
}

void main() {
  MessagingRepository repo() => MessagingRepository(
    account: 'me',
    call: (id, p) async {
      if (id == 'K260913000608') {
        return {
          'items': [
            {'peer': 'peer', 'nickname': 'Friend'},
          ],
          'hasMore': false,
        };
      }
      if (id == 'K260913000604') return history([]);
      if (id == 'K260913000601') throw StateError('offline');
      return {};
    },
  );
  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('forward-text-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forward-text-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'image confirmation queues the asset key consumed by the real sender',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final outbox = RecordingOutbox()..failWrite = true;
      final sent = <Map<String, dynamic>>[];
      final repository = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000608') {
            return {
              'items': [
                {'peer': 'peer', 'nickname': 'Friend'},
              ],
              'hasMore': false,
            };
          }
          if (id == 'K260913000604') return history([]);
          if (id == 'K260913000632') {
            sent.add({...p});
            throw StateError('offline');
          }
          return {};
        },
      );
      final image = PreparedImage(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: ForwardTextPage(
            repository: repository,
            text: '[图片]',
            imageMessageId: 'source',
            outbox: outbox,
            createImageForwarder: () => image,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-text-peer')));
      await tester.pump();
      expect(image.prepared, 0);
      await confirm(tester);
      expect(sent, isEmpty);
      expect(image.prepared, 1);
      outbox.failWrite = false;
      await confirm(tester);
      expect(image.prepared, 1);
      expect(outbox.attempts.toSet().length, 1);
      final queued = outbox.items.values.single;
      expect(queued['imageAssetId'], '11111111-1111-4111-8111-111111111111');
      expect(queued.containsKey('assetId'), false);
      expect(sent.single['assetId'], queued['imageAssetId']);
      expect(sent.single['clientMessageId'], queued['clientMessageId']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'file confirmation queues the asset key consumed by the real sender',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final outbox = RecordingOutbox()..failWrite = true;
      final sent = <Map<String, dynamic>>[];
      final repository = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000608') {
            return {
              'items': [
                {'peer': 'peer', 'nickname': 'Friend'},
              ],
              'hasMore': false,
            };
          }
          if (id == 'K260913000604') return history([]);
          if (id == 'K260914000651') {
            sent.add({...p});
            throw StateError('offline');
          }
          return {};
        },
      );
      final image = PreparedFile(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: ForwardTextPage(
            repository: repository,
            text: '[文件]',
            file: PreparedFile.fileReference,
            outbox: outbox,
            createFileForwarder: () => image,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-text-peer')));
      await tester.pump();
      expect(image.prepared, 0);
      await confirm(tester);
      expect(sent, isEmpty);
      expect(image.prepared, 1);
      outbox.failWrite = false;
      await confirm(tester);
      expect(image.prepared, 1);
      expect(outbox.attempts.toSet().length, 1);
      final queued = outbox.items.values.single;
      expect(queued['fileAssetId'], '11111111-1111-4111-8111-111111111111');
      expect(queued.containsKey('assetId'), false);
      expect(queued['fileName'], 'test.bin');
      expect(queued['fileSize'], 3);
      expect(queued['fileSha256'], 'a' * 64);
      expect(sent.single['assetId'], queued['fileAssetId']);
      expect(sent.single['clientMessageId'], queued['clientMessageId']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'location forwarding preserves coordinate system and original point',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final outbox = RecordingOutbox();
      final point = ChatLocation.fromJson({
        'latitudeE6': 30000000,
        'longitudeE6': 110000000,
        'coordinateSystem': 'gcj02',
        'name': 'Test venue',
        'address': 'Test address',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ForwardTextPage(
            repository: repo(),
            text: '[位置]',
            location: point,
            outbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-text-peer')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forward-text-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Test venue\nTest address'), findsOneWidget);
      expect(outbox.items, isEmpty);
      await tester.tap(find.byKey(const ValueKey('forward-text-confirm')));
      await tester.pumpAndSettle();
      expect(outbox.items.values.single['messageType'], 'location');
      expect(outbox.items.values.single['location'], point.toJson());
      expect(outbox.items.values.single['text'], '[位置]');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'group forwarding verifies membership and keeps one queued identity on storage retry',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final outbox = RecordingOutbox()..failWrite = true;
      var detailCalls = 0;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000608') return {'items': [], 'hasMore': false};
          if (id == 'K260913000618') {
            return {
              'items': [
                {'groupId': 'group', 'groupName': 'Test group'},
              ],
              'nextCursor': null,
            };
          }
          if (id == 'K260913000619') {
            detailCalls++;
            return {'groupId': 'group', 'membershipVersion': 3, 'members': []};
          }
          if (id == 'K260913000621') {
            return {
              'messages': [],
              'hasMore': false,
              'lastSequence': 0,
              'readSequence': 0,
              'membershipVersion': 3,
              'joinedSequence': 0,
              'settings': {'hiddenThrough': 0},
            };
          }
          if (id == 'K260913000620') throw StateError('offline');
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ForwardTextPage(
            repository: repository,
            text: 'Group forward',
            outbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('群聊'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-text-group')));
      await tester.pump();
      expect(detailCalls, 0);
      expect(outbox.items, isEmpty);
      await confirm(tester);
      expect(detailCalls, 1);
      expect(find.byType(DirectChatPage), findsNothing);
      outbox.failWrite = false;
      await confirm(tester);
      expect(outbox.attempts.toSet().length, 1);
      final queued = outbox.items.values.single;
      expect(queued['groupId'], 'group');
      expect(queued['membershipVersion'], 3);
      expect(queued.containsKey('recipient'), false);
      expect(
        tester.widget<DirectChatPage>(find.byType(DirectChatPage)).groupId,
        'group',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'confirmed text enters durable queue once across storage retry and opens real target',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final outbox = RecordingOutbox()..failWrite = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ForwardTextPage(
            repository: repo(),
            text: 'Forward this',
            outbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-text-peer')));
      await tester.pump();
      expect(outbox.items, isEmpty);
      await confirm(tester);
      expect(find.text('转发未完成，请重试'), findsOneWidget);
      expect(find.byType(DirectChatPage), findsNothing);
      outbox.failWrite = false;
      await confirm(tester);
      expect(outbox.attempts.toSet().length, 1);
      expect(outbox.items.values.single['text'], 'Forward this');
      expect(outbox.items.values.single['recipient'], 'peer');
      expect(find.byType(DirectChatPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'session change during confirmation cannot queue or display old contacts',
    (tester) async {
      final outbox = RecordingOutbox();
      await tester.pumpWidget(
        MaterialApp(
          home: ForwardTextPage(
            repository: repo(),
            text: 'Private',
            outbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forward-text-peer')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forward-text-submit')));
      await tester.pumpAndSettle();
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forward-text-confirm')), findsNothing);
      expect(find.text('Private'), findsNothing);
      expect(outbox.items, isEmpty);
      expect(find.text('Friend'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
