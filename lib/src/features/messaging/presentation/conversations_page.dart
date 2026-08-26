import 'package:flutter/material.dart';

const _gold = Color(0xFFC9B69E);

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    required this.active,
    required this.onOpenContacts,
    required this.onAddFriend,
  });

  final bool active;
  final VoidCallback onOpenContacts;
  final VoidCallback onAddFriend;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  bool _pinnedExpanded = true;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                children: [
                  _PinnedToggle(
                    expanded: _pinnedExpanded,
                    onTap: () =>
                        setState(() => _pinnedExpanded = !_pinnedExpanded),
                  ),
                  if (_pinnedExpanded)
                    _KingClubConversation(onTap: _showConversation),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 66,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 17,
            child: IconButton(
              tooltip: '添加好友',
              onPressed: widget.onAddFriend,
              icon: const Icon(
                Icons.add_circle_outline,
                color: _gold,
                size: 29,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onOpenContacts,
                child: const Text(
                  '通讯录',
                  style: TextStyle(color: Color(0x66C9B69E), fontSize: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 0, 11),
                child: Text(
                  '聊天',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConversation() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15120F),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .62,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    _KingAvatar(size: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'KING CLUB',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'UI MOCK',
                      style: TextStyle(
                        color: Color(0x55C9B69E),
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x332E2922),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      '收到50枚金币',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 15),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  '当前为离线 Fake 会话，不连接 WebSocket，也不会发送消息。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedToggle extends StatelessWidget {
  const _PinnedToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0x202E2922),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const SizedBox(width: 38),
              Icon(
                expanded ? Icons.format_list_bulleted : Icons.push_pin_outlined,
                size: 22,
                color: const Color(0x66C9B69E),
              ),
              const SizedBox(width: 22),
              Text(
                expanded ? '折叠置顶聊天' : '1 个置顶聊天',
                style: const TextStyle(color: Color(0x66C9B69E), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KingClubConversation extends StatelessWidget {
  const _KingClubConversation({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 116,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x332E2922), width: 1),
            ),
          ),
          child: const Row(
            children: [
              _KingAvatar(size: 58),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KING CLUB',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '收到50枚金币',
                      style: TextStyle(color: Color(0x66FFFFFF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment(0, -.38),
                child: Text(
                  '08月23日',
                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KingAvatar extends StatelessWidget {
  const _KingAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: const BoxDecoration(
        color: Color(0xFF3047D6),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'assets/legacy/home/logo_2.png',
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
      ),
    );
  }
}
