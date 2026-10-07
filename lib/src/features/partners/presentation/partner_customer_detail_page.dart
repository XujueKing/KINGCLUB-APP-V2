import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/formatters/money.dart';
import '../../profile_settings/presentation/profile_choices.dart';
import '../data/partner_repository.dart';
import 'customer_components.dart';

class PartnerCustomerDetailPage extends StatefulWidget {
  const PartnerCustomerDetailPage({
    super.key,
    required this.call,
    required this.targetAccount,
  });
  final PartnerCall call;
  final String targetAccount;
  @override
  State<PartnerCustomerDetailPage> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<PartnerCustomerDetailPage> {
  static const tabs = ['profile', 'ledger', 'notes'];
  final note = TextEditingController();
  Map<String, dynamic>? data, pendingNote;
  final records = <Map<String, dynamic>>[];
  String tab = 'profile', month = '';
  int page = 0, epoch = 0, total = 0;
  bool busy = false,
      failed = false,
      saving = false,
      saveFailed = false,
      statusBusy = false,
      more = false;
  String t(String key) => customerText(context, key);
  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = '${n.year}-${n.month.toString().padLeft(2, '0')}';
    load(reset: true);
  }

  @override
  void dispose() {
    epoch++;
    note.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (busy && !reset) return;
    final generation = ++epoch;
    if (reset) {
      records.clear();
      page = 0;
      more = false;
    }
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final r = await widget.call({
        'action': 'customer_detail',
        'targetAccount': widget.targetAccount,
        'tab': tab,
        'page': page,
        if (tab == 'ledger') 'month': month,
      });
      if (!mounted || generation != epoch) return;
      setState(() {
        if (tab == 'profile') {
          data = r;
        } else {
          final rows = (r['items'] as List).map(
            (v) => Map<String, dynamic>.from(v as Map),
          );
          for (final row in rows) {
            if (!records.any((v) => v['ref'] == row['ref'])) records.add(row);
          }
          total = (r['total'] as num).toInt();
          page++;
          more = total > page * 30;
        }
      });
    } catch (_) {
      if (mounted && generation == epoch) setState(() => failed = true);
    } finally {
      if (mounted && generation == epoch) setState(() => busy = false);
    }
  }

  Future<void> saveNote() async {
    if (saving || (pendingNote == null && note.text.trim().isEmpty)) return;
    pendingNote ??= {
      'action': 'customer_note',
      'targetAccount': widget.targetAccount,
      'requestId': const Uuid().v4(),
      'content': note.text.trim(),
    };
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      saveFailed = false;
    });
    try {
      final r = await widget.call(pendingNote!);
      if (!mounted) return;
      setState(() {
        final entry = Map<String, dynamic>.from(r['record'] as Map);
        if (tab == 'notes' && !records.any((v) => v['ref'] == entry['ref'])) {
          records.insert(0, entry);
          total++;
        }
        pendingNote = null;
        note.clear();
      });
    } catch (_) {
      if (mounted) setState(() => saveFailed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changeStatus(bool active) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(t(active ? 'restore' : 'restrict')),
          content: TextField(
            key: const ValueKey('customer-status-reason'),
            controller: reason,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => update(() {}),
            decoration: InputDecoration(hintText: t('reason')),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, kingControlHeight),
                      shape: kingActionButtonShape,
                    ),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(t('cancel')),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, kingControlHeight),
                      shape: kingActionButtonShape,
                    ),
                    onPressed: reason.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(dialogContext, true),
                    child: Text(t('confirm')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final explanation = reason.text.trim();
    // The dialog route may still be animating; dispose after it has released the field.
    Future<void>.delayed(const Duration(milliseconds: 350), reason.dispose);
    if (accepted != true || !mounted) return;
    final customer = Map<String, dynamic>.from(data!['customer'] as Map);
    setState(() => statusBusy = true);
    try {
      final r = await widget.call({
        'action': 'customer_status',
        'targetAccount': widget.targetAccount,
        'requestId': const Uuid().v4(),
        'expectedStatus': customer['status'],
        'status': active ? 'active' : 'suspended',
        'reason': explanation,
      });
      if (mounted) {
        setState(() => (data!['customer'] as Map)['status'] = r['status']);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('changed'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('stateFailed'))));
        await load(reset: true);
      }
    } finally {
      if (mounted) setState(() => statusBusy = false);
    }
  }

  Future<void> chooseMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.parse('$month-01'),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: t('month'),
    );
    if (date != null && mounted) {
      month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      await load(reset: true);
    }
  }

  Widget line(String label, Object? value, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value?.toString() ?? t('unavailable'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
  Widget metrics(List<(String, Object?)> values, {int columns = 3}) =>
      LayoutBuilder(
        builder: (context, c) => Wrap(
          runSpacing: 22,
          spacing: 8,
          children: [
            for (final v in values)
              SizedBox(
                width: (c.maxWidth - 8 * (columns - 1)) / columns,
                child: Column(
                  children: [
                    Text(
                      v.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.$2?.toString() ?? '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
  String relation(Object? raw) {
    if (raw is! Map) return t('unavailable');
    return '${raw['name']} (${raw['memberId']})';
  }

  String preference(Map prefs, String field) {
    final values = prefs[field];
    if (values is! List || values.isEmpty) return t('unavailable');
    final choices = preferenceChoices[field] ?? [];
    return values
        .map((v) {
          for (final choice in choices) {
            if (choice.id == v) return choice.label;
          }
          return v.toString();
        })
        .join('、');
  }

  List<Widget> profile() {
    if (data == null) return [];
    final c = Map<String, dynamic>.from(data!['customer'] as Map),
        assets = Map<String, dynamic>.from(c['assets'] as Map? ?? {}),
        stats = Map<String, dynamic>.from(c['stats'] as Map? ?? {}),
        appearance = Map<String, dynamic>.from(c['appearance'] as Map? ?? {}),
        prefs = Map<String, dynamic>.from(c['preferences'] as Map? ?? {});
    final paid = data!['consumption'] as List? ?? [];
    final amounts = paid.isEmpty
        ? customerAmount('0')
        : paid
              .map(
                (v) =>
                    customerAmount(v['amountCents'], v['currency'] as String),
              )
              .join('\n');
    final phone = c['phone'] as String?;
    return [
      CustomerPanel(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CustomerAvatar(customer: c, size: 82),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      customerName(c, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        c['levelName'] as String? ?? '—',
                        style: const TextStyle(
                          color: customerGold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            line(t('memberId'), c['memberId']),
            line(
              t('birthday'),
              c['birthDate'] == null
                  ? null
                  : '${c['age']} ${t('years')} (${(c['birthDate'] as String).substring(5)})',
            ),
            line(
              t('phone'),
              phone,
              trailing: phone == null
                  ? null
                  : IconButton(
                      tooltip: t('copy'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: phone));
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(t('copied'))));
                        }
                      },
                      icon: const Icon(Icons.content_copy, size: 18),
                    ),
            ),
          ],
        ),
      ),
      CustomerPanel(
        child: metrics([
          (t('orders'), groupMoney('${stats['orderCount'] ?? 0}')),
          (t('consumption'), amounts),
          (t('commission'), customerAmount(data!['commissionCents'])),
        ]),
      ),
      CustomerPanel(
        child: metrics([
          (t('rank'), c['levelName']),
          (t('platformBalance'), customerAmount(assets['cashCents'])),
          (t('coins'), groupMoney('${assets['coins'] ?? 0}')),
          (t('diamonds'), groupMoney('${assets['diamonds'] ?? 0}')),
        ], columns: 2),
      ),
      CustomerPanel(
        child: metrics([
          (t('appearance'), appearance['score']),
          (t('selfie'), appearance['selfie']),
          (t('portrait'), appearance['portrait']),
          (t('outfit'), appearance['outfit']),
        ], columns: 2),
      ),
      CustomerPanel(
        child: metrics([
          (t('friends'), groupMoney('${stats['friendCount'] ?? 0}')),
          (t('messages'), groupMoney('${stats['messageCount'] ?? 0}')),
          (t('team'), groupMoney('${stats['teamCount'] ?? 0}')),
        ]),
      ),
      CustomerPanel(
        child: Column(
          children: [
            line(
              t('status'),
              t(c['status'] == 'active' ? 'active' : 'suspended'),
              trailing:
                  (data!['canSetStatus'] == true || data!['canSetStatus'] == 1)
                  ? Switch(
                      key: const ValueKey('customer-status'),
                      value: c['status'] == 'active',
                      onChanged: statusBusy ? null : changeStatus,
                      activeThumbColor: customerGold,
                    )
                  : null,
            ),
            line(t('date'), customerDate(c['date'])),
            line(t('city'), c['city']),
            line(t('referrer'), relation(c['referrer'])),
            if (c['parent'] != null) line(t('parent'), relation(c['parent'])),
            for (final field in ['styles', 'music', 'drinks', 'events'])
              line(t(field), preference(prefs, field)),
          ],
        ),
      ),
      if ((data!['storeBalances'] as List? ?? []).isNotEmpty)
        CustomerPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('storeBalances'),
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 10),
              for (final raw in data!['storeBalances'] as List)
                line(
                  raw['store'] as String,
                  customerAmount(raw['amountCents'], raw['currency'] as String),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          t('recordScope'),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    ];
  }

  Widget record(Map<String, dynamic> r) => CustomerPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tab == 'ledger') ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t(
                    r['type'] == 'commission'
                        ? 'commission'
                        : r['type'] as String,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                customerAmount(r['amountCents'], r['currency'] as String),
                style: const TextStyle(
                  color: customerGold,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r['title'] as String,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ] else ...[
          if (r['type'] == 'status')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t('statusRecord'),
                style: const TextStyle(color: customerGold, fontSize: 15),
              ),
            ),
          Text(
            r['content'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            r['operator'] as String,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          customerDate(r['date']),
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        if (tab == 'ledger') ...[
          const SizedBox(height: 4),
          Text(
            r['ref'] as String,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(t('detail')),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: Column(
        children: [
          CustomerTabs(
            labels: [for (final key in tabs) t(key)],
            onTap: (i) {
              tab = tabs[i];
              load(reset: true);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => load(reset: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (tab == 'profile' && !failed && !busy) ...profile(),
                  if (tab == 'ledger')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: chooseMonth,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                          ),
                          label: Text(month),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, kingControlHeight),
                            shape: kingActionButtonShape,
                          ),
                        ),
                      ),
                    ),
                  if (tab == 'notes')
                    CustomerPanel(
                      child: Column(
                        children: [
                          TextField(
                            key: const ValueKey('customer-note'),
                            controller: note,
                            readOnly: pendingNote != null,
                            maxLength: 1000,
                            minLines: 3,
                            maxLines: 6,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: t('noteInput'),
                              border: InputBorder.none,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: kingControlHeight,
                            child: FilledButton(
                              key: const ValueKey('customer-save-note'),
                              onPressed:
                                  saving ||
                                      (note.text.trim().isEmpty &&
                                          pendingNote == null)
                                  ? null
                                  : saveNote,
                              style: FilledButton.styleFrom(
                                backgroundColor: customerGold,
                                foregroundColor: Colors.black,
                                shape: kingActionButtonShape,
                              ),
                              child: Text(t(saveFailed ? 'retry' : 'save')),
                            ),
                          ),
                          if (saveFailed)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                t('savingFailed'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (tab != 'profile')
                    for (final r in records) record(r),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!busy && failed)
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            load(reset: tab == 'profile' || records.isEmpty),
                        child: Text(t('failed')),
                      ),
                    ),
                  if (tab != 'profile' && !busy && !failed && records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text(t('empty'))),
                    ),
                  if (tab != 'profile' && !busy && !failed && more)
                    TextButton(onPressed: load, child: Text(t('more'))),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
