import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

class PartnerCandidatePage extends StatefulWidget {
  const PartnerCandidatePage({
    super.key,
    required this.call,
    required this.taskRef,
    required this.merchant,
  });
  final PartnerCall call;
  final String taskRef;
  final bool merchant;
  @override
  State<PartnerCandidatePage> createState() => _PartnerCandidateState();
}

class _PartnerCandidateState extends State<PartnerCandidatePage> {
  final search = TextEditingController();
  final rows = <Map<String, dynamic>>[];
  StreamSubscription<void>? session;
  bool busy = false, failed = false, invalid = false, more = true;
  int page = 0;
  String query = '';
  String t(String k) => partnerText(context, k);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) {
        setState(() {
          invalid = true;
          rows.clear();
        });
      }
    });
    load();
  }

  @override
  void dispose() {
    session?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (busy || invalid) return;
    if (reset) {
      page = 0;
      query = search.text.trim();
      rows.clear();
      more = true;
    }
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final r = await widget.call({
        'action': 'task_candidates',
        'taskRef': widget.taskRef,
        'page': page,
        'query': query,
      });
      if (!mounted || invalid) return;
      final list = (r['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      setState(() {
        rows.addAll(list);
        page++;
        more = list.length == 30;
      });
    } catch (_) {
      if (mounted && !invalid) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(
        t(widget.merchant ? 'selectMerchant' : 'selectCustomer'),
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xff111111),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: search,
              enabled: !busy && !invalid,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => load(reset: true),
              decoration: InputDecoration(
                hintText: t('candidateSearch'),
                counterText: '',
                suffixIcon: IconButton(
                  onPressed: busy || invalid ? null : () => load(reset: true),
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Text(
                    t('candidateNote'),
                    style: const TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  for (final row in rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xff202020),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          title: Text(row['name'] as String),
                          subtitle:
                              row['address'] is String &&
                                  (row['address'] as String).isNotEmpty
                              ? Text(row['address'] as String)
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: invalid
                              ? null
                              : () => Navigator.pop(context, row),
                        ),
                      ),
                    ),
                  if (invalid)
                    Text(t('sessionChanged'))
                  else if (busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (failed)
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: load,
                        child: Text(t('retry')),
                      ),
                    )
                  else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        t('candidateEmpty'),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (more)
                    TextButton(onPressed: load, child: Text(t('more'))),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
