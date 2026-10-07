import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/partner_repository.dart';
import 'partner_platform_page.dart';
import 'partner_strings.dart';

/// Reloads the authorized current application when opened from a notification.
class PartnerApplicationReviewPage extends StatefulWidget {
  const PartnerApplicationReviewPage({
    super.key,
    required this.reference,
    this.call,
  });
  final String reference;
  final PartnerCall? call;

  @override
  State<PartnerApplicationReviewPage> createState() =>
      _ApplicationReviewState();
}

class _ApplicationReviewState extends State<PartnerApplicationReviewPage> {
  late final PartnerCall call = widget.call ?? PartnerRepository().call;
  late Future<Map<String, dynamic>> result = load();
  Future<Map<String, dynamic>> load() =>
      call({'action': 'application', 'applicationRef': widget.reference});

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data!['item'] is Map) {
        return PartnerApplicationReviewForm(
          item: Map<String, dynamic>.from(snapshot.data!['item'] as Map),
          call: call,
        );
      }
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: kingAppBar(
          context: context,
          title: Text(
            partnerText(context, 'applications'),
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF111111),
        ),
        body: Center(
          child: snapshot.connectionState != ConnectionState.done
              ? const CircularProgressIndicator()
              : TextButton(
                  onPressed: () => setState(() => result = load()),
                  child: Text(partnerText(context, 'failed')),
                ),
        ),
      );
    },
  );
}
