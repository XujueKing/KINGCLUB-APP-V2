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
