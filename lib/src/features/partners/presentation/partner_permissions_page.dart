import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

const partnerManagementPermissions = {
  'applications.review': 'applications',
  'withdrawals.review': 'withdrawReview',
  'tasks.publish': 'taskManagement',
  'tasks.review': 'task_reviews',
  'customers.read': 'directory',
  'messages.publish': 'publishMessage',
};

class PartnerPermissionsPage extends StatefulWidget {
  const PartnerPermissionsPage({super.key, required this.call});
  final PartnerCall call;
  @override
  State<PartnerPermissionsPage> createState() => _PermissionsState();
}

class _PermissionsState extends State<PartnerPermissionsPage> {
  final search = TextEditingController(), reason = TextEditingController();
  final selected = <String>{};
  final rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? member, pending;
  bool busy = false, failed = false, more = true;
  int page = 0;
  @override
  void initState() {
    super.initState();
    request({'action': 'permissions', 'page': 0});
  }

  @override
  void dispose() {
    search.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> request(Map<String, dynamic> p) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await widget.call(p);
      if (!mounted) return;
      setState(() {
        if (p['action'] == 'permissions') {
          final next = (result['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          rows.addAll(next);
          more = next.length == 30;
          page++;
        } else {
          member = Map<String, dynamic>.from(result['member'] as Map);
          search.text = member!['memberId'] as String;
          selected
            ..clear()
            ..addAll(List<String>.from(member!['permissions'] as List));
          history = (result['history'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          pending = null;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          failed = true;
          if (error is AuthFailure && error.code.startsWith('PARTNER_')) {
            pending = null;
            if (error.code == 'PARTNER_GRANT_CONFLICT') member = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void lookup() {
    final id = search.text.trim().toUpperCase();
    if (!RegExp(r'^KM[0-9A-Z]{1,62}$').hasMatch(id)) {
      setState(() => failed = true);
      return;
    }
    setState(() => member = null);
    request({'action': 'permission_member', 'memberId': id});
  }

  void save() {
    if (member == null || reason.text.trim().isEmpty) {
      setState(() => failed = true);
      return;
    }
    pending ??= {
      'action': 'permission_set',
      'requestId': const Uuid().v4(),
      'memberId': member!['memberId'],
      'expectedVersion': member!['version'],
      'permissions': selected.toList()..sort(),
      'reason': reason.text.trim(),
    };
    request(pending!);
  }

  @override
  Widget build(BuildContext context) {
    String t(String k) => partnerText(context, k);
    final editable = !busy && pending == null;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t('permissions')),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xff111111),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t('permissionNote'),
            style: const TextStyle(color: Colors.white60, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('permission-member-id'),
            controller: search,
            enabled: editable,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => member = null),
            onSubmitted: (_) => lookup(),
            decoration: InputDecoration(
              labelText: t('memberId'),
              hintText: 'KM…',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: kingControlHeight,
            child: OutlinedButton(
              onPressed: editable ? lookup : null,
              child: Text(t('verifyMember')),
            ),
          ),
          if (member != null) ...[
            const SizedBox(height: 24),
            Text(
              member!['name'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            for (final entry in partnerManagementPermissions.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(entry.value)),
                value: selected.contains(entry.key),
                onChanged: editable
                    ? (v) => setState(
                        () => v == true
                            ? selected.add(entry.key)
                            : selected.remove(entry.key),
                      )
                    : null,
              ),
            TextField(
              controller: reason,
              enabled: editable,
              maxLength: 300,
              maxLines: 3,
              decoration: InputDecoration(labelText: t('permissionReason')),
            ),
            SizedBox(
              height: kingControlHeight,
              child: FilledButton(
                onPressed: busy ? null : save,
                child: Text(t(pending == null ? 'savePermissions' : 'retry')),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('revokeNote'),
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            for (final row in history)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '${row['date']} · ${row['operator']}\n${row['reason']}',
                  style: const TextStyle(color: Colors.white60, height: 1.5),
                ),
              ),
          ] else ...[
            const SizedBox(height: 24),
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row['name'] as String),
                subtitle: Text(row['memberId'] as String),
                trailing: const Icon(Icons.chevron_right),
                onTap: editable
                    ? () {
                        search.text = row['memberId'] as String;
                        lookup();
                      }
                    : null,
              ),
            if (more && rows.isNotEmpty)
              TextButton(
                onPressed: busy
                    ? null
                    : () => request({'action': 'permissions', 'page': page}),
                child: Text(t('more')),
              ),
          ],
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                t('permissionFailed'),
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
