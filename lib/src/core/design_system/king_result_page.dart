import 'package:flutter/material.dart';

import 'king_components.dart';
import 'king_theme.dart';

/// Result assets selected for contrast against the actual page background.
class KingResultIcon extends StatelessWidget {
  const KingResultIcon({
    super.key,
    this.success = true,
    this.background = Colors.black,
    this.size = 72,
  });
  final bool success;
  final Color background;
  final double size;
  @override
  Widget build(BuildContext context) {
    final dark = background.computeLuminance() < 0.5;
    final name = success
        ? (dark ? 'success2' : 'success1')
        : (dark ? 'err2' : 'err3');
    return Image.asset(
      'assets/legacy/storage/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class KingResultPage extends StatelessWidget {
  const KingResultPage({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onReturn,
    this.titleKey,
    this.success = true,
    this.tapAnywhere = false,
  });
  final String title, description, buttonText;
  final VoidCallback onReturn;
  final Key? titleKey;
  final bool success, tapAnywhere;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tapAnywhere ? onReturn : null,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: bounds.maxHeight,
                minWidth: bounds.maxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: bounds.maxHeight > 550 ? 68 : 8,
                        left: 24,
                        right: 24,
                      ),
                      child: Column(
                        children: [
                          KingResultIcon(success: success),
                          const SizedBox(height: 28),
                          Text(
                            title,
                            key: titleKey,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFC9B69E),
                              fontSize: 17,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: SizedBox(
                        width: KingBackButton.contentWidth(context),
                        height: 45,
                        child: FilledButton(
                          onPressed: onReturn,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(45),
                            backgroundColor: KingColors.brand,
                            foregroundColor: KingColors.onBrand,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(buttonText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
