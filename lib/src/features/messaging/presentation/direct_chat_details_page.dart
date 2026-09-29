import '../../contacts/presentation/public_member_page.dart';

import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'create_group_page.dart';
import '../data/group_chat_repository.dart';

import '../../../core/session/secure_session_store.dart';
import 'chat_member_avatar.dart';
import 'chat_history_context_page.dart';
import 'chat_history_search_page.dart';
import '../data/messaging_repository.dart';
import '../data/call_repository.dart';
import '../../../core/design_system/king_notice.dart';

import 'package:flutter/material.dart';

import '../../contacts/presentation/relationship_permissions_page.dart';
import 'legacy_messaging_components.dart';

class DirectChatDetailsPage extends StatefulWidget {
  const DirectChatDetailsPage({
    super.key,
    required this.peerName,
    this.initialMuted = false,
    this.onMutedChanged,
    this.peerAccount,
    this.repository,
    this.initialPinned = false,
    this.initialOnlyChat = false,
    this.loadedHistory = const [],
    this.onCall,
  });

  final String? peerAccount;
  final MessagingRepository? repository;
  final bool initialPinned, initialOnlyChat;
  final List<String> loadedHistory;
  final Future<void> Function(CallMedia media)? onCall;
  final String peerName;
  final bool initialMuted;
  final ValueChanged<bool>? onMutedChanged;

  @override
  State<DirectChatDetailsPage> createState() => _DirectChatDetailsPageState();
}

class _DirectChatDetailsPageState extends State<DirectChatDetailsPage> {
  final _searchController = TextEditingController();
  late bool _muted = widget.initialMuted;
  late bool _pinned = widget.peerAccount == null ? true : widget.initialPinned;
  late bool _onlyChat = widget.initialOnlyChat;
  bool _saving = false;
  bool _invalid = false;
  StreamSubscription<void>? _sessionChanges;
  bool _searching = false;
  late final Future<Map<String, dynamic>> _profile =
      widget.peerAccount != null && widget.repository != null
      ? widget.repository!.avatarProfile(widget.peerAccount!)
      : Future.value({});

  static const _history = ['周末 KING CLUB 见', '好，晚上九点', 'A6 卡座见'];

  String _senderLabel(String account) => account == widget.repository?.account
      ? '我'
      : account == widget.peerAccount
      ? widget.peerName
      : '聊天成员';

  @override
  void initState() {
    super.initState();
    if (widget.peerAccount != null) {
      _sessionChanges = SecureSessionStore.changes.stream.listen((_) {
        if (!mounted) return;
        setState(() {
          _invalid = true;
          _searchController.clear();
        });
      });
    }
  }

  @override
  void dispose() {
    _sessionChanges?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: _searching ? '查找聊天内容' : '聊天详情',
              backgroundColor: const Color(0xFF111111),
              lineColor: const Color(0xFF262626),
              lineWidth: .5,
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
            Expanded(
              child: _invalid
                  ? const Center(child: Text('登录状态已变化，请返回重新进入会话'))
                  : _searching
                  ? _searchView()
                  : _settingsView(),
            ),
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
          color: const Color(0xFF191919),
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  if (widget.peerAccount == null)
                    const LegacyFakeAvatar(size: 52)
                  else
                    GestureDetector(
                      key: const ValueKey('direct-chat-details-avatar'),
                      onTap: widget.repository == null
                          ? null
                          : () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => PublicMemberPage(
                                    account: widget.peerAccount!,
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                            },
                      child: ChatMemberAvatar(
                        profile: _profile,
                        account: widget.peerAccount!,
                        size: 52,
                      ),
                    ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 72,
                    child: Text(
                      widget.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Semantics(
                label: '添加朋友发起群聊',
                button: true,
                child: InkWell(
                  key: const ValueKey('direct-chat-details-create-group'),
                  onTap: _invalid || _saving
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => CreateGroupPage(
                              repository: widget.repository == null
                                  ? null
                                  : GroupChatRepository(widget.repository!),
                              initialMembers: {
                                if (widget.peerAccount != null)
                                  widget.peerAccount!,
                              },
                            ),
                          ),
                        ),
                  borderRadius: BorderRadius.circular(6),
                  child: CustomPaint(
                    painter: const _DashedAvatarBorder(),
                    child: const SizedBox.square(
                      dimension: 52,
                      child: Icon(
                        Icons.add,
                        size: 32,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
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
              onTap: () {
                if (widget.peerAccount != null && widget.repository != null) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ChatHistorySearchPage(
                        account: widget.repository!.account,
                        localConversation: widget.repository!.persistHistory
                            ? 'direct:${widget.peerAccount!}'
                            : null,
                        mediaSearch: (type, before) =>
                            widget.repository!.history(
                              widget.peerAccount!,
                              messageType: type,
                              before: before,
                              limit: 30,
                            ),
                        senderLabel: _senderLabel,
                        onSelected: (message) =>
                            Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ChatHistoryContextPage(
                                  localConversation:
                                      widget.repository!.persistHistory
                                      ? 'direct:${widget.peerAccount!}'
                                      : null,
                                  onCall: widget.onCall,
                                  repository: widget.repository,
                                  senderLabel: _senderLabel,
                                  account: widget.repository!.account,
                                  messageId: message['messageId'] as String,
                                  sequence: message['sequence'] as int,
                                  read: ({before, after, required limit}) =>
                                      widget.repository!.history(
                                        widget.peerAccount!,
                                        before: before,
                                        after: after,
                                        limit: limit,
                                      ),
                                ),
                              ),
                            ),
                        search: (query, before) => widget.repository!.history(
                          widget.peerAccount!,
                          query: query,
                          before: before,
                          limit: 30,
                        ),
                      ),
                    ),
                  );
                } else {
                  setState(() => _searching = true);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SettingsGroup(
          children: [
            _SettingsRow(
              label: '消息免打扰',
              trailing: CupertinoSwitch(
                key: const ValueKey('direct-chat-details-muted'),
                value: _muted,
                activeTrackColor: const Color(0xFF07C160),
                inactiveTrackColor: const Color(0xFF39393D),
                thumbColor: Colors.white,
                onChanged: _saving
                    ? null
                    : (value) => _saveSettings(muted: value),
              ),
            ),
            _SettingsRow(
              label: '置顶聊天',
              trailing: CupertinoSwitch(
                key: const ValueKey('direct-chat-details-pinned'),
                value: _pinned,
                activeTrackColor: const Color(0xFF07C160),
                inactiveTrackColor: const Color(0xFF39393D),
                thumbColor: Colors.white,
                onChanged: _saving
                    ? null
                    : (value) => _saveSettings(pinned: value),
              ),
            ),
            if (widget.peerAccount != null)
              _SettingsRow(
                label: '仅聊天',
                trailing: CupertinoSwitch(
                  key: const ValueKey('direct-chat-details-only-chat'),
                  value: _onlyChat,
                  activeTrackColor: const Color(0xFF07C160),
                  inactiveTrackColor: const Color(0xFF39393D),
                  thumbColor: Colors.white,
                  onChanged: _saving
                      ? null
                      : (value) => _saveSettings(onlyChat: value),
                ),
              )
            else
              _SettingsRow(
                key: const ValueKey('direct-chat-details-permissions'),
                label: '关系权限',
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    allowSnapshotting: false,
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
              centered: false,
              showChevron: false,
              onTap: _saving ? null : _confirmClear,
            ),
          ],
        ),
        if (widget.peerAccount == null)
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
    final history = widget.peerAccount == null
        ? _history
        : widget.loadedHistory;
    final results = history.where((item) => item.contains(query)).toList();
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
              ? Center(
                  child: Text(
                    widget.peerAccount == null
                        ? '输入关键词查找 Fake 文本消息'
                        : '输入关键词查找已加载的消息',
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

  Future<void> _saveSettings({
    bool? muted,
    bool? pinned,
    bool? onlyChat,
  }) async {
    if (_saving || _invalid) return;
    setState(() => _saving = true);
    try {
      if (widget.peerAccount != null) {
        final result = await widget.repository!.settings(
          widget.peerAccount!,
          muted: muted,
          pinned: pinned,
          onlyChat: onlyChat,
        );
        if (result['saved'] != true) throw const FormatException('设置未保存，请重试');
      }
      if (!mounted || _invalid) return;
      setState(() {
        _muted = muted ?? _muted;
        _pinned = pinned ?? _pinned;
        _onlyChat = onlyChat ?? _onlyChat;
      });
      if (muted != null) widget.onMutedChanged?.call(muted);
    } catch (error) {
      if (mounted && !_invalid) KingNotice.of(context).show(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmClear() async {
    if (_saving || _invalid) return;
    setState(() => _saving = true);
    try {
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
      if (clear == true && mounted && !_invalid) {
        try {
          if (widget.peerAccount != null) {
            final result = await widget.repository!.settings(
              widget.peerAccount!,
              hide: true,
            );
            if (result['saved'] != true) {
              throw const FormatException('清空未完成，请重试');
            }
          }
          if (mounted && !_invalid) Navigator.pop(context, true);
        } catch (error) {
          if (mounted && !_invalid) {
            KingNotice.of(context).show(error.toString());
          }
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF191919),
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
    this.showChevron = true,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool centered;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF262626), width: .5),
          ),
        ),
        child: Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 17),
            ),
            ?trailing,
            if (!centered && trailing == null && showChevron)
              const Icon(Icons.chevron_right, color: Color(0x66FFFFFF)),
          ],
        ),
      ),
    );
  }
}

class _DashedAvatarBorder extends CustomPainter {
  const _DashedAvatarBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.75),
          const Radius.circular(6),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF666666);
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 9) {
        canvas.drawPath(metric.extractPath(start, start + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedAvatarBorder oldDelegate) => false;
}
