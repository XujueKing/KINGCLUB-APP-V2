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
  });
  final ContactGroupsRepository? repository;
  final Map<String, String> contacts;
  final List<ContactGroup> groups;
  final ValueChanged<List<ContactGroup>> onChanged;
  @override
  State<RelationshipGroupsPage> createState() => _RelationshipGroupsPageState();
}

class _RelationshipGroupsPageState extends State<RelationshipGroupsPage> {
  late List<ContactGroup> _groups = widget.repository == null
      ? List.of(widget.groups)
      : [];
  bool _ready = false, _sessionInvalid = false;
  String? _loadError;
  int _generation = 0;
  StreamSubscription<void>? _session;
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
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_sessionInvalid) throw StateError('登录状态已变化');
    final generation = ++_generation;
    try {
      final groups = await widget.repository!.load();
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

  void _update(List<ContactGroup> groups) {
    setState(() => _groups = groups);
    widget.onChanged(List.of(groups));
  }

  Future<void> _edit(ContactGroup? group) async {
    final result = await Navigator.of(context).push<ContactGroup>(
      MaterialPageRoute(
        builder: (_) => _GroupEditor(
          group: group,
          contacts: widget.contacts,
          onSave: widget.repository == null ? null : _saveReal,
          onReload: widget.repository == null ? null : _load,
        ),
      ),
    );
    if (!mounted || result == null || widget.repository != null) return;
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
              onPressed: _ready ? () => _edit(null) : null,
              icon: const Icon(Icons.add, color: legacyMessageGold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
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
                        onTap: _ready ? () => _edit(group) : null,
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
  });
  final Future<void> Function(ContactGroup)? onSave;
  final Future<void> Function()? onReload;
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
