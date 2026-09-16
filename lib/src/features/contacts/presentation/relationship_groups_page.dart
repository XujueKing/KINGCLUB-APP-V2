import '../../../core/networking/kingclub_realtime.dart';

import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/contact_groups_repository.dart';
export '../data/contact_groups_repository.dart' show ContactGroup;

import 'package:flutter/material.dart';

import '../../messaging/presentation/legacy_messaging_components.dart';

const relationshipIcons = <IconData>[
  Icons.favorite_rounded,
  Icons.school_rounded,
  Icons.people_alt_rounded,
  Icons.work_rounded,
  Icons.home_rounded,
  Icons.star_rounded,
  Icons.sports_bar_rounded,
  Icons.music_note_rounded,
];

class RelationshipGroupsPage extends StatefulWidget {
  const RelationshipGroupsPage({
    super.key,
    required this.contacts,
    required this.groups,
    required this.onChanged,
    this.repository,
    this.events,
  });
  final ContactGroupsRepository? repository;
  final Stream<Map<String, dynamic>>? events;
  final Map<String, String> contacts;
  final List<ContactGroup> groups;
  final ValueChanged<List<ContactGroup>> onChanged;
  @override
  State<RelationshipGroupsPage> createState() => _RelationshipGroupsPageState();
}

class _RelationshipGroupsPageState extends State<RelationshipGroupsPage> {
  late List<ContactGroup> _groups = List.of(widget.groups);
  bool _ready = false, _sessionInvalid = false, _cleaning = false;
  String? _loadError;
  int _generation = 0;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _editing = false;
  bool _refreshPending = false;
  @override
  void initState() {
    super.initState();
    _ready = widget.repository == null;
    if (widget.repository != null) {
      _session = SecureSessionStore.changes.stream.listen((_) {
        _generation++;
        _sessionInvalid = true;
        if (mounted) {
          setState(() {
            _groups = [];
            _ready = false;
            _loadError = '登录状态已变化';
          });
        }
      });
      _events = (widget.events ?? KingclubRealtime.shared.events).listen((
        event,
      ) {
        if (_sessionInvalid || !mounted) return;
        if (event['eventType'] != 'chat.groups.changed' &&
            event['eventType'] != 'connection.ready') {
          return;
        }
        if (_editing || _cleaning) {
          _refreshPending = true;
          setState(() => _loadError = '分组已更新，编辑内容已保留，请刷新后保存');
        } else {
          unawaited(_load());
        }
      });
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_sessionInvalid) throw StateError('登录状态已变化');
    final generation = ++_generation;
    try {
      final groups = await widget.repository!.load(
        onCached: (groups) {
          if (!mounted || generation != _generation || _sessionInvalid) return;
          setState(() => _groups = groups);
        },
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _groups = groups;
        _ready = true;
        _loadError = null;
      });
      widget.onChanged(groups);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadError = '分组加载失败，点击重试');
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    super.dispose();
  }

  List<ContactGroup> _merge(ContactGroup result) => [
    ..._groups
        .where((group) => group.id != result.id)
        .map(
          (group) => ContactGroup(
            group.id,
            group.name,
            group.icon,
            group.members.difference(result.members),
          ),
        ),
    result,
  ];
  Future<void> _saveReal(ContactGroup result) async {
    if (!_ready || _sessionInvalid) throw StateError('请重新读取关系分组');
    final generation = _generation;
    final saved = await widget.repository!.save(_merge(result));
    if (!mounted || _sessionInvalid || generation != _generation) {
      throw StateError('登录或分组状态已变化');
    }
    _update(saved);
  }

  Future<void> _cleanUnavailableMembers() async {
    if (!_ready || _sessionInvalid || _cleaning || widget.repository == null) {
      return;
    }
    final generation = _generation;
    setState(() => _cleaning = true);
    try {
      final allowed = <String>{};
      var offset = 0;
      while (true) {
        final result = await widget.repository!.messaging.call(
          'K260913000608',
          {'offset': offset, 'limit': 100},
        );
        if (!mounted || generation != _generation || _sessionInvalid) return;
        final items = result['items'] as List;
        for (final item in items) {
          allowed.add((item as Map)['peer'] as String);
        }
        if (result['hasMore'] != true) break;
        if (items.isEmpty || offset >= 100000) throw StateError('通讯录分页无效');
        offset += items.length;
      }
      final cleaned = _groups
          .map(
            (group) => ContactGroup(
              group.id,
              group.name,
              group.icon,
              group.members.intersection(allowed),
            ),
          )
          .toList();
      final removed =
          _groups.fold<int>(0, (count, group) => count + group.members.length) -
          cleaned.fold<int>(0, (count, group) => count + group.members.length);
      if (removed == 0) {
        setState(() => _loadError = '没有需要清理的失效成员');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清理失效成员'),
          content: Text('将 $removed 位已不在通讯录中的成员移出关系分组。分组和聊天记录会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认清理'),
            ),
          ],
        ),
      );
      if (!mounted ||
          confirmed != true ||
          generation != _generation ||
          _sessionInvalid) {
        return;
      }
      final saved = await widget.repository!.save(cleaned);
      if (!mounted || generation != _generation || _sessionInvalid) return;
      _update(saved);
      setState(() => _loadError = null);
    } catch (error) {
      if (mounted && !_sessionInvalid) {
        setState(() => _loadError = '清理失败，请刷新分组后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _cleaning = false);
        if (_refreshPending && !_sessionInvalid) {
          _refreshPending = false;
          await _load();
        }
      }
    }
  }

  Future<void> _deleteGroup(ContactGroup group) async {
    if (!_ready || _sessionInvalid) throw StateError('请重新读取关系分组');
    final generation = _generation;
    final remaining = _groups.where((item) => item.id != group.id).toList();
    final saved = widget.repository == null
        ? remaining
        : await widget.repository!.save(remaining);
    if (!mounted || _sessionInvalid || generation != _generation) {
      throw StateError('登录或分组状态已变化');
    }
    _update(saved);
  }

  void _update(List<ContactGroup> groups) {
    setState(() => _groups = groups);
    widget.onChanged(List.of(groups));
  }

  Future<void> _edit(ContactGroup? group) async {
    if (_editing) return;
    _editing = true;
    final result = await Navigator.of(context).push<ContactGroup>(
      MaterialPageRoute(
        builder: (_) => _GroupEditor(
          group: group,
          contacts: widget.contacts,
          onSave: widget.repository == null ? null : _saveReal,
          onReload: widget.repository == null ? null : _load,
          onDelete: group == null ? null : () => _deleteGroup(group),
        ),
      ),
    );
    _editing = false;
    if (!mounted || _sessionInvalid) return;
    if (widget.repository != null) {
      if (_refreshPending) {
        _refreshPending = false;
        await _load();
      }
      return;
    }
    if (result == null) return;
    _update([
      ..._groups
          .where((g) => g.id != result.id)
          .map(
            (g) => ContactGroup(
              g.id,
              g.name,
              g.icon,
              g.members.difference(result.members),
            ),
          ),
      result,
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '我的关系',
            onBack: () => Navigator.pop(context),
            trailing: IconButton(
              tooltip: '新建分组',
              onPressed: _ready && !_cleaning ? () => _edit(null) : null,
              icon: const Icon(Icons.add, color: legacyMessageGold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (widget.repository != null && _ready)
                  TextButton(
                    onPressed: _cleaning ? null : _cleanUnavailableMembers,
                    child: const Text('清理失效成员'),
                  ),
                if (_loadError != null)
                  TextButton(
                    onPressed: _sessionInvalid ? null : _load,
                    child: Text(_loadError!),
                  ),
                if (_ready && _groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '创建分组，选择关系图标并添加好友',
                      style: TextStyle(color: Color(0x80C9B69E)),
                    ),
                  ),
                for (final group in _groups)
                  Column(
                    children: [
                      ListTile(
                        onTap: _ready && !_cleaning ? () => _edit(group) : null,
                        leading: Icon(
                          relationshipIcons[group.icon],
                          color: legacyMessageGold,
                          size: 23,
                        ),
                        title: Text(
                          group.name,
                          style: const TextStyle(
                            color: legacyMessageGold,
                            fontSize: 15,
                          ),
                        ),
                        trailing: Text(
                          '${group.members.length} 人 ›',
                          style: const TextStyle(color: Color(0x80C9B69E)),
                        ),
                      ),
                      const Divider(
                        indent: 22,
                        endIndent: 22,
                        color: Color(0x1CC9B69E),
                        height: .5,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({
    required this.group,
    required this.contacts,
    this.onSave,
    this.onReload,
    this.onDelete,
  });
  final Future<void> Function(ContactGroup)? onSave;
  final Future<void> Function()? onReload;
  final Future<void> Function()? onDelete;
  final ContactGroup? group;
  final Map<String, String> contacts;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late int _icon = widget.group?.icon ?? 0;
  late final Set<String> _members = {...?widget.group?.members};
  String? _error;
  bool _saving = false, _expired = false;
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    if (widget.onSave != null) {
      _session = SecureSessionStore.changes.stream.listen((_) {
        if (mounted) {
          setState(() {
            _expired = true;
            _name.clear();
            _members.clear();
            _error = '登录状态已变化';
          });
        }
      });
    }
  }

  late final _id = widget.group?.id ?? const Uuid().v4();
  @override
  void dispose() {
    _session?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_saving || _expired || widget.onDelete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: const Text('仅删除这个关系分组，好友和聊天记录会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _expired) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onDelete!();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _expired) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入分组名称');
      return;
    }
    final result = ContactGroup(_id, name, _icon, {..._members});
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave?.call(result);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: widget.group == null ? '新建分组' : '编辑分组',
            onBack: () => Navigator.pop(context),
            trailing: TextButton(
              onPressed: _saving || _expired ? null : _save,
              child: const Text(
                '保存',
                style: TextStyle(color: legacyMessageGold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _name,
                  maxLength: 12,
                  style: const TextStyle(color: legacyMessageGold),
                  decoration: InputDecoration(
                    labelText: '分组名称',
                    hintText: '例如：恋人、同学、好友',
                    errorText: _error,
                  ),
                ),
                if (_error != null && widget.onReload != null)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            try {
                              await widget.onReload!();
                              if (mounted) {
                                setState(
                                  () => _error = '已尝试刷新分组，编辑内容已保留，请重新保存',
                                );
                              }
                            } catch (error) {
                              if (mounted) {
                                setState(() => _error = error.toString());
                              }
                            }
                          },
                    child: const Text('刷新分组并保留编辑'),
                  ),
                if (widget.onDelete != null)
                  TextButton(
                    onPressed: _saving || _expired ? null : _delete,
                    child: const Text(
                      '删除分组',
                      style: TextStyle(color: Color(0xFFFF7373)),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  '选择关系图标',
                  style: TextStyle(color: legacyMessageGold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < relationshipIcons.length; i++)
                      Semantics(
                        selected: _icon == i,
                        label: '关系图标${i + 1}',
                        child: InkWell(
                          onTap: () => setState(() => _icon = i),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _icon == i
                                  ? const Color(0xFF393025)
                                  : legacyMessagePanel,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              relationshipIcons[i],
                              color: legacyMessageGold,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('选择好友', style: TextStyle(color: legacyMessageGold)),
                for (final contact
                    in (_expired
                        ? <MapEntry<String, String>>[]
                        : widget.contacts.entries))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: legacyMessageGold,
                    checkColor: Colors.black,
                    title: Text(
                      contact.value,
                      style: const TextStyle(
                        color: Color(0xBBFFFFFF),
                        fontSize: 15,
                      ),
                    ),
                    value: _members.contains(contact.key),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _members.add(contact.key);
                      } else {
                        _members.remove(contact.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
