import 'package:flutter/widgets.dart';

import '../data/partner_repository.dart';
import 'partner_tasks_page.dart';
import 'partner_transfer_page.dart';
import 'partner_withdrawal_page.dart';
import 'partner_application_review_page.dart';
import 'partner_platform_page.dart';

Widget partnerNoticeDestination(String? reference, {PartnerCall? call}) {
  call ??= PartnerRepository().call;
  if (reference != null && reference.startsWith('application:')) {
    return PartnerApplicationReviewPage(
      reference: reference.substring(12),
      call: call,
    );
  }
  return switch (reference) {
    'platform' ||
    'platform:approved' ||
    'platform:rejected' => PartnerPlatformPage(call: call),
    'withdrawal' => PartnerWithdrawalPage(call: call),
    'transfer' => PartnerTransferPage(call: call),
    _ => PartnerTasksPage(call: call, kind: 'ledger'),
  };
}
