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
      final result = await widget.repository.details(widget.groupId);
      if (mounted && generation == _generation) {
        setState(() {
          _details = result;
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
