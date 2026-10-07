import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/formatters/money.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';
import 'partner_tasks_page.dart';

class PartnerRecordsPage extends StatefulWidget {
  const PartnerRecordsPage({super.key, required this.call, required this.kind});
  final PartnerCall call;
  final String kind;
  @override
  State<PartnerRecordsPage> createState() => _RecordsState();
}

class _RecordsState extends State<PartnerRecordsPage> {
  final rows = <Map<String, dynamic>>[];
  bool busy = false, failed = false, more = true;
  int page = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await widget.call({'action': widget.kind, 'page': page});
      if (!mounted) return;
      final next = (result['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      setState(() {
        rows.addAll(next);
        page++;
        more = next.length == 30;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String k) => partnerText(context, k);
    final task = widget.kind == 'task_records';
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t(task ? 'taskRecords' : 'myParties')),
        backgroundColor: const Color(0xff111111),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final row in rows)
            Card(
              color: const Color(0xff202020),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['title'] as String,
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(
                        task
                            ? (row['status'] == 'rejected'
                                  ? 'taskRejected'
                                  : row['status'] as String)
                            : 'party_${row['status']}',
                      ),
                      style: const TextStyle(color: Color(0xffcebea4)),
                    ),
                    const SizedBox(height: 10),
                    Text('${row[task ? 'date' : 'startsAt'] ?? ''}'),
                    if (!task) ...[
                      Text('${row['endsAt'] ?? ''}'),
                      const SizedBox(height: 10),
                      Text(
                        '${t('commission')} ¥${moneyCents(row['amountCents'])}',
                      ),
                      Text(
                        '${t('partyRef')} ${row['ref']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                    if (task) ...[
                      if (row['status'] == 'approved')
                        Text('¥${moneyCents(row['rewardCents'])}'),
                      if ((row['reason'] as String? ?? '').isNotEmpty)
                        Text(row['reason'] as String),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PartnerTasksPage(
                              call: widget.call,
                              taskRef: row['taskRef'] as String,
                            ),
                          ),
                        ),
                        child: Text(t('details')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (failed) TextButton(onPressed: load, child: Text(t('retry'))),
          if (!busy && !failed && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(t('empty'))),
            ),
          if (more && rows.isNotEmpty && !busy)
            TextButton(onPressed: load, child: Text(t('more'))),
        ],
      ),
    );
  }
}
