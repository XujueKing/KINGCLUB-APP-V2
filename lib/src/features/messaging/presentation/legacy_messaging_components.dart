import '../../../core/design_system/king_theme.dart';

import 'package:flutter/material.dart';

const legacyMessageGold = Color(0xFFC9B69E);
const legacyMessagePanel = Color(0xFF191715);
const legacyMessageLine = Color(0x40C9B69E);

class LegacyMessagingHeader extends StatelessWidget {
  const LegacyMessagingHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.backgroundColor = Colors.black,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(bottom: BorderSide(color: legacyMessageLine)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('messaging-back'),
              tooltip: '返回',
              onPressed: onBack,
              icon: Image.asset(
                'assets/legacy/friendship/back.png',
                width: 11,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing!),
        ],
      ),
    );
  }
}

class LegacyFakeAvatar extends StatelessWidget {
  const LegacyFakeAvatar({super.key, this.size = 46, this.kingClub = false});

  final double size;
  final bool kingClub;

  @override
  Widget build(BuildContext context) {
    if (kingClub) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/legacy/friendship/touxiang.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Shared native header; dimensions follow the old 750rpx canvas.
class LegacyConversationTabs extends StatelessWidget {
  const LegacyConversationTabs({
    super.key,
    required this.chatSelected,
    required this.onChat,
    required this.onContacts,
    required this.onAdd,
  });
  final bool chatSelected;
  final VoidCallback? onChat, onContacts, onAdd;
  @override
  Widget build(BuildContext context) {
    final r = MediaQuery.sizeOf(context).width / 750;
    Widget tab(String title, bool selected, VoidCallback? onTap) => Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            title,
            style: selected
                ? kingSectionTitleStyle
                : const TextStyle(
                    color: Color(0x80C9B69E),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 10,
            right: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                tab('聊天', chatSelected, onChat),
                const SizedBox(width: 16),
                tab('通讯录', !chatSelected, onContacts),
              ],
            ),
          ),
          Positioned(
            right: 18 - (44 - 40 * r) / 2,
            top: 0,
            child: IconButton(
              tooltip: '添加好友',
              constraints: const BoxConstraints.tightFor(width: 44, height: 48),
              padding: EdgeInsets.zero,
              onPressed: onAdd,
              icon: Image.asset(
                'assets/legacy/messaging/add.png',
                width: 40 * r,
                height: 40 * r,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
