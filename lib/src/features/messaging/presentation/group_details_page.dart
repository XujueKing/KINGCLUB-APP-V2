import '../../../core/networking/kingclub_realtime.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/group_chat_repository.dart';
import '../../contacts/presentation/public_member_page.dart';
import 'legacy_messaging_components.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({
    super.key,
    required this.groupId,
    required this.repository,
  });
  final String groupId;
  final GroupChatRepository repository;
  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  Map<String, dynamic>? _details;
  String? _error;
  bool _invalid = false;
  bool _saving = false;
  Map<String, dynamic> _settings = {};
  int _generation = 0;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _generation++;
      if (mounted) {
        setState(() {
          _details = null;
          _error = '登录状态已变化';
        });
      }
    });
    _events = KingclubRealtime.shared.events.listen((event) {
      final data = event['data'];
      if (!_invalid &&
          mounted &&
          event['eventType'] == 'chat.group.read' &&
          data is Map &&
          data['groupId'] == widget.groupId) {
        unawaited(_load());
        return;
      }
      if (!_invalid &&
          mounted &&
          (event['eventType'] == 'chat.group.changed' ||
              event['eventType'] == 'connection.ready')) {
        setState(() => _details = null);
        unawaited(_load());
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_invalid) return;
    final generation = ++_generation;
    try {
      final results = await Future.wait([
        widget.repository.details(widget.groupId),
        widget.repository.history(widget.groupId, limit: 1),
      ]);
      final result = results[0];
      final settings = Map<String, dynamic>.from(results[1]['settings'] as Map);
      if (mounted && generation == _generation) {
        setState(() {
          _details = result;
          _settings = settings;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _details = null;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _save({bool? muted, bool? pinned}) async {
    if (_invalid || _saving || _details == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.settings(
        widget.groupId,
        muted: muted,
        pinned: pinned,
      );
      if (result['saved'] != true) throw const FormatException('设置未保存');
    } catch (error) {
      if (mounted && !_invalid) setState(() => _error = error.toString());
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted && !_invalid) await _load();
  }

  Widget _settingRow(String label, String field) => ListTile(
    title: Text(
      label,
      style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 16),
    ),
    trailing: Switch(
      key: ValueKey('group-details-$field'),
      value: _settings[field] == true,
      activeTrackColor: const Color(0xFF07C160),
      onChanged: _saving || _invalid
          ? null
          : (value) =>
                field == 'muted' ? _save(muted: value) : _save(pinned: value),
    ),
  );

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '群聊资料',
            onBack: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: ListView(
              children: [
                if (_error != null)
                  ListTile(
                    title: Text(
                      _error!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: _invalid ? null : _load,
                  ),
                if (_details != null) ...[
                  ListTile(
                    title: Text(
                      _details!['groupName'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  _settingRow('消息免打扰', 'muted'),
                  const Divider(
                    indent: 24,
                    endIndent: 24,
                    height: 1,
                    color: Color(0xFF1A1611),
                  ),
                  _settingRow('置顶聊天', 'pinned'),
                  const Divider(
                    indent: 24,
                    endIndent: 24,
                    height: 1,
                    color: Color(0xFF1A1611),
                  ),
                  for (final raw in _details!['members'] as List) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: Color(0xFFC9B69E),
                      ),
                      title: Text(
                        (raw as Map)['nickname'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: raw['role'] == 'owner'
                          ? const Text(
                              '群主',
                              style: TextStyle(color: Colors.grey),
                            )
                          : null,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => PublicMemberPage(
                            account: raw['account'] as String,
                            repository: widget.repository.messaging,
                          ),
                        ),
                      ),
                    ),
                    const Divider(
                      indent: 72,
                      endIndent: 24,
                      height: 1,
                      color: Color(0xFF1A1611),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
