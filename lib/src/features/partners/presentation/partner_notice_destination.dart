import 'package:flutter/widgets.dart';

import '../data/partner_repository.dart';
import 'partner_tasks_page.dart';
import 'partner_transfer_page.dart';
import 'partner_withdrawal_page.dart';

Widget partnerNoticeDestination(String? reference) {
  final call = PartnerRepository().call;
  return switch (reference) {
    'withdrawal' => PartnerWithdrawalPage(call: call),
    'transfer' => PartnerTransferPage(call: call),
    _ => PartnerTasksPage(call: call, kind: 'ledger'),
  };
}
