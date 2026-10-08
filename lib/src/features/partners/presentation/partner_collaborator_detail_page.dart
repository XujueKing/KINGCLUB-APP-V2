import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/formatters/money.dart';
import '../data/partner_repository.dart';
import 'collaborator_components.dart';
import 'customer_components.dart';
import 'partner_customer_detail_page.dart';
import 'partner_assignment_page.dart';

class PartnerCollaboratorDetailPage extends StatefulWidget {
  const PartnerCollaboratorDetailPage({
    super.key,
    required this.call,
    required this.targetAccount,
    this.section = 'overview',
  });
  final PartnerCall call;
  final String targetAccount, section;
  @override
  State<PartnerCollaboratorDetailPage> createState() =>
      _CollaboratorDetailState();
}

class _CollaboratorDetailState extends State<PartnerCollaboratorDetailPage> {
  Map<String, dynamic>? data;
  final items = <Map<String, dynamic>>[];
  int page = 0, epoch = 0;
  bool busy = false, failed = false, more = false;
  String t(String key) => collaboratorText(context, key);
  String c(String key) => customerText(context, key);
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void dispose() {
    epoch++;
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (busy && !reset) return;
    final generation = ++epoch;
    if (reset) {
      page = 0;
      data = null;
      items.clear();
      more = false;
    }
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await widget.call({
        'action': 'collaborator_detail',
        'targetAccount': widget.targetAccount,
        'tab': widget.section,
        'page': page,
      });
      if (!mounted || generation != epoch) return;
      setState(() {
        data = result;
        items.addAll(
          (result['items'] as List? ?? []).map(
            (v) => Map<String, dynamic>.from(v as Map),
          ),
        );
        more = result['hasMore'] == true || result['hasMore'] == 1;
        page++;
      });
    } catch (_) {
      if (mounted && generation == epoch) setState(() => failed = true);
    } finally {
      if (mounted && generation == epoch) setState(() => busy = false);
    }
  }

  Future<void> open(String section, {String? account}) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => PartnerCollaboratorDetailPage(
        call: widget.call,
        targetAccount: account ?? widget.targetAccount,
        section: section,
      ),
    ),
  );
  Future<void> assign(Map<String, dynamic> partner) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartnerAssignmentPage(call: widget.call, partner: partner),
      ),
    );
    if (mounted && result != null) setState(() => data = result);
  }

  Widget label(String value, {Color color = Colors.white, double size = 16}) =>
      Text(
        value,
        style: TextStyle(color: color, fontSize: size, height: 1.4),
      );
  Widget pair(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        label(title, color: Colors.white60),
        label(value),
      ],
    ),
  );
  Widget heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: label(value, size: 18),
  );
  Widget metrics(
    Map<String, dynamic> values,
    List<String> keys, {
    bool amounts = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          MediaQuery.textScalerOf(context).scale(16) > 24 ||
              constraints.maxWidth < 260
          ? 1
          : 2;
      return Wrap(
        spacing: 16,
        runSpacing: 20,
        children: [
          for (final key in keys)
            SizedBox(
              width: (constraints.maxWidth - 16 * (columns - 1)) / columns,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label(t(key), color: Colors.white60, size: 14),
                  const SizedBox(height: 6),
                  label(
                    amounts
                        ? customerAmount(
                            values[key],
                            values['currency'] as String? ?? 'CNY',
                          )
                        : groupMoney('${values[key] ?? 0}'),
                    size: amounts ? 22 : 20,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
  List<Widget> overview() {
    final p = Map<String, dynamic>.from(data!['partner'] as Map),
        f = Map<String, dynamic>.from(data!['finance'] as Map),
        stats = Map<String, dynamic>.from(data!['stats'] as Map);
    final parent = p['parent'] as Map?;
    final coverage = [
      p['coverageProvince'],
      p['coverageCity'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(' · ');
    return [
      CustomerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomerAvatar(customer: p, size: 72),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      collaboratorName(context, p, size: 20),
                      const SizedBox(height: 6),
                      label(
                        p['memberId'] as String? ?? '—',
                        color: Colors.white60,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            pair(t('level'), collaboratorLevel(p)),
            if (p['partnerRole'] != 'superadmin')
              pair(t('city'), p['city'] as String? ?? c('unavailable')),
            pair(
              t('coverage'),
              p['partnerRole'] == 'superadmin'
                  ? t('allRegions')
                  : coverage.isEmpty
                  ? t('unassigned')
                  : coverage,
            ),
            pair(
              t('parent'),
              parent == null
                  ? t('direct')
                  : '${parent['name']} · ${parent['memberId']}',
            ),
            pair(t('joined'), customerDate(p['joinedAt'])),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                label(c('phone'), color: Colors.white60),
                label(p['phone'] as String? ?? c('unavailable')),
                if (p['phone'] is String && (p['phone'] as String).isNotEmpty)
                  IconButton(
                    tooltip: c('copy'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: p['phone'] as String),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(c('copied'))));
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18, color: customerGold),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            label(
              t(p['status'] as String? ?? 'not_enrolled'),
              color: customerGold,
            ),
            if (data!['canAssign'] == true || data!['canAssign'] == 1)
              TextButton(
                key: const ValueKey('collaborator-assign'),
                onPressed: () => assign(p),
                child: Text(
                  t('assign'),
                  style: const TextStyle(color: customerGold, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
      CustomerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label(
              '${t('cumulativeCents')} · ${f['currency']}',
              color: Colors.white60,
            ),
            const SizedBox(height: 10),
            label(
              customerAmount(f['cumulativeCents'], f['currency'] as String),
              size: 32,
            ),
            const SizedBox(height: 24),
            metrics(f, [
              'monthlyCents',
              'availableCents',
              'pendingCents',
              'frozenCents',
              'paidCents',
              'transferredCents',
              'commissionCents',
              'rewardCents',
            ], amounts: true),
            const SizedBox(height: 20),
            label(t('ledgerScope'), color: Colors.white54, size: 13),
          ],
        ),
      ),
      CustomerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(t('work')),
            metrics(stats, [
              'teamCount',
              'memberCount',
              'taskCount',
              'completedCount',
              'ongoingCount',
              'reviewCount',
              'rejectedCount',
              'partyCount',
            ]),
          ],
        ),
      ),
      CustomerPanel(
        child: Column(
          children: [
            for (final section in [
              'team',
              'members',
              'tasks',
              'commissions',
              'withdrawals',
            ]) ...[
              if (section != 'team')
                const Divider(height: 1, color: Colors.white12),
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: ValueKey('collaborator-$section'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 64,
                  title: label(t(section)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: customerGold,
                    size: 20,
                  ),
                  onTap: () => open(section),
                ),
              ),
            ],
          ],
        ),
      ),
      if (p['introduction'] is String &&
          (p['introduction'] as String).isNotEmpty)
        CustomerPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(t('introduction')),
              label(p['introduction'] as String, color: Colors.white70),
            ],
          ),
        ),
      if ((data!['assignmentHistory'] as List? ?? []).isNotEmpty)
        CustomerPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(t('assignmentHistory')),
              for (final raw in data!['assignmentHistory'] as List) ...[
                label(
                  '${raw['operator']} · ${customerDate(raw['date'])}',
                  color: Colors.white60,
                  size: 14,
                ),
                label('${raw['reason']}', color: Colors.white70),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
    ];
  }

  Widget record(Map<String, dynamic> item) {
    if (['members', 'team'].contains(widget.section)) {
      return CustomerPanel(
        child: InkWell(
          onTap: () => widget.section == 'team'
              ? open('overview', account: item['ref'] as String)
              : Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PartnerCustomerDetailPage(
                      call: widget.call,
                      targetAccount: item['ref'] as String,
                    ),
                  ),
                ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomerAvatar(customer: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.section == 'team')
                      collaboratorName(context, item)
                    else
                      customerName(item),
                    const SizedBox(height: 6),
                    label(
                      item['memberId'] as String? ?? '—',
                      color: Colors.white60,
                      size: 14,
                    ),
                    label(
                      item['phone'] as String? ?? c('unavailable'),
                      size: 16,
                    ),
                    label(
                      customerDate(item['date']),
                      color: Colors.white54,
                      size: 14,
                    ),
                    if (widget.section == 'team')
                      label(
                        '${t('level')} ${collaboratorLevel(item)}',
                        color: customerGold,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: customerGold, size: 20),
            ],
          ),
        ),
      );
    }
    final status = item['status'] as String?,
        kind = item['kind'] as String?,
        amount = item['amountCents'] ?? item['rewardCents'];
    return CustomerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item['title'] != null) heading('${item['title']}'),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (kind != null && collaboratorCopy.containsKey(kind))
                label(t(kind), color: Colors.white70),
              if (amount != null)
                label(
                  customerAmount(amount, item['currency'] as String? ?? 'CNY'),
                  size: 22,
                ),
              if (status != null)
                label(
                  collaboratorCopy.containsKey(status) ? t(status) : status,
                  color: customerGold,
                ),
            ],
          ),
          const SizedBox(height: 8),
          label(customerDate(item['date']), color: Colors.white54, size: 14),
          if (item['memberId'] != null)
            pair(c('memberId'), '${item['memberId']}'),
          if (item['availableAt'] != null)
            pair(t('availableAt'), customerDate(item['availableAt'])),
          if (item['paidAt'] != null)
            pair(t('paidAt'), customerDate(item['paidAt'])),
          if (item['channel'] != null)
            label(t(item['channel'] as String), color: Colors.white70),
          if (item['reason'] is String && (item['reason'] as String).isNotEmpty)
            label(item['reason'] as String, color: Colors.white70),
          if (item['proofRef'] != null)
            pair(t('proofRef'), '${item['proofRef']}'),
          const SizedBox(height: 8),
          SelectableText(
            '${item['ref']}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(t(widget.section == 'overview' ? 'detail' : widget.section)),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () => load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            if (data != null && widget.section == 'overview') ...overview(),
            for (final item in items) record(item),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!busy && failed)
              Center(
                child: TextButton(
                  onPressed: () => load(reset: items.isEmpty),
                  child: Text(c('failed')),
                ),
              ),
            if (!busy &&
                !failed &&
                data != null &&
                widget.section != 'overview' &&
                items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: label(c('empty'), color: Colors.white60)),
              ),
            if (!busy && !failed && more)
              TextButton(onPressed: load, child: Text(c('more'))),
          ],
        ),
      ),
    ),
  );
}
