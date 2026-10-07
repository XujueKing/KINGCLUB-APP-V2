import 'package:flutter/widgets.dart';

import '../data/partner_repository.dart';
import '../../messaging/data/system_notices_controller.dart';
import 'partner_tasks_page.dart';
import 'partner_withdrawal_history_page.dart';
import 'partner_application_review_page.dart';
import 'partner_platform_page.dart';
import 'partner_messages_page.dart';

Widget partnerNoticeDestination(
  String? reference, {
  PartnerCall? call,
  SystemNoticesController? inbox,
}) {
  call ??= PartnerRepository().call;
  if (reference == 'messages') {
    return PartnerMessagesPage(call: call, inbox: inbox);
  }
  if (reference != null && reference.startsWith('application:')) {
    return PartnerApplicationReviewPage(
      reference: reference.substring(12),
      call: call,
    );
  }
  return switch (reference) {
    'platform' ||
    'platform:approved' ||
    'platform:rejected' => PartnerPlatformPage(call: call, inbox: inbox),
    'withdrawal' || 'transfer' => PartnerWithdrawalHistoryPage(call: call),
    _ => PartnerTasksPage(call: call, kind: 'ledger'),
  };
}
