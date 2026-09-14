import 'group_announcement_page.dart';
import 'chat_member_avatar.dart';
import 'create_group_page.dart';
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
  final _name = TextEditingController();
  int? _editingVersion;
  Map<String, dynamic> _settings = {};
  int _generation = 0;
  final _avatarProfiles = <String, Future<Map<String, dynamic>>>{};
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _avatarProfiles.clear();
      _name.clear();
      _editingVersion = null;
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
          _avatarProfiles.clear();
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

  List<String> _memberActions(Map member) {
    if (_details == null ||
        _invalid ||
        member['membershipVersion'] is! num ||
        member['account'] == widget.repository.account ||
        member['role'] == 'owner') {
      return [];
    }
    if (_details!['ownerAccount'] == widget.repository.account) {
      return [member['role'] == 'admin' ? 'member' : 'admin', 'remove'];
    }
    final admin = (_details!['members'] as List).cast<Map>().any(
      (m) => m['account'] == widget.repository.account && m['role'] == 'admin',
    );
    return admin && member['role'] == 'member' ? ['remove'] : [];
  }

  String _actionLabel(String action) => switch (action) {
    'admin' => '设为管理员',
    'member' => '取消管理员',
    _ => '移出群聊',
  };

  Widget _memberTrailing(Map member) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (member['role'] != 'member')
        Text(
          member['role'] == 'owner' ? '群主' : '管理员',
          style: const TextStyle(color: Colors.grey),
        ),
      if (_memberActions(member).isNotEmpty)
        PopupMenuButton<String>(
          key: ValueKey('group-member-actions-${member['account']}'),
          enabled: !_saving,
          color: const Color(0xFF202020),
          icon: const Icon(
            Icons.more_horiz,
            color: Color(0xFFC9B69E),
            size: 22,
          ),
          onSelected: (action) => _manageMember(member, action),
          itemBuilder: (_) => [
            for (final action in _memberActions(member))
              PopupMenuItem(
                value: action,
                child: Text(
                  _actionLabel(action),
                  style: const TextStyle(
                    color: Color(0xFFC9B69E),
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
    ],
  );

  Future<void> _manageMember(Map member, String action) async {
    if (_saving || !_memberActions(member).contains(action)) return;
    final version = (_details!['metadataVersion'] as num).toInt();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: Text(
            '${_actionLabel(action)}？',
            style: const TextStyle(color: Color(0xFFC9B69E)),
          ),
          content: Text(
            member['nickname'] as String,
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const ValueKey('group-member-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _invalid) return;
      final result = await widget.repository.manageMember(
        widget.groupId,
        member['account'] as String,
        action: action,
        expectedVersion: version,
        membershipVersion: (member['membershipVersion'] as num).toInt(),
      );
      if (result['changed'] is! bool) throw const FormatException('成员管理结果无效');
      if (mounted && !_invalid) await _load();
    } catch (error) {
      if (mounted && !_invalid) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _transfer() async {
    if (_invalid ||
        _saving ||
        _details?['ownerAccount'] != widget.repository.account) {
      return;
    }
    final version = (_details!['metadataVersion'] as num).toInt();
    final members = (_details!['members'] as List)
        .cast<Map>()
        .where((m) => m['account'] != widget.repository.account)
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final target = await showDialog<Map>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          backgroundColor: const Color(0xFF202020),
          title: const Text(
            '选择新群主',
            style: TextStyle(color: Color(0xFFC9B69E)),
          ),
          children: [
            SizedBox(
              width: double.maxFinite,
              height: 280,
              child: ListView(
                children: [
                  for (final member in members)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, member),
                      child: Text(
                        member['nickname'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  if (members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '暂无可选成员',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        ),
      );
      if (target == null || !mounted || _invalid) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: const Text(
            '转让群主？',
            style: TextStyle(color: Color(0xFFC9B69E)),
          ),
          content: Text(
            '将群主转让给${target['nickname']}，你将成为普通成员。',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const ValueKey('group-transfer-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认转让'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _invalid) return;
      await widget.repository.transfer(
        widget.groupId,
        target['account'] as String,
        version,
      );
      if (mounted && !_invalid) await _load();
    } catch (error) {
      if (mounted && !_invalid) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _depart() async {
    if (_invalid || _saving || _details == null) return;
    final dissolve = _details!['ownerAccount'] == widget.repository.account;
    final version = (_details!['membershipVersion'] as num).toInt();
    setState(() => _saving = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: Text(
            dissolve ? '解散群聊？' : '退出群聊？',
            style: const TextStyle(color: Color(0xFFC9B69E)),
          ),
          content: Text(
            dissolve ? '解散后所有成员都无法继续在此群聊天。' : '退出后将无法继续收发此群消息。',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const ValueKey('group-depart-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                dissolve ? '解散' : '退出',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _invalid) return;
      final result = await widget.repository.depart(
        widget.groupId,
        dissolve: dissolve,
        membershipVersion: version,
      );
      if (result['action'] != (dissolve ? 'dissolve' : 'leave') ||
          result['changed'] is! bool) {
        throw const FormatException('退出结果无效');
      }
      if (mounted && !_invalid) Navigator.pop(context, true);
    } catch (error) {
      if (mounted && !_invalid) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename() async {
    if (_invalid ||
        _saving ||
        _editingVersion == null ||
        _details?['ownerAccount'] != widget.repository.account) {
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写群名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.rename(widget.groupId, name, _editingVersion!);
      if (!mounted || _invalid) return;
      setState(() => _editingVersion = null);
      await _load();
    } catch (error) {
      if (mounted && !_invalid) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    _name.dispose();
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
                    leading: const Icon(
                      Icons.person_add_alt,
                      color: Color(0xFFC9B69E),
                    ),
                    title: const Text(
                      '邀请好友',
                      style: TextStyle(color: Color(0xFFC9B69E), fontSize: 16),
                    ),
                    onTap: _saving || _invalid
                        ? null
                        : () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateGroupPage(
                                  repository: widget.repository,
                                  inviteGroupId: widget.groupId,
                                ),
                              ),
                            );
                            if (mounted && !_invalid) await _load();
                          },
                  ),
                  ListTile(
                    key: const ValueKey('group-name-row'),
                    onTap:
                        !_saving &&
                            _details!['ownerAccount'] ==
                                widget.repository.account
                        ? () => setState(() {
                            _name.text = _details!['groupName'] as String;
                            _editingVersion =
                                (_details!['metadataVersion'] as num).toInt();
                          })
                        : null,
                    trailing:
                        _details!['ownerAccount'] == widget.repository.account
                        ? const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFC9B69E),
                          )
                        : null,
                    title: Text(
                      _details!['groupName'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  if (_editingVersion != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          TextField(
                            key: const ValueKey('group-name-input'),
                            controller: _name,
                            enabled: !_saving,
                            maxLength: 64,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: '群名称'),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => setState(
                                        () => _editingVersion = null,
                                      ),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                key: const ValueKey('group-name-save'),
                                onPressed: _saving ? null : _rename,
                                child: const Text('保存'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_details!['ownerAccount'] == widget.repository.account)
                    ListTile(
                      key: const ValueKey('group-transfer'),
                      title: const Text(
                        '转让群主',
                        style: TextStyle(
                          color: Color(0xFFC9B69E),
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFC9B69E),
                      ),
                      onTap: _saving ? null : _transfer,
                    ),
                  ListTile(
                    key: const ValueKey('group-announcement-row'),
                    title: const Text(
                      '群公告',
                      style: TextStyle(color: Color(0xFFC9B69E), fontSize: 16),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFC9B69E),
                    ),
                    onTap: _saving || _invalid
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => GroupAnnouncementPage(
                                groupId: widget.groupId,
                                repository: widget.repository,
                              ),
                            ),
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
                      leading: Builder(
                        builder: (_) {
                          final account = (raw as Map)['account'] as String;
                          final own = account == widget.repository.account;
                          return ChatMemberAvatar(
                            account: account,
                            own: own,
                            profile: _avatarProfiles.putIfAbsent(
                              account,
                              () => widget.repository.messaging.call(
                                own ? 'K260912000501' : 'K260913000612',
                                own ? {} : {'peer': account},
                              ),
                            ),
                          );
                        },
                      ),
                      title: Text(
                        (raw as Map)['nickname'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: _memberTrailing(raw),
                      onTap: _saving
                          ? null
                          : () => Navigator.of(context).push<void>(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: TextButton(
                      key: const ValueKey('group-depart'),
                      onPressed: _saving ? null : _depart,
                      child: Text(
                        _details!['ownerAccount'] == widget.repository.account
                            ? '解散群聊'
                            : '退出群聊',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
