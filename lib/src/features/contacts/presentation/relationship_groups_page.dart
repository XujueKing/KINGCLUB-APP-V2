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

class ContactGroup {
  ContactGroup(this.id, this.name, this.icon, this.members);
  final String id;
  final String name;
  final int icon;
  final Set<String> members;
}

class RelationshipGroupsPage extends StatefulWidget {
  const RelationshipGroupsPage({
    super.key,
    required this.contacts,
    required this.groups,
    required this.onChanged,
  });
  final Map<String, String> contacts;
  final List<ContactGroup> groups;
  final ValueChanged<List<ContactGroup>> onChanged;
  @override
  State<RelationshipGroupsPage> createState() => _RelationshipGroupsPageState();
}

class _RelationshipGroupsPageState extends State<RelationshipGroupsPage> {
  late List<ContactGroup> _groups = List.of(widget.groups);
  void _update(List<ContactGroup> groups) {
    setState(() => _groups = groups);
    widget.onChanged(List.of(groups));
  }

  Future<void> _edit(ContactGroup? group) async {
    final result = await Navigator.of(context).push<ContactGroup>(
      MaterialPageRoute(
        builder: (_) => _GroupEditor(group: group, contacts: widget.contacts),
      ),
    );
    if (!mounted || result == null) return;
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
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add, color: legacyMessageGold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (_groups.isEmpty)
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
                        onTap: () => _edit(group),
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
  const _GroupEditor({required this.group, required this.contacts});
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
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入分组名称');
      return;
    }
    Navigator.pop(
      context,
      ContactGroup(
        widget.group?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name,
        _icon,
        {..._members},
      ),
    );
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
              onPressed: _save,
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
                for (final contact in widget.contacts.entries)
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
