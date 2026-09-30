import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_journal.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_repository.dart';

import 'member_recharge_result_test.dart' as receipt;
import 'member_recharge_repository_test.dart' as api;

MemberRechargeRequest request({
  String member = 'TEST_MEMBER',
  String store = 'TEST_STORE',
  String suffix = '1',
}) => MemberRechargeRequest(
  baseUrl: 'https://service.invalid',
  userAccount: member,
  storeRef: store,
  requestId: '00000000-0000-4000-8000-00000000000$suffix',
  campaignRef: 'TEST_OFFER',
  campaignRevision: 1,
  channel: 'wechat',
);
void main() {
  test(
    'concurrent instances serialize writes without losing either original',
    () async {
      String? saved;
      final writing = Completer<void>(), release = Completer<void>();
      var writes = 0;
      MemberRechargeJournal journal() => MemberRechargeJournal(
        read: () async => saved,
        write: (value) async {
          writes++;
          if (writes == 1) {
            writing.complete();
            await release.future;
          }
          saved = value;
        },
      );
      final first = journal().save(request());
      await writing.future;
      final second = journal().save(request(member: 'OTHER'));
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      release.complete();
      await Future.wait([first, second]);
      expect(writes, 2);
      expect((jsonDecode(saved!) as List).length, 2);
      expect(
        await journal().load(
          baseUrl: 'https://service.invalid',
          userAccount: 'TEST_MEMBER',
        ),
        hasLength(1),
      );
      expect(
        await journal().load(
          baseUrl: 'https://service.invalid',
          userAccount: 'OTHER',
        ),
        hasLength(1),
      );
    },
  );
  test('credited acknowledgement removes only the exact original and preserves other members', () async {
    String? saved;
    final journal = MemberRechargeJournal(
      read: () async => saved,
      write: (v) async {
        saved = v;
      },
    );
    await journal.save(request());
    await journal.save(request(member: 'OTHER'));
    final original = MemberRechargeOriginal.parse(
      api.original(),
      storeRef: 'TEST_STORE',
      channel: 'wechat',
    );
    await journal.acknowledge(
      request(),
      original,
      receipt.parse(receipt.credited()),
    );
    expect(
      await journal.load(
        baseUrl: 'https://service.invalid',
        userAccount: 'TEST_MEMBER',
      ),
      isEmpty,
    );
    expect(
      (await journal.load(
        baseUrl: 'https://service.invalid',
        userAccount: 'OTHER',
      )).length,
      1,
    );
    await journal.acknowledge(
      request(),
      original,
      receipt.parse(receipt.credited()),
    );
    expect(
      (await journal.load(
        baseUrl: 'https://service.invalid',
        userAccount: 'OTHER',
      )).length,
      1,
    );
  });
  test(
    'pending, wrong member and replaced request never clear original',
    () async {
      String? saved;
      final journal = MemberRechargeJournal(
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      await journal.save(request());
      final original = MemberRechargeOriginal.parse(
        api.original(),
        storeRef: 'TEST_STORE',
        channel: 'wechat',
      );
      final confirmed = receipt.parse(receipt.credited());
      await expectLater(
        journal.acknowledge(
          request(),
          original,
          receipt.parse({
            'state': 'credit_pending',
            'rechargeRef': api.request,
          }),
        ),
        throwsStateError,
      );
      await expectLater(
        journal.acknowledge(request(member: 'OTHER'), original, confirmed),
        throwsStateError,
      );
      await expectLater(
        journal.acknowledge(request(suffix: '2'), original, confirmed),
        throwsStateError,
      );
      expect(
        (await journal.load(
          baseUrl: 'https://service.invalid',
          userAccount: 'TEST_MEMBER',
        )).length,
        1,
      );
    },
  );
  test(
    'readback persistence survives another instance and isolates members',
    () async {
      String? saved;
      MemberRechargeJournal journal() => MemberRechargeJournal(
        read: () async => saved,
        write: (v) async {
          saved = v;
        },
      );
      await journal().save(request());
      await journal().save(request(member: 'OTHER'));
      final rows = await journal().load(
        baseUrl: 'https://service.invalid',
        userAccount: 'TEST_MEMBER',
      );
      expect(rows.length, 1);
      expect(rows.single.requestId, request().requestId);
      expect((jsonDecode(saved!) as List).length, 2);
      expect(jsonDecode(saved!)[0].keys.toSet(), {
        'baseUrl',
        'userAccount',
        'storeRef',
        'requestId',
        'campaignRef',
        'campaignRevision',
        'channel',
      });
      expect(() => rows.clear(), throwsUnsupportedError);
    },
  );
  test(
    'same request is idempotent; new original cannot replace unresolved one',
    () async {
      String? saved;
      var writes = 0;
      final journal = MemberRechargeJournal(
        read: () async => saved,
        write: (v) async {
          writes++;
          saved = v;
        },
      );
      await journal.save(request());
      await journal.save(request());
      await expectLater(journal.save(request(suffix: '2')), throwsStateError);
      expect(writes, 1);
    },
  );
  test(
    'failed readback and corrupt storage never silently reset records',
    () async {
      final lost = MemberRechargeJournal(
        read: () async => null,
        write: (v) async {},
      );
      await expectLater(lost.save(request()), throwsStateError);
      var writes = 0;
      final corrupt = MemberRechargeJournal(
        read: () async => 'broken',
        write: (v) async {
          writes++;
        },
      );
      await expectLater(corrupt.save(request()), throwsFormatException);
      expect(writes, 0);
    },
  );
  test(
    'duplicate scopes and unknown fields in saved rows are rejected',
    () async {
      for (final raw in [
        [request().encoded, request(suffix: '2').encoded],
        [
          {...request().encoded, 'authCode': 'TEST_ONLY'},
        ],
      ]) {
        final journal = MemberRechargeJournal(
          read: () async => jsonEncode(raw),
        );
        await expectLater(
          journal.load(
            baseUrl: 'https://service.invalid',
            userAccount: 'TEST_MEMBER',
          ),
          throwsA(anything),
        );
      }
    },
  );
}
