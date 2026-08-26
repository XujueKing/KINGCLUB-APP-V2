import 'package:flutter/material.dart';

const _gold = Color(0xFFC9B69E);
const _darkBrown = Color(0xFF422E19);

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenTogether,
    required this.onOpenParty,
    required this.onOpenScanner,
  });

  final VoidCallback onOpenTogether;
  final VoidCallback onOpenParty;
  final VoidCallback onOpenScanner;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _showMock(String label) async {
    final details = switch (label) {
      '兼职探店品鉴官' => (
        'assets/legacy/home/mock_hero_recruitment.png',
        'KINGCLUB 正在招募兼职探店品鉴官。当前页面使用固定 Fake 内容，只用于还原旧版运营详情的展开与返回流程。',
      ),
      '最帅小哥哥活动' => (
        'assets/legacy/home/mock_poster_handsome.png',
        '谁是最帅小哥哥 · 投稿有奖。活动投稿、审核和奖励均未连接服务器。',
      ),
      'AI 卡颜局' => (
        'assets/legacy/home/mock_poster_party.png',
        '男女会员 1:1 随机组局。点击下方按钮可继续查看现有 VIP 组局 Fake 页面。',
      ),
      '生日有礼' => (
        'assets/legacy/home/mock_poster_birthday.png',
        '生日会员权益展示。当前仅模拟旧版内容阅读流程，不发放真实权益。',
      ),
      _ => (
        'assets/legacy/home/mock_poster_music.png',
        '玩音乐能赚钱。当前仅模拟旧版运营内容，不提交报名或产生真实收益。',
      ),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15120F),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  details.$1,
                  height: label == '兼职探店品鉴官' ? 190 : 300,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                label,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                details.$2,
                style: const TextStyle(
                  color: Color(0xBBFFFFFF),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: Colors.black,
          backgroundColor: _gold,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 122),
                sliver: SliverList.list(
                  children: [
                    const _MemberHeader(),
                    const SizedBox(height: 18),
                    _HeroBanner(onTap: () => _showMock('兼职探店品鉴官')),
                    const SizedBox(height: 10),
                    _QuickActions(
                      onTogether: widget.onOpenTogether,
                      onParty: widget.onOpenParty,
                      onScan: widget.onOpenScanner,
                    ),
                    const SizedBox(height: 10),
                    _PromotionGrid(onTap: _showMock),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          const Image(
            image: AssetImage('assets/legacy/home/logo_2.png'),
            width: 102,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '青铜',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.male, size: 13, color: _gold),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'L-0 EXP:50',
                        maxLines: 1,
                        style: TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Row(
                  children: [
                    _AssetPill(
                      image: 'assets/legacy/home/gold.png',
                      value: '50',
                    ),
                    SizedBox(width: 8),
                    _AssetPill(
                      image: 'assets/legacy/home/diamond.png',
                      value: '0',
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(
                    value: .5,
                    minHeight: 4,
                    color: _gold,
                    backgroundColor: Color(0x33C9B69E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetPill extends StatelessWidget {
  const _AssetPill({required this.image, required this.value});

  final String image;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0x332E2922),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Image.asset(image, width: 20, height: 20),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _gold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '招募兼职探店品鉴官',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 2.1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/legacy/home/mock_hero_recruitment.png',
                  fit: BoxFit.cover,
                ),
                const Positioned(
                  left: 20,
                  bottom: 15,
                  child: Opacity(
                    opacity: .72,
                    child: Image(
                      image: AssetImage('assets/legacy/home/logo_2.png'),
                      width: 76,
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 16,
                  child: Transform.rotate(
                    angle: -.035,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      color: const Color(0xFF9A6339),
                      child: const Text(
                        '招募兼职探店品鉴官',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 15,
                  bottom: 3,
                  child: Text(
                    'RECRUITING PART-TIME WORKERS',
                    style: TextStyle(
                      color: Color(0xFFD8C9B6),
                      fontSize: 8,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onTogether,
    required this.onParty,
    required this.onScan,
  });

  final VoidCallback onTogether;
  final VoidCallback onParty;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            flex: 10,
            child: _LegacyAction(
              title: '一起玩',
              subtitle: 'TOGETHER PLAY',
              backgroundAsset: 'assets/legacy/home/H01.png',
              onTap: onTogether,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: _LegacyAction(
              title: '组局玩',
              subtitle: 'EXCLUSIVE SEATS',
              backgroundAsset: 'assets/legacy/home/H02.png',
              onTap: onParty,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: _LegacyAction(
              title: '',
              subtitle: 'SCAN QR',
              backgroundAsset: 'assets/legacy/home/qrcode2.png',
              foregroundAsset: 'assets/legacy/home/qrcode3.png',
              onTap: onScan,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyAction extends StatelessWidget {
  const _LegacyAction({
    required this.title,
    required this.subtitle,
    required this.backgroundAsset,
    required this.onTap,
    this.foregroundAsset,
  });

  final String title;
  final String subtitle;
  final String backgroundAsset;
  final String? foregroundAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title.isEmpty ? '扫码' : title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const RadialGradient(
                center: Alignment(-.6, -.6),
                radius: 1.6,
                colors: [Color(0xFFB8A289), Color(0xFF7E6951)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -8,
                  top: -10,
                  child: Opacity(
                    opacity: .12,
                    child: Image.asset(backgroundAsset, width: 72, height: 72),
                  ),
                ),
                if (foregroundAsset != null)
                  Align(
                    alignment: const Alignment(0, -.25),
                    child: Image.asset(foregroundAsset!, width: 29, height: 29),
                  )
                else
                  Align(
                    alignment: const Alignment(.35, -.12),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _darkBrown,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Align(
                  alignment: const Alignment(.25, .68),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    style: const TextStyle(
                      color: _darkBrown,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionGrid extends StatelessWidget {
  const _PromotionGrid({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _PosterCard(
                asset: 'assets/legacy/home/mock_poster_handsome.png',
                title: '谁是最帅小哥哥',
                display: 'HANDSOME\nMAN',
                tag: '投稿有奖',
                onTap: () => onTap('最帅小哥哥活动'),
              ),
              const SizedBox(height: 8),
              _PosterCard(
                asset: 'assets/legacy/home/mock_poster_birthday.png',
                title: '生日有礼',
                display: '解锁小姐姐哥哥特权',
                palette: const Color(0xFFA82F61),
                onTap: () => onTap('生日有礼'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              _PosterCard(
                asset: 'assets/legacy/home/mock_poster_party.png',
                title: 'AI 卡颜局',
                display: '男女会员 1:1\n随机组局',
                tag: '新玩法',
                palette: const Color(0xFFFFB1D6),
                onTap: () => onTap('AI 卡颜局'),
              ),
              const SizedBox(height: 8),
              _PosterCard(
                asset: 'assets/legacy/home/mock_poster_music.png',
                title: '玩音乐能赚钱',
                display: 'PLAY MUSIC',
                onTap: () => onTap('玩音乐能赚钱'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.asset,
    required this.title,
    required this.display,
    required this.onTap,
    this.tag,
    this.palette = const Color(0xFFE7D5B9),
  });

  final String asset;
  final String title;
  final String display;
  final String? tag;
  final Color palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: .72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(asset, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Color(0x00000000),
                        Color(0x66000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 8,
                  top: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        display,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          height: .93,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tag != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: const Color(0xCC8C653F),
                      child: Text(
                        tag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
