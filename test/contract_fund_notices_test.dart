import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/presentation/monthly_contracts_page.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_controller.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_repository.dart';
import 'package:kingclub/src/features/partners/presentation/partner_notice_destination.dart';

void main() {
  const contract = '018fde35-1407-7000-8000-000000000001';
  test('each contract event is readable and links to its exact contract', () {
    for (final kind in [
      'partner_contract_received',
      'partner_contract_refunded',
      'partner_contract_completed',
    ]) {
      final notice = SystemNotice.parse({
        'noticeRef': 'a' * 64,
        'kind': kind,
        'occurredAt': '2030-01-01T00:00:00.000Z',
        'read': false,
        'amountCents': kind.endsWith('completed') ? null : 100000,
        'details': [
          {'label': 'store', 'value': 'Test store'},
          {'label': 'table', 'value': 'V1'},
        ],
        'target': {'kind': 'partner', 'reference': 'contract:$contract'},
      });
      expect(notice.asRead().read, isTrue);
      expect(notice.asRead().target, notice.target);
      final destination = partnerNoticeDestination(
        notice.target!['reference'],
        call: (_) async => {},
      );
      expect(destination, isA<MonthlyContractDetailPage>());
      expect((destination as MonthlyContractDetailPage).contractRef, contract);
    }
  });

  test('received funds notify once and retain server unread count', () async {
    var rows = <Map<String, dynamic>>[];
    final arrivals = <SystemNotice>[];
    final subscription = SystemNoticesController.arrivals.listen(
      (event) => arrivals.add(event.notice),
    );
    final controller = SystemNoticesController(
      SystemNoticesRepository(
        readSession: () async => {
          'sessionId': 'test',
          'apiKeyId': 'test',
          'apiKey': 'test',
          'account': {'userAccount': 'synthetic'},
        },
      request: (_, params, _) async {
          expect(params['contractNotices'], 1);
          return {
            'result': {
              'notices': rows,
              'nextBeforeNotice': null,
              'unreadCount': rows.length,
              'highWaterSequence': rows.isEmpty ? null : '1',
              'latest': rows.isEmpty ? null : rows.first,
            },
          };
        },
      ),
    );
    addTearDown(subscription.cancel);
    addTearDown(controller.dispose);
    await controller.refresh();
    rows = [
      {
        'noticeRef': 'b' * 64,
        'kind': 'partner_contract_received',
        'occurredAt': '2030-01-01T00:00:00.000Z',
        'read': false,
        'amountCents': 100000,
        'details': [],
        'target': {'kind': 'partner', 'reference': 'contract:$contract'},
      },
    ];
    await controller.refresh();
    await controller.refresh();
    expect(arrivals.length, 1);
    expect(controller.summary.unreadCount, 1);
    expect(
      controller.notices.single.target!['reference'],
      'contract:$contract',
    );
  });
}
