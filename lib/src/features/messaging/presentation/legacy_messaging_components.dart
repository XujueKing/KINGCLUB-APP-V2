import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/core/design_system/king_notice.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design_system/king_theme.dart';

import 'package:flutter/material.dart';

const legacyActionMenuBackground = Color(0xFF28231C);
const legacyActionMenuForeground = Color(0xFFB7ADA0);
const legacyActionMenuTextStyle = TextStyle(
  color: legacyActionMenuForeground,
  fontSize: 15,
  fontWeight: FontWeight.w400,
);

class LegacyActionMenuStyle extends StatelessWidget {
  const LegacyActionMenuStyle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => IconTheme(
    data: const IconThemeData(color: legacyActionMenuForeground, size: 21),
    child: ListTileTheme(
      data: const ListTileThemeData(
        textColor: legacyActionMenuForeground,
        iconColor: legacyActionMenuForeground,
        titleTextStyle: legacyActionMenuTextStyle,
        subtitleTextStyle: TextStyle(color: Color(0x80B7ADA0), fontSize: 12),
        minTileHeight: 52,
        minLeadingWidth: 21,
        horizontalTitleGap: 11,
        contentPadding: EdgeInsets.symmetric(horizontal: 18),
      ),
      child: child,
    ),
  );
}

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
    this.alignToConversationTitle = false,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final Color backgroundColor;
  final bool alignToConversationTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(bottom: BorderSide(color: legacyMessageLine)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            // The 8 dp glyph has 20 dp inset inside its 48 dp target.
            left: alignToConversationTitle
                ? -2
                : KingBackButton.leftOffset(context),
            top: KingBackButton.safeAreaOffset.dy,
            child: KingBackButton(
              key: const ValueKey('messaging-back'),
              tooltip: '返回',
              onPressed: onBack,
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
            Positioned(
              // Match the back button center, not the wider icon edge.
              right: alignToConversationTitle ? -2 : 18,
              top: 4,
              height: 48,
              child: trailing!,
            ),
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
    this.onScan,
    this.onPersonalQr,
  });
  final bool chatSelected;
  final VoidCallback? onChat, onContacts, onAdd, onScan, onPersonalQr;
  @override
  Widget build(BuildContext context) {
    final r = MediaQuery.sizeOf(context).width / 750;
    Widget tab(String title, bool selected, VoidCallback? onTap) => Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                FocusScope.of(context).unfocus();
                onTap();
              },
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
      height: 58,
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
            child: Builder(
              builder: (anchorContext) => IconButton(
                tooltip: '添加好友',
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                onPressed: onAdd == null
                    ? null
                    : () => _showActions(anchorContext),
                icon: Image.asset(
                  'assets/legacy/messaging/add.png',
                  width: 40 * r,
                  height: 40 * r,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final selected = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Stack(
        children: [
          Positioned(
            top: origin.dy + box.size.height - 2,
            right: 12,
            width: 164,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    right:
                        (MediaQuery.sizeOf(context).width -
                                origin.dx -
                                box.size.width / 2 -
                                20)
                            .clamp(0, 150),
                  ),
                  child: CustomPaint(
                    size: const Size(16, 8),
                    painter: _MenuPointer(),
                  ),
                ),
                Material(
                  color: legacyActionMenuBackground,
                  borderRadius: BorderRadius.circular(5),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 50),
                            child: Divider(
                              height: .5,
                              thickness: .5,
                              color: Color(0x18C9B69E),
                            ),
                          ),
                        InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(i),
                          child: SizedBox(
                            height: 52,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    [
                                      Icons.chat_bubble_rounded,
                                      Icons.person_add_alt_1_rounded,
                                      Icons.qr_code_scanner_rounded,
                                      Icons.qr_code_rounded,
                                    ][i],
                                    color: legacyActionMenuForeground,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 11),
                                  Flexible(
                                    child: Text(
                                      ['发起群聊', '添加朋友', '扫一扫', '我的二维码'][i],
                                      style: legacyActionMenuTextStyle,
                                    ),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
    if (!context.mounted || selected == null) return;
    if (selected == 1) {
      onAdd?.call();
    } else if (selected == 2 && onScan != null) {
      onScan!();
    } else if (selected == 3 && onPersonalQr != null) {
      onPersonalQr!();
    } else {
      KingNotice.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected == 0
                ? '群聊功能暂未开放'
                : selected == 3
                ? '二维码暂不可用'
                : '扫码暂不可用',
          ),
        ),
      );
    }
  }
}

class _MenuPointer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = legacyActionMenuBackground,
    );
  }

  @override
  bool shouldRepaint(covariant _MenuPointer oldDelegate) => false;
}

class LegacyConversationSearch extends StatefulWidget {
  const LegacyConversationSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = '搜索',
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hint;
  @override
  State<LegacyConversationSearch> createState() =>
      _LegacyConversationSearchState();
}

class _LegacyConversationSearchState extends State<LegacyConversationSearch> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) => SizedBox(
        height: 84 * MediaQuery.sizeOf(context).width / 750,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          maxLength: 40,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: const TextStyle(color: legacyMessageGold, fontSize: 14),
          cursorColor: legacyMessageGold,
          decoration: InputDecoration(
            hintText: _focus.hasFocus ? null : widget.hint,
            hintStyle: const TextStyle(color: Color(0x59C9B69E), fontSize: 14),
            counterText: '',
            filled: true,
            fillColor: const Color(0xB3191715),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            prefixIcon: SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/legacy/messaging/search.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      Color(0x59C9B69E),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清除搜索',
                    onPressed: widget.onClear,
                    icon: const Icon(
                      Icons.close,
                      size: 17,
                      color: Color(0x59C9B69E),
                    ),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    ),
  );
}
