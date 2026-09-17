import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_file_device_scope.dart';

void main() {
  const message = '11111111-1111-4111-8111-111111111111';
  const group = '22222222-2222-4222-8222-222222222222';
  final valid = <String, dynamic>{
    'kind': 'group-file',
    'messageId': message,
    'groupId': group,
    'sender': 'me',
    'recipient': 'peer',
    'senderMembershipVersion': 0,
    'recipientMembershipVersion': 4294967295,
  };
  GroupFileDeviceScope parse(Object? raw) => GroupFileDeviceScope.parse(
    raw,
    messageId: message,
    groupId: group,
    account: 'me',
    peer: 'peer',
  );
  test('scope binds direction and membership epochs', () {
    final first = parse(valid);
    expect(first.samePermission(parse(valid)), isTrue);
    for (final changed in [
      {'sender': 'peer', 'recipient': 'me'},
      {'senderMembershipVersion': 1},
      {'recipientMembershipVersion': 1},
    ]) {
      expect(first.samePermission(parse({...valid, ...changed})), isFalse);
    }
  });
  test('rejects other message, group, member or malformed membership', () {
    for (final change in [
      {'kind': 'direct'},
      {'messageId': group},
      {'groupId': message},
      {'sender': 'outsider'},
      {'recipient': 'outsider'},
      {'senderMembershipVersion': -1},
      {'recipientMembershipVersion': 4294967296},
      {'senderMembershipVersion': 1.0},
      {'recipientMembershipVersion': '1'},
      {'senderMembershipVersion': null},
    ]) {
      expect(() => parse({...valid, ...change}), throwsFormatException);
    }
    expect(() => parse(null), throwsFormatException);
  });
}
