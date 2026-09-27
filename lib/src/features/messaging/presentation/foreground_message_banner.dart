import 'dart:ui';

import 'package:flutter/material.dart';

/// Legacy content-box: width 650 + 60 rpx, height 110 + 40 rpx.
class ForegroundMessageBanner extends StatelessWidget {
  const ForegroundMessageBanner({
    super.key,
    required this.visible,
    required this.onTap,
    required this.onDismiss,
  });
  final bool visible;
  final VoidCallback onTap, onDismiss;
  @override
  Widget build(BuildContext context) {
    final r = MediaQuery.sizeOf(context).width / 750;
    final radius = BorderRadius.circular(50 * r);
    final caption = TextStyle(
      inherit: false,
      color: const Color(0x80FFFFFF),
      fontSize: 24 * r,
      fontWeight: FontWeight.w400,
    );
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -250 / 150),
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.ease,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: const Color(0x80000000), blurRadius: 10 * r),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -100) onDismiss();
                  },
                  child: Container(
                    key: const ValueKey('legacy-message-banner-card'),
                    height: 150 * r,
                    color: const Color(0x24FFFFFF),
                    padding: EdgeInsets.symmetric(
                      horizontal: 30 * r,
                      vertical: 20 * r,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20 * r),
                          child: Image.asset(
                            'assets/legacy/messaging/notification_kingclub.png',
                            width: 86 * r,
                            height: 86 * r,
                            fit: BoxFit.fill,
                            excludeFromSemantics: true,
                          ),
                        ),
                        SizedBox(width: 20 * r),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('K聊', style: caption),
                                  SizedBox(height: 8 * r),
                                  Text(
                                    '您收到一条新消息',
                                    style: TextStyle(
                                      inherit: false,
                                      color: const Color(0xAAFFFFFF),
                                      fontSize: 28 * r,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16 * r),
                        Text('现在', style: caption),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
