import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/session/secure_session_store.dart';
import '../../../core/formatters/money.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';
import 'partner_code_page.dart';
import 'partner_tasks_page.dart';
import 'partner_policy_page.dart';
import 'partner_transfer_page.dart';
import 'partner_withdrawal_page.dart';

Widget _title(BuildContext context, String value) => Text(
  value,
  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
);

const _card = Color(0xff202020), _gold = Color(0xffcebea4);

class PartnerPlatformPage extends StatefulWidget {
  const PartnerPlatformPage({super.key, this.call});
  final PartnerCall? call;
  @override
  State<PartnerPlatformPage> createState() => _PartnerPlatformPageState();
}

class _PartnerPlatformPageState extends State<PartnerPlatformPage> {
  late final PartnerCall call = widget.call ?? PartnerRepository().call;
  PartnerContext? data;
  bool busy = false, failed = false;
  int epoch = 0;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).popUntil((r) => r == route);
      epoch++;
      setState(() {
        data = null;
        busy = false;
        failed = false;
      });
      load();
    });
    load();
  }

  @override
  void dispose() {
    epoch++;
    session?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    final generation = ++epoch;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = PartnerContext(await call({'action': 'context'}));
      if (mounted && epoch == generation) setState(() => data = result);
    } catch (_) {
      if (mounted && epoch == generation) setState(() => failed = true);
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> apply() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _ApplicationPage(call: call)),
    );
    if (mounted) await load();
  }

  void list(String kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PartnerListPage(kind: kind, call: call),
    ),
  );
  void tasks(String kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PartnerTasksPage(call: call, kind: kind),
    ),
  );
  void levels() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(c).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              t('levels'),
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              t('rateNote'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            for (var n = 1; n <= 15; n++)
              ListTile(title: Text('L$n'), trailing: Text('${n + 5}%')),
            const Divider(),
            Text(
              t('eligibleNote'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
  void switchWorkspace() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t('title')),
              trailing: const Icon(Icons.check, color: _gold),
              onTap: () => Navigator.pop(c),
            ),
            for (final store in data!.stores)
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: _gold),
                title: Text(store['name'] as String),
                subtitle: Text(t('merchant')),
                onTap: () {
                  Navigator.pop(c);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _MerchantPage(store: store, call: call),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: _title(context, t('title')),
        foregroundColor: Colors.white,
        centerTitle: true,
        backgroundColor: const Color(0xff111111),
        actions: [
          if (d != null && d.stores.isNotEmpty)
            IconButton(
              tooltip: t('switch'),
              onPressed: switchWorkspace,
              icon: const Icon(Icons.swap_horiz),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (busy && d == null)
                const Padding(
                  padding: EdgeInsets.all(64),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (failed)
                _panel(
                  Column(
                    children: [
                      Text(t('failed')),
                      TextButton(
                        onPressed: busy ? null : load,
                        child: Text(t('retry')),
                      ),
                    ],
                  ),
                ),
              if (d != null && d.admin)
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(t('withdrawReview')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PartnerWithdrawalPage(call: call, review: true),
                    ),
                  ),
                ),
              if (d != null && d.partner == null) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        color: _gold,
                        size: 42,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t(
                          d.application?['status'] == 'pending'
                              ? 'pending'
                              : d.application?['status'] == 'rejected'
                              ? 'rejected'
                              : 'join',
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('intro'),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      if ((d.application?['reason'] as String? ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(d.application!['reason'] as String),
                        ),
                      if (d.application?['status'] != 'pending') ...[
                        const SizedBox(height: 24),
                        _button(t('join'), apply),
                      ],
                    ],
                  ),
                ),
              ],
              if (d?.partner != null) ...[
                ListTile(
                  contentPadding: const EdgeInsets.only(bottom: 16),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xff302a21),
                    child: Icon(Icons.handshake_outlined, color: _gold),
                  ),
                  title: Text('${t('title')} · L${d!.partner!['level']}'),
                  subtitle: Text(
                    '${t('rate')} ${(d.partner!['organizerBps'] as num).toInt() ~/ 100}%',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: levels,
                ),
                if (d.partner!['status'] == 'suspended')
                  _panel(Text(t('suspended'))),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('earnings'), style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(
                        d.finance == null
                            ? '—'
                            : '¥${moneyCents(d.finance!['availableCents'])}',
                        style: const TextStyle(fontSize: 34),
                      ),
                      if (d.finance != null)
                        Text(
                          '${t('pendingReward')}  ¥${moneyCents(d.finance!['pendingCents'])}',
                        ),
                      Text(
                        t(
                          d.finance == null
                              ? 'financePending'
                              : 'taskLedgerNote',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: d.partner?['status'] == 'active'
                                  ? () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PartnerWithdrawalPage(call: call),
                                        ),
                                      );
                                      if (mounted) await load();
                                    }
                                  : null,
                              child: Text(
                                t('withdraw'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: d.partner?['status'] == 'active'
                                  ? () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PartnerTransferPage(call: call),
                                        ),
                                      );
                                      if (mounted) await load();
                                    }
                                  : null,
                              child: Text(
                                t('transfer'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _panel(
                  Column(
                    children: [
                      _entry(
                        'code',
                        Icons.qr_code_2,
                        onTap: d.partner!['status'] == 'active'
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PartnerCodePage(call: call),
                                ),
                              )
                            : null,
                      ),
                      _entry(
                        'tasks',
                        Icons.assignment_outlined,
                        onTap: () => tasks('tasks'),
                      ),
                    ],
                  ),
                ),
                _panel(
                  Column(
                    children: [
                      _entry(
                        'team',
                        Icons.groups_outlined,
                        onTap: () => list('team'),
                        sub: '${t('direct')} · ${d.teamCount}',
                      ),
                      _entry(
                        'customers',
                        Icons.person_outline,
                        onTap: () => list('customers'),
                        sub: '${d.customerCount}',
                      ),
                      _entry(
                        'commission',
                        Icons.receipt_long_outlined,
                        onTap: () => tasks('ledger'),
                      ),
                    ],
                  ),
                ),
              ],
              if (d?.admin == true)
                _panel(
                  Column(
                    children: [
                      _entry(
                        'tasks',
                        Icons.assignment_outlined,
                        onTap: () => tasks('tasks'),
                      ),
                      _entry(
                        'task_reviews',
                        Icons.fact_check_outlined,
                        onTap: () => tasks('task_reviews'),
                      ),
                      _entry(
                        'applications',
                        Icons.fact_check_outlined,
                        onTap: () => list('applications'),
                      ),
                      _entry(
                        'directory',
                        Icons.contacts_outlined,
                        onTap: () => list('directory'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry(
    String key,
    IconData icon, {
    VoidCallback? onTap,
    String? sub,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _gold),
    title: Text(t(key)),
    subtitle: sub == null
        ? null
        : Text(
            sub,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

Widget _panel(Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Material(
    color: _card,
    borderRadius: BorderRadius.circular(14),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);
Widget _button(String label, VoidCallback? onTap) => SizedBox(
  width: double.infinity,
  height: kingControlHeight,
  child: FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: _gold,
      foregroundColor: Colors.black,
    ),
    onPressed: onTap,
    child: Text(label),
  ),
);

class _ApplicationPage extends StatefulWidget {
  const _ApplicationPage({required this.call});
  final PartnerCall call;
  @override
  State<_ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<_ApplicationPage> {
  final city = TextEditingController(), intro = TextEditingController();
  final directions = <String>{};
  Map<String, dynamic>? pending;
  bool busy = false;
  String? error;
  String t(String k) => partnerText(context, k);
  @override
  void dispose() {
    city.dispose();
    intro.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (pending == null && (city.text.trim().isEmpty || directions.isEmpty)) {
      setState(() => error = t('required'));
      return;
    }
    pending ??= {
      'action': 'apply',
      'requestId': const Uuid().v4(),
      'city': city.text.trim(),
      'directions': directions.toList()..sort(),
      'introduction': intro.text.trim(),
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.call(pending!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = t('actionFailed'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: _title(context, t('join')),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: city,
            readOnly: pending != null,
            maxLength: 80,
            decoration: InputDecoration(labelText: t('city')),
          ),
          const SizedBox(height: 16),
          Text(t('directions')),
          Wrap(
            spacing: 8,
            children: [
              for (final key in ['organize', 'members', 'merchants'])
                FilterChip(
                  label: Text(t(key)),
                  selected: directions.contains(key),
                  onSelected: pending != null
                      ? null
                      : (v) => setState(() {
                          v ? directions.add(key) : directions.remove(key);
                        }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: intro,
            readOnly: pending != null,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(labelText: t('experience')),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          const SizedBox(height: 20),
          _button(
            pending != null ? t('retry') : t('submit'),
            busy ? null : submit,
          ),
        ],
      ),
    ),
  );
}

class _PartnerListPage extends StatefulWidget {
  const _PartnerListPage({
    required this.kind,
    required this.call,
    this.teamAccount,
    this.teamName,
  });
  final String kind;
  final String? teamAccount, teamName;
  final PartnerCall call;
  @override
  State<_PartnerListPage> createState() => _PartnerListState();
}

class _PartnerListState extends State<_PartnerListPage> {
  final items = <Map<String, dynamic>>[];
  int page = 0;
  bool busy = false, failed = false, more = true;
  String t(String k) => partnerText(context, k);
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
      final r = await widget.call({
        'action': widget.kind,
        'page': page,
        if (widget.teamAccount != null) 'teamAccount': widget.teamAccount,
      });
      final rows = (r['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (mounted) {
        setState(() {
          items.addAll(rows);
          page++;
          more = rows.length == 30;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ReviewPage(item: item, call: widget.call),
      ),
    );
    if (mounted) {
      items.clear();
      page = 0;
      more = true;
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: _title(context, t(widget.kind)),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.teamName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.teamName!,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          if (widget.kind == 'team')
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                t('treeNote'),
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          for (final item in items)
            _panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['name'] as String),
                subtitle: Text(
                  [item['city'], item['date']].whereType<String>().join('\n'),
                ),
                trailing: widget.kind == 'applications'
                    ? const Icon(Icons.chevron_right)
                    : item['level'] == null
                    ? null
                    : Text('L${item['level']}'),
                onTap: widget.kind == 'applications'
                    ? () => review(item)
                    : widget.kind == 'team'
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PartnerListPage(
                            kind: 'team',
                            call: widget.call,
                            teamAccount: item['ref'] as String,
                            teamName: item['name'] as String,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          if (!busy && !failed && items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text(t('empty'))),
            ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (failed)
            TextButton(
              onPressed: load,
              child: Text('${t('failed')} · ${t('retry')}'),
            ),
          if (!busy && !failed && more)
            TextButton(onPressed: load, child: Text(t('more'))),
        ],
      ),
    ),
  );
}

class _ReviewPage extends StatefulWidget {
  const _ReviewPage({required this.item, required this.call});
  final Map<String, dynamic> item;
  final PartnerCall call;
  @override
  State<_ReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<_ReviewPage> {
  final reason = TextEditingController(), parent = TextEditingController();
  bool busy = false;
  Map<String, dynamic>? pending;
  String? error;
  String t(String k) => partnerText(context, k);
  @override
  void dispose() {
    reason.dispose();
    parent.dispose();
    super.dispose();
  }

  Future<void> send(String decision) async {
    if (busy || reason.text.trim().isEmpty) return;
    if (pending == null &&
        parent.text.trim().isNotEmpty &&
        !RegExp(r'^U[0-9]{11}$').hasMatch(parent.text.trim())) {
      setState(() => error = t('parent'));
      return;
    }
    pending ??= {
      'action': 'review',
      'requestId': const Uuid().v4(),
      'applicationRef': widget.item['ref'],
      'decision': decision,
      'reason': reason.text.trim(),
      if (parent.text.trim().isNotEmpty) 'parentAccount': parent.text.trim(),
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.call(pending!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = t('actionFailed'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: kingAppBar(
      context: context,
      title: Text(t('applications')),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.item['name'] as String,
          style: const TextStyle(fontSize: 22),
        ),
        Text('${widget.item['city']}'),
        Text('${widget.item['introduction']}'),
        const SizedBox(height: 20),
        TextField(
          controller: reason,
          readOnly: pending != null,
          maxLength: 300,
          decoration: InputDecoration(labelText: t('reviewReason')),
        ),
        TextField(
          controller: parent,
          readOnly: pending != null,
          maxLength: 12,
          decoration: InputDecoration(labelText: t('parent')),
        ),
        if (error != null) Text(error!),
        const SizedBox(height: 20),
        _button(
          pending == null ? t('approve') : t('retry'),
          busy ? null : () => send('approved'),
        ),
        if (pending == null)
          TextButton(
            onPressed: busy ? null : () => send('rejected'),
            child: Text(t('reject')),
          ),
      ],
    ),
  );
}

class _MerchantPage extends StatefulWidget {
  const _MerchantPage({required this.store, required this.call});
  final Map<String, dynamic> store;
  final PartnerCall call;
  @override
  State<_MerchantPage> createState() => _MerchantState();
}

class _MerchantState extends State<_MerchantPage> {
  late Future<Map<String, dynamic>> result = widget.call({
    'action': 'merchant',
    'storeRef': widget.store['ref'],
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: _title(context, partnerText(context, 'merchant')),
      centerTitle: true,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: partnerText(context, 'title'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.swap_horiz),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: result,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => result = widget.call({
                  'action': 'merchant',
                  'storeRef': widget.store['ref'],
                }),
              ),
              child: Text(partnerText(c, 'retry')),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final store = s.data!['store'] as Map;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_outlined, color: _gold, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    store['name'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  Text('${partnerText(c, 'address')}\n${store['address']}'),
                  const SizedBox(height: 16),
                  Text('${partnerText(c, 'currency')} · ${store['currency']}'),
                  if (store['currency'] == 'CNY') ...[
                    const SizedBox(height: 20),
                    _button(
                      partnerText(c, 'commissionPolicy'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PartnerPolicyPage(
                            call: widget.call,
                            storeRef: widget.store['ref'] as String,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              partnerText(c, 'merchantNote'),
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 20),
            _button(
              partnerText(c, 'tasks'),
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PartnerTasksPage(
                    call: widget.call,
                    storeRef: widget.store['ref'] as String,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
