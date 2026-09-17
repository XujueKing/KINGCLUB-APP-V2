import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/peer_file_authority.dart';

void main() {
  const message = '00000000-0000-4000-8000-000000000001';
  const asset = '00000000-0000-4000-8000-000000000002';
  const group = '00000000-0000-4000-8000-000000000003';
  Map<String, dynamic> manifest() => {
    'messageId': message,
    'sender': 'me',
    'recipient': 'peer',
    'assetId': asset,
    'fileName': 'file.bin',
    'size': 3,
    'sha256': 'a' * 64,
    'groupId': group,
    'senderMembershipVersion': 2,
    'recipientMembershipVersion': 5,
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(seconds: 15))
        .toIso8601String(),
  };
  Future<PeerFileAuthority> read(
    Map<String, dynamic> data, {
    String? groupId = group,
    bool sending = true,
  }) => PeerFileAuthority.read(
    MessagingRepository(
      account: 'me',
      call: (api, params) async {
        expect(api, 'K260916000686');
        expect(params, {
          'messageId': message,
          'peer': 'peer',
          if (groupId != null) 'group': true,
        });
        return data;
      },
    ),
    'peer',
    message,
    sending: sending,
    groupId: groupId,
  );
  test('renewal binds group and both membership epochs', () async {
    final first = await read(manifest());
    expect(first.sameFile(await read(manifest())), isTrue);
    for (final field in [
      'senderMembershipVersion',
      'recipientMembershipVersion',
    ]) {
      expect(first.sameFile(await read({...manifest(), field: 6})), isFalse);
    }
    final another = await read({
      ...manifest(),
      'groupId': asset,
    }, groupId: asset);
    expect(first.sameFile(another), isFalse);
  });
  test('receiver validates original sender and receiver versions', () async {
    final authority = await read({
      ...manifest(),
      'sender': 'peer',
      'recipient': 'me',
    }, sending: false);
    expect(authority.senderMembershipVersion, 2);
    expect(authority.recipientMembershipVersion, 5);
  });
  test('direct and group authority cannot be substituted', () async {
    await expectLater(read(manifest(), groupId: null), throwsFormatException);
    final direct = manifest()
      ..remove('groupId')
      ..remove('senderMembershipVersion')
      ..remove('recipientMembershipVersion');
    await expectLater(read(direct), throwsFormatException);
    final authority = await read(direct, groupId: null);
    expect(authority.groupId, isNull);
    expect(authority.sameFile(await read(manifest())), isFalse);
  });
  test('malformed or mismatched group identity is rejected', () async {
    for (final id in [null, asset, 123, 'bad']) {
      await expectLater(
        read({...manifest(), 'groupId': id}),
        throwsFormatException,
      );
    }
    await expectLater(read(manifest(), groupId: 'bad'), throwsFormatException);
  });
  test('both membership epochs must be unsigned integers', () async {
    for (final field in [
      'senderMembershipVersion',
      'recipientMembershipVersion',
    ]) {
      for (final value in [null, -1, 4294967296, 2.0, '2']) {
        await expectLater(
          read({...manifest(), field: value}),
          throwsFormatException,
        );
      }
      await expectLater(read(manifest()..remove(field)), throwsFormatException);
    }
  });
}
