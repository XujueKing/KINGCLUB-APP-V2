import 'package:flutter/material.dart';

import '../data/partner_repository.dart';
import 'partner_payout_form.dart';

class PartnerTransferPage extends StatelessWidget {
  const PartnerTransferPage({super.key, required this.call});
  final PartnerCall call;
  @override
  Widget build(BuildContext context) =>
      PartnerPayoutForm(call: call, withdrawal: false);
}
