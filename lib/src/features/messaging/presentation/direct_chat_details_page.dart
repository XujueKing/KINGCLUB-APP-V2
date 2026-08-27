import 'package:flutter/material.dart';

import '../../contacts/presentation/relationship_permissions_page.dart';
import 'legacy_messaging_components.dart';

class DirectChatDetailsPage extends StatefulWidget {
  const DirectChatDetailsPage({super.key, required this.peerName});

  final String peerName;

  @override
  State<DirectChatDetailsPage> createState() => _DirectChatDetailsPageState();
}

class _DirectChatDetailsPageState extends State<DirectChatDetailsPage> {
  final _searchController = TextEditingController();
  bool _muted = false;
  bool _pinned = true;
  bool _searching = false;

  static const _history = ['周末 KING CLUB 见', '好，晚上九点', 'A6 卡座见'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: _searching ? '查找聊天内容' : '聊天详情',
              backgroundColor: const Color(0x141C1814),
              onBack: () {
                if (_searching) {
                  setState(() {
                    _searching = false;
                    _searchController.clear();
                  });
                } else {
                  Navigator.pop(context, false);
                }
              },
            ),
            Expanded(child: _searching ? _searchView() : _settingsView()),
          ],
        ),
      ),
    );
  }

  Widget _settingsView() {
    return ListView(
      key: const ValueKey('direct-chat-details-settings'),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Container(
          color: const Color(0x14C9B69E),
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
          child: Row(
            children: [
              Column(
                children: [
                  const LegacyFakeAvatar(size: 52),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 72,
                    child: Text(
                      widget.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SettingsGroup(
          children: [
            _SettingsRow(
              key: const ValueKey('direct-chat-details-search'),
              label: '查找聊天内容',
              onTap: () => setState(() => _searching = true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SettingsGroup(
          children: [
            _SettingsRow(
              label: '消息免打扰',
              trailing: Switch(
                key: const ValueKey('direct-chat-details-muted'),
                value: _muted,
                activeTrackColor: const Color(0xFF07C160),
                onChanged: (value) => setState(() => _muted = value),
              ),
            ),
            _SettingsRow(
              label: '置顶聊天',
              trailing: Switch(
                key: const ValueKey('direct-chat-details-pinned'),
                value: _pinned,
                activeTrackColor: const Color(0xFF07C160),
                onChanged: (value) => setState(() => _pinned = value),
              ),
            ),
            _SettingsRow(
              key: const ValueKey('direct-chat-details-permissions'),
              label: '关系权限',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => RelationshipPermissionsPage(
                    targetRef: 'contact-seatmate',
                    displayName: widget.peerName,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SettingsGroup(
          children: [
            _SettingsRow(
              key: const ValueKey('direct-chat-details-clear'),
              label: '清空聊天记录',
              centered: true,
              onTap: _confirmClear,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '当前设置和聊天记录均为离线 Fake，仅用于 UI 流程演示。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0x55FFFFFF), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _searchView() {
    final query = _searchController.text.trim();
    final results = _history.where((item) => item.contains(query)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const ValueKey('direct-chat-details-search-input'),
            controller: _searchController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索聊天内容',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? const Center(
                  child: Text(
                    '输入关键词查找 Fake 文本消息',
                    style: TextStyle(color: Color(0x66FFFFFF)),
                  ),
                )
              : results.isEmpty
              ? const Center(
                  child: Text(
                    '未找到相关聊天内容',
                    style: TextStyle(color: Color(0x66FFFFFF)),
                  ),
                )
              : ListView(
                  children: results
                      .map(
                        (result) => ListTile(
                          leading: const LegacyFakeAvatar(size: 42),
                          title: Text(
                            result,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text('今天 21:08'),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmClear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('再次确认清空聊天记录'),
        content: const Text('清空后仅对你隐藏且无法恢复，对方的聊天记录不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('direct-chat-details-confirm-clear'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) Navigator.pop(context, true);
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x14C9B69E),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
    this.centered = false,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x20C9B69E))),
        ),
        child: Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            ?trailing,
            if (!centered && trailing == null)
              const Icon(Icons.chevron_right, color: Color(0x66FFFFFF)),
          ],
        ),
      ),
    );
  }
}
