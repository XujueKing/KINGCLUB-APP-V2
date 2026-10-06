import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/formatters/money.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/partner_repository.dart';
import '../../auth/domain/auth_repository.dart';
import 'partner_strings.dart';

String _money(Object? value) => '¥${moneyCents(value ?? '0')}';
int _cents(String s) {
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(s.trim())) {
    throw const FormatException();
  }
  final v = s.trim().split('.');
  return int.parse(v[0]) * 100 +
      int.parse(v.length == 1 ? '0' : v[1].padRight(2, '0'));
}

class PartnerTasksPage extends StatefulWidget {
  const PartnerTasksPage({
    super.key,
    required this.call,
    this.kind = 'tasks',
    this.taskRef,
    this.review,
    this.storeRef,
  });
  final PartnerCall call;
  final String kind;
  final String? taskRef, storeRef;
  final Map<String, dynamic>? review;
  @override
  State<PartnerTasksPage> createState() => _PartnerTasksState();
}

class _PartnerTasksState extends State<PartnerTasksPage> {
  Map<String, dynamic>? data;
  final rows = <Map<String, dynamic>>[];
  final inputs = List.generate(6, (_) => TextEditingController());
  bool busy = false, failed = false, invalid = false, more = true;
  int page = 0;
  String taskKind = 'member';
  DateTime? deadline;
  Map<String, dynamic>? pending;
  StreamSubscription<void>? session;
  String t(String k) => partnerText(context, k);
  bool get detail => widget.taskRef != null;
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) {
        setState(() {
          invalid = true;
          data = null;
          rows.clear();
        });
      }
    });
    if (widget.kind != 'create' && widget.review == null) request();
  }

  @override
  void dispose() {
    session?.cancel();
    for (final c in inputs) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> request([Map<String, dynamic>? action]) async {
    if (busy || invalid) return;
    final p =
        action ??
        {
          'action': detail ? 'task_detail' : widget.kind,
          if (detail) 'taskRef': widget.taskRef,
          if (!detail) 'page': page,
          if (!detail && widget.kind == 'tasks' && widget.storeRef != null)
            'storeRef': widget.storeRef,
        };
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await widget.call(p);
      if (!mounted || invalid) return;
      if (widget.kind == 'create' || widget.review != null) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        data = result;
        pending = null;
        if (!detail) {
          final next = (result['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          rows.addAll(next);
          more = next.length == 30;
          page++;
        }
      });
    } catch (error) {
      if (mounted && !invalid) {
        setState(() {
          failed = true;
          // A definitive business rejection may be corrected. Unknown outcomes
          // must retain the exact request so retry cannot duplicate an award.
          if (error is AuthFailure && error.code.startsWith('PARTNER_')) {
            pending = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void act(Map<String, dynamic> p) {
    pending ??= p;
    request(pending);
  }

  Future<void> open({
    String? ref,
    Map<String, dynamic>? review,
    String kind = 'tasks',
  }) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerTasksPage(
          call: widget.call,
          taskRef: ref,
          storeRef: widget.storeRef,
          review: review,
          kind: kind,
        ),
      ),
    );
    if (mounted && !invalid && changed == true) {
      page = 0;
      rows.clear();
      more = true;
      await request();
    }
  }

  Widget button(String key, VoidCallback fn) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy || invalid || (pending != null && key != 'retry')
            ? null
            : fn,
        child: Text(
          t(key),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
          ),
        ),
      ),
    ),
  );
  Widget field(int n, String label, {bool money = false, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: inputs[n],
          readOnly: busy || pending != null,
          minLines: lines,
          maxLines: lines,
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: money
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          decoration: InputDecoration(labelText: t(label)),
        ),
      );
  Widget card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xff202020),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  void create() {
    try {
      if (deadline == null) throw const FormatException();
      act({
        'action': 'task_create',
        if (widget.storeRef != null) 'storeRef': widget.storeRef,
        'requestId': const Uuid().v4(),
        'title': inputs[0].text,
        'description': inputs[1].text,
        'kind': taskKind,
        'minimumCents': _cents(inputs[2].text),
        'maximumCents': _cents(inputs[3].text),
        'budgetCents': _cents(inputs[4].text),
        'endsAt': deadline!.toUtc().toIso8601String(),
      });
    } catch (_) {
      setState(() => failed = true);
    }
  }

  void review(bool approved) {
    try {
      act({
        'action': 'task_review',
        'requestId': const Uuid().v4(),
        'claimRef': widget.review!['ref'],
        'decision': approved ? 'approved' : 'rejected',
        'rewardCents': approved ? _cents(inputs[0].text) : 0,
        'reason': inputs[1].text,
      });
    } catch (_) {
      setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = data?['task'] as Map?, claim = data?['claim'] as Map?;
    final status = claim?['status'];
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        centerTitle: true,
        title: Text(
          t(
            widget.kind == 'create'
                ? 'taskNew'
                : widget.review != null
                ? 'task_reviews'
                : widget.kind,
          ),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (invalid)
              Text(t('sessionChanged'))
            else ...[
              if (failed)
                card([
                  Text(t('taskError')),
                  if (pending != null ||
                      (widget.kind != 'create' && widget.review == null))
                    button('retry', () => request(pending)),
                ]),
              if (widget.kind == 'create')
                card([
                  field(0, 'taskTitle'),
                  field(1, 'taskRules', lines: 4),
                  DropdownButton<String>(
                    value: taskKind,
                    isExpanded: true,
                    items: ['member', 'merchant']
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(t('${k}Task')),
                          ),
                        )
                        .toList(),
                    onChanged: busy || pending != null
                        ? null
                        : (v) => setState(() => taskKind = v!),
                  ),
                  field(2, 'rewardMin', money: true),
                  field(3, 'rewardMax', money: true),
                  field(4, 'budget', money: true),
                  TextButton(
                    onPressed: busy || pending != null
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: context,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 366)),
                              initialDate: now.add(const Duration(days: 30)),
                            );
                            if (date != null && mounted) {
                              setState(
                                () => deadline = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  23,
                                  59,
                                ),
                              );
                            }
                          },
                    child: Text(
                      '${t('deadline')} ${deadline == null ? '' : deadline.toString().split(' ').first}',
                    ),
                  ),
                  button('saveDraft', create),
                ]),
              if (widget.review != null)
                card([
                  Text(
                    widget.review!['title'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.review!['description'] as String),
                  const Divider(),
                  Text(
                    '${widget.review!['partnerAccount']}\n${widget.review!['evidenceRef']}\n${widget.review!['note']}',
                  ),
                  Text(
                    '${_money(widget.review!['minimumCents'])} – ${_money(widget.review!['maximumCents'])}',
                  ),
                  field(0, 'rewardAmount', money: true),
                  field(1, 'reviewReason', lines: 3),
                  button('approve', () => review(true)),
                  button('reject', () => review(false)),
                ]),
              if (detail && task != null) ...[
                card([
                  Text(
                    task['title'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_money(task['minimumCents'])} – ${_money(task['maximumCents'])}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Color(0xffcebea4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    task['description'] as String,
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Text('${t('deadline')}\n${task['endsAt']}'),
                  if (data?['isAdmin'] == true && task['status'] == 'draft')
                    button(
                      'publishTask',
                      () => act({
                        'action': 'task_publish',
                        'taskRef': widget.taskRef,
                      }),
                    ),
                ]),
                if (claim != null)
                  card([
                    Text(
                      t(
                        status == 'rejected'
                            ? 'taskRejected'
                            : status as String,
                      ),
                      style: const TextStyle(fontSize: 20),
                    ),
                    if ((claim['reason'] as String? ?? '').isNotEmpty)
                      Text(claim['reason'] as String),
                    if (status == 'claimed') ...[
                      field(0, 'evidence'),
                      field(1, 'evidenceNote', lines: 3),
                      button(
                        'submitTask',
                        () => act({
                          'action': 'task_submit',
                          'claimRef': claim['ref'],
                          'evidenceRef': inputs[0].text.trim(),
                          'note': inputs[1].text.trim(),
                        }),
                      ),
                      button(
                        'cancelTask',
                        () => act({
                          'action': 'task_cancel',
                          'claimRef': claim['ref'],
                        }),
                      ),
                    ],
                  ]),
                if (!['claimed', 'submitted'].contains(status))
                  if (task['available'] == true)
                    button(
                      'claimTask',
                      () => act({
                        'action': 'task_claim',
                        'taskRef': widget.taskRef,
                        'requestId': const Uuid().v4(),
                      }),
                    )
                  else
                    Text(t('taskUnavailable')),
              ],
              if (!detail && data != null) ...[
                if (widget.kind == 'tasks' &&
                    (data!['canCreate'] == true || data!['isAdmin'] == true))
                  button('taskNew', () => open(kind: 'create')),
                if (widget.kind == 'ledger')
                  card([
                    Text(t('pendingReward')),
                    const SizedBox(height: 12),
                    Text(
                      _money(data!['pendingCents']),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(t('availableReward')),
                    Text(
                      _money(data!['availableCents']),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(t('taskLedgerNote')),
                  ]),
                for (final row in rows)
                  card([
                    Text(
                      row['title'] as String,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    if (widget.kind == 'ledger') ...[
                      if (['organizer', 'referrer'].contains(row['kind'])) ...[
                        Text(t(row['kind'] as String)),
                        Text(
                          '${t('eligibleSpend')} ${_money(row['eligibleCents'])} · ${(row['rateBps'] as num) / 100}%',
                        ),
                      ],
                      Text(
                        _money(row['amountCents']),
                        style: TextStyle(
                          fontSize: 24,
                          decoration: row['status'] == 'reversed'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text('${row['date']}'),
                      if (row['status'] == 'reversed')
                        Text('${t('reversed')} ${row['reversedAt'] ?? ''}')
                      else
                        Text(
                          '${t('availableDate')} ${row['availableAt'] ?? ''}',
                        ),
                      Text(row['reason'] as String? ?? ''),
                    ] else ...[
                      Text(
                        '${_money(row['minimumCents'])} – ${_money(row['maximumCents'])}',
                      ),
                      button(
                        widget.kind == 'task_reviews'
                            ? 'task_reviews'
                            : 'details',
                        () => open(
                          ref: widget.kind == 'tasks'
                              ? row['ref'] as String
                              : null,
                          review: widget.kind == 'task_reviews' ? row : null,
                        ),
                      ),
                    ],
                  ]),
                if (rows.isEmpty && !busy)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(t('empty'))),
                  ),
                if (more && rows.isNotEmpty) button('more', () => request()),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
