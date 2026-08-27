import 'package:flutter/material.dart';

const legacyGold = Color(0xFFC9B69E);
const legacyPink = Color(0xFFFBAFDA);
const legacyMagenta = Color(0xFFAD016A);

class LegacyClubScaffold extends StatelessWidget {
  const LegacyClubScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
    this.showMockLabel = true,
    this.onTitleLongPress,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;
  final bool showMockLabel;
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.56),
            radius: .9,
            colors: [Color(0xEF252018), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 6,
                      child: IconButton(
                        tooltip: '返回',
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: legacyGold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: const ValueKey('legacy-club-title'),
                      onLongPress: onTitleLongPress,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: legacyGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showMockLabel)
                      const Positioned(
                        right: 18,
                        child: Text(
                          'UI MOCK',
                          style: TextStyle(
                            color: Color(0x66C9B69E),
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class LegacyDateStrip extends StatelessWidget {
  const LegacyDateStrip({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const dates = [
    ('今天', '08.26'),
    ('周四', '08.27'),
    ('周五', '08.28'),
    ('周六', '08.29'),
    ('周日', '08.30'),
    ('周一', '08.31'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Semantics(
            button: true,
            selected: selected,
            label: '${dates[index].$1} ${dates[index].$2}',
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 60,
                decoration: BoxDecoration(
                  color: selected ? legacyGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dates[index].$1,
                      style: TextStyle(
                        color: selected ? Colors.black : legacyGold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dates[index].$2,
                      style: TextStyle(
                        color: selected ? Colors.black : legacyGold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LegacyClubButton extends StatelessWidget {
  const LegacyClubButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.light = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(82, 38),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        backgroundColor: light ? legacyPink : const Color(0xFF24180A),
        foregroundColor: light ? const Color(0xFF33261D) : legacyGold,
        disabledBackgroundColor: const Color(0x33222222),
        disabledForegroundColor: const Color(0x55FFFFFF),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }
}

void showFakeResult(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$message（仅 Fake 数据，未连接服务器）')));
}
