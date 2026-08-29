import 'dart:async';

import 'package:flutter/material.dart';

const _gold = Color(0xFFC9B69E);
const _darkBrown = Color(0xFF422E19);

enum HomeDemoState {
  ready,
  initialLoading,
  verifiedMember,
  longNickname,
  unspecifiedGender,
  largeBalance,
  emptyPromotion,
  partialImageError,
  offlineCached,
  fatalError,
  articleCard,
  videoCard,
  sessionInvalid,
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenTogether,
    required this.onOpenParty,
    required this.onOpenScanner,
    this.onSessionResetRequested,
    this.initialState = HomeDemoState.ready,
    this.reselectSignal = 0,
  });

  final VoidCallback onOpenTogether;
  final VoidCallback onOpenParty;
  final VoidCallback onOpenScanner;
  final VoidCallback? onSessionResetRequested;
  final HomeDemoState initialState;
  final int reselectSignal;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scrollController = ScrollController();
  bool _refreshing = false;
  bool _actionOpening = false;
  Timer? _actionTimer;
  late HomeDemoState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    if (_state == HomeDemoState.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionReset());
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialState != oldWidget.initialState) {
      _state = widget.initialState;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (_state == HomeDemoState.sessionInvalid) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showSessionReset(),
        );
      }
    }
    if (widget.reselectSignal != oldWidget.reselectSignal &&
        _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _actionTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() {
        _refreshing = false;
        if (_state == HomeDemoState.fatalError ||
            _state == HomeDemoState.offlineCached) {
          _state = HomeDemoState.ready;
        }
      });
    }
  }

  void _runAction(VoidCallback action) {
    if (_actionOpening) return;
    _actionOpening = true;
    action();
    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(milliseconds: 300), () {
      _actionOpening = false;
    });
  }

  Future<void> _showSessionReset() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('登录状态已失效'),
        content: const Text('首页已停止使用，将清理本地页面状态并返回手机号登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('home-session-reset'),
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onSessionResetRequested?.call();
            },
            child: const Text('返回登录'),
          ),
        ],
      ),
    );
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
    if (_state == HomeDemoState.fatalError) {
      return ColoredBox(
        color: Colors.black,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 58, color: _gold),
                  const SizedBox(height: 16),
                  const Text(
                    '首页暂时无法显示',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '当前为离线 Fake 错误，不会显示技术异常原文。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0x99FFFFFF)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('home-fatal-retry'),
                    onPressed: () =>
                        setState(() => _state = HomeDemoState.ready),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final loading = _state == HomeDemoState.initialLoading;
    final empty = _state == HomeDemoState.emptyPromotion;
    final offline = _state == HomeDemoState.offlineCached;
    final member = switch (_state) {
      HomeDemoState.verifiedMember => const _MemberPresentation(verified: true),
      HomeDemoState.longNickname => const _MemberPresentation(
        nickname: '这是一个用于验证安全截断的很长昵称',
      ),
      HomeDemoState.unspecifiedGender => const _MemberPresentation(
        genderAsset: null,
      ),
      HomeDemoState.largeBalance => const _MemberPresentation(
        gold: '12.8万',
        diamond: '9.9万',
        progress: 1,
      ),
      _ => const _MemberPresentation(),
    };

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: Colors.black,
          backgroundColor: _gold,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeStickyHeaderDelegate(
                  presentation: member,
                  textScale: MediaQuery.textScalerOf(context).scale(1),
                  viewportWidth: MediaQuery.sizeOf(context).width,
                  showHero: !empty,
                  hero: _HeroBanner(
                    loading: loading,
                    imageError: _state == HomeDemoState.partialImageError,
                    onTap: () => _showMock('兼职探店品鉴官'),
                    onRetry: () => setState(() => _state = HomeDemoState.ready),
                  ),
                  quickActions: _QuickActions(
                    onTogether: () => _runAction(widget.onOpenTogether),
                    onParty: () => _runAction(widget.onOpenParty),
                    onScan: () => _runAction(widget.onOpenScanner),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 230),
                sliver: SliverList.list(
                  children: [
                    if (offline) ...[
                      const _HomeStatusBanner(
                        icon: Icons.wifi_off_rounded,
                        label: '离线内容 · 最近更新 5 分钟前',
                      ),
                    ],
                    if (_refreshing) ...[
                      const SizedBox(height: 8),
                      const _HomeStatusBanner(
                        icon: Icons.refresh_rounded,
                        label: '正在刷新，当前内容继续保留',
                        busy: true,
                      ),
                    ],
                    if (empty)
                      _EmptyPromotions(
                        onRestore: () =>
                            setState(() => _state = HomeDemoState.ready),
                      )
                    else
                      _PromotionGrid(
                        loading: loading,
                        imageError: _state == HomeDemoState.partialImageError,
                        mode: _state == HomeDemoState.articleCard
                            ? _PromotionMode.article
                            : _state == HomeDemoState.videoCard
                            ? _PromotionMode.video
                            : _PromotionMode.poster,
                        onTap: _showMock,
                        onRecover: () =>
                            setState(() => _state = HomeDemoState.ready),
                      ),
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

class _MemberPresentation {
  const _MemberPresentation({
    this.nickname = '青铜',
    this.gold = '50',
    this.diamond = '0',
    this.progress = .5,
    this.verified = false,
    this.genderAsset = 'assets/legacy/home/man4.png',
  });

  final String nickname;
  final String gold;
  final String diamond;
  final double progress;
  final bool verified;
  final String? genderAsset;
}

class _HomeStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeStickyHeaderDelegate({
    required this.presentation,
    required this.textScale,
    required this.viewportWidth,
    required this.showHero,
    required this.hero,
    required this.quickActions,
  });

  final _MemberPresentation presentation;
  final double textScale;
  final double viewportWidth;
  final bool showHero;
  final Widget hero;
  final Widget quickActions;

  double get _scaleExtra => (textScale - 1).clamp(0, 2) * 12;
  double get _contentWidth => viewportWidth - 32;
  double get _expandedMemberExtent => 86 + _scaleExtra;
  double get _compactMemberExtent => 56 + (_scaleExtra * 2 / 3);
  double get _heroHeight => showHero ? _contentWidth * 417 / 690 : 0;
  double get _quickHeight => _contentWidth * 140 / 680;
  double get _shadowExtent => 8;
  double get _expandedHeroTop => _expandedMemberExtent - 20;
  double get _expandedQuickTop =>
      _expandedHeroTop + (showHero ? _heroHeight + 10 : 0);

  @override
  double get maxExtent => _expandedQuickTop + _quickHeight + _shadowExtent;

  @override
  double get minExtent => _compactMemberExtent + _quickHeight + _shadowExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseOffset = shrinkOffset.clamp(0.0, maxExtent - minExtent);
    final progress = collapseOffset / (maxExtent - minExtent);
    final memberTop = 12 - (8 * progress);
    final memberBottom = 6 - (2 * progress);
    final memberExtent =
        _expandedMemberExtent -
        ((_expandedMemberExtent - _compactMemberExtent) * progress);
    final quickTop = _expandedQuickTop - collapseOffset;
    final heroTop = _expandedHeroTop - collapseOffset;

    return ColoredBox(
      key: const ValueKey('home-sticky-header'),
      color: Colors.black,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showHero)
            Positioned(
              left: 16,
              right: 16,
              top: heroTop,
              height: _heroHeight,
              child: hero,
            ),
          Positioned(
            key: const ValueKey('home-member-persistent-header'),
            left: 0,
            right: 0,
            top: 0,
            height: memberExtent,
            child: ColoredBox(
              color: Colors.black,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, memberTop, 16, memberBottom),
                child: _MemberHeader(
                  presentation: presentation,
                  compactProgress: progress,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: quickTop,
            height: _quickHeight + _shadowExtent,
            child: Container(
              key: const ValueKey('home-sticky-actions-shadow'),
              padding: EdgeInsets.fromLTRB(16, 0, 16, _shadowExtent),
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .78 * progress),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: quickActions,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeStickyHeaderDelegate oldDelegate) =>
      oldDelegate.presentation != presentation ||
      oldDelegate.textScale != textScale ||
      oldDelegate.viewportWidth != viewportWidth ||
      oldDelegate.showHero != showHero ||
      oldDelegate.hero != hero ||
      oldDelegate.quickActions != quickActions;
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.presentation, this.compactProgress = 0});

  final _MemberPresentation presentation;
  final double compactProgress;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final progress = compactProgress.clamp(0.0, 1.0);
    final height = 68.0 - (20 * progress) + ((textScale - 1).clamp(0, 2) * 12);
    final legacyScale =
        (MediaQuery.sizeOf(context).width / 750) * (1 - (.38 * progress));
    final logoWidth = 140 * legacyScale;
    final logoHeight = logoWidth * 213 / 400;
    final contentLeft = logoWidth + (20 * legacyScale);
    final contentWidth = 360 * legacyScale;
    final topRowHeight = 22 * legacyScale;
    final assetTopGap = 6 * legacyScale;
    final assetHeight = 26 * legacyScale;
    final progressTopGap = 15 * legacyScale;
    final progressHeight = 4 * legacyScale;
    final contentHeight =
        topRowHeight +
        assetTopGap +
        assetHeight +
        progressTopGap +
        progressHeight;

    return SizedBox(
      key: const ValueKey('home-member-header'),
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: (height - logoHeight) / 2,
            width: logoWidth,
            height: logoHeight,
            child: const Image(
              key: ValueKey('home-member-logo'),
              image: AssetImage('assets/legacy/home/logo_2.png'),
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: contentLeft,
            top: (height - contentHeight) / 2,
            width: contentWidth,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: topRowHeight,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            presentation.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _gold,
                              fontSize: 22 * legacyScale,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: 10 * legacyScale),
                        SizedBox(
                          width: 14 * legacyScale,
                          child: presentation.genderAsset == null
                              ? Semantics(label: '未指定性别')
                              : Image.asset(
                                  presentation.genderAsset!,
                                  fit: BoxFit.fitWidth,
                                ),
                        ),
                        SizedBox(width: 10 * legacyScale),
                        Flexible(
                          child: Text(
                            'L-0 EXP:50',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _gold,
                              fontSize: 20 * legacyScale,
                              fontWeight: FontWeight.normal,
                              height: 1,
                            ),
                          ),
                        ),
                        if (presentation.verified) ...[
                          SizedBox(width: 10 * legacyScale),
                          Image.asset(
                            'assets/legacy/home/bigV.png',
                            width: 16 * legacyScale,
                            fit: BoxFit.fitWidth,
                          ),
                          SizedBox(width: 10 * legacyScale),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: assetTopGap),
                  SizedBox(
                    height: assetHeight,
                    child: Row(
                      children: [
                        _AssetPill(
                          image: 'assets/legacy/home/gold.png',
                          value: presentation.gold,
                          iconWidth: 24 * legacyScale,
                          scale: legacyScale,
                        ),
                        SizedBox(width: 15 * legacyScale),
                        _AssetPill(
                          image: 'assets/legacy/home/diamond.png',
                          value: presentation.diamond,
                          iconWidth: 28 * legacyScale,
                          scale: legacyScale,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: progressTopGap),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2 * legacyScale),
                    child: LinearProgressIndicator(
                      key: const ValueKey('home-member-progress'),
                      value: presentation.progress.clamp(0, 1),
                      minHeight: progressHeight,
                      color: _gold,
                      backgroundColor: const Color(0x33C9B69E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetPill extends StatelessWidget {
  const _AssetPill({
    required this.image,
    required this.value,
    required this.iconWidth,
    required this.scale,
  });

  final String image;
  final String value;
  final double iconWidth;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final assetName = image.endsWith('gold.png') ? 'gold' : 'diamond';
    return Container(
      key: ValueKey('home-member-asset-$assetName'),
      width: 120 * scale,
      height: 26 * scale,
      decoration: BoxDecoration(
        color: const Color(0x33C9B69E),
        borderRadius: BorderRadius.circular(13 * scale),
      ),
      child: Row(
        children: [
          Image.asset(
            image,
            width: iconWidth,
            height: image.endsWith('gold.png') ? 24 * scale : null,
            fit: BoxFit.contain,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 20 * scale, right: 10 * scale),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 20 * scale,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({
    required this.onTap,
    required this.loading,
    required this.imageError,
    required this.onRetry,
  });

  final VoidCallback onTap;
  final bool loading;
  final bool imageError;
  final VoidCallback onRetry;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  static const _initialVirtualPage = 10000;

  final _controller = PageController(initialPage: _initialVirtualPage);
  Timer? _timer;
  int _virtualIndex = _initialVirtualPage;
  int _index = 0;
  bool? _motionDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_motionDisabled == disabled) return;
    _motionDisabled = disabled;
    _timer?.cancel();
    if (!disabled && !widget.loading && !widget.imageError) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage(
          _virtualIndex + 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading != oldWidget.loading ||
        widget.imageError != oldWidget.imageError) {
      _motionDisabled = null;
      didChangeDependencies();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !widget.imageError,
      label: widget.imageError ? '运营 Banner 加载失败' : '招募兼职探店品鉴官',
      child: GestureDetector(
        onTap: widget.imageError ? null : widget.onTap,
        child: AspectRatio(
          aspectRatio: 690 / 417,
          child: widget.imageError
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _BannerError(onRetry: widget.onRetry),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      key: const ValueKey('home-banner-pages'),
                      controller: _controller,
                      clipBehavior: Clip.none,
                      physics: const _LeftOnlyPageScrollPhysics(),
                      onPageChanged: (value) => setState(() {
                        _virtualIndex = value;
                        _index = value % 2;
                      }),
                      itemBuilder: (context, index) =>
                          _RecruitmentBanner(alternate: index.isOdd),
                    ),
                    Positioned(
                      bottom: 7,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          2,
                          (index) => Container(
                            key: ValueKey(
                              'home-banner-indicator-$index-${index == _index}',
                            ),
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _index
                                  ? _gold
                                  : const Color(0x60C9B69E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.loading)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const ColoredBox(
                            color: Color(0x99000000),
                            child: Center(
                              child: SizedBox(
                                width: 120,
                                child: LinearProgressIndicator(),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LeftOnlyPageScrollPhysics extends PageScrollPhysics {
  const _LeftOnlyPageScrollPhysics({super.parent});

  @override
  _LeftOnlyPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _LeftOnlyPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (offset > 0) return 0;
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

class _RecruitmentBanner extends StatelessWidget {
  const _RecruitmentBanner({this.alternate = false});

  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final asset = alternate
        ? 'assets/legacy/home/legacy_banner_childrens_day.png'
        : 'assets/legacy/home/legacy_banner_recruitment.png';

    return Image.asset(
      asset,
      key: ValueKey(
        'home-banner-original-${alternate ? 'childrens-day' : 'recruitment'}',
      ),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF18140F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, color: _gold),
            const SizedBox(height: 6),
            const Text('运营图片暂不可用'),
            TextButton(onPressed: onRetry, child: const Text('查看文字详情')),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatefulWidget {
  const _QuickActions({
    required this.onTogether,
    required this.onParty,
    required this.onScan,
  });

  final VoidCallback onTogether;
  final VoidCallback onParty;
  final VoidCallback onScan;

  @override
  State<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<_QuickActions> {
  Timer? _shineClock;
  int _elapsedMilliseconds = 0;
  bool? _motionDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_motionDisabled == disabled) return;
    _motionDisabled = disabled;
    _shineClock?.cancel();
    _elapsedMilliseconds = 0;
    if (disabled) return;

    // The three legacy CSS animations are created with the same DOM row and
    // therefore share a time origin. One clock prevents per-card timer drift.
    const frame = Duration(milliseconds: 33);
    _shineClock = Timer.periodic(frame, (timer) {
      if (!mounted || _motionDisabled == true) return;
      setState(() {
        _elapsedMilliseconds = timer.tick * frame.inMilliseconds;
      });
    });
  }

  double? _progress() {
    if (_motionDisabled == true) return null;
    const period = Duration(seconds: 4);
    return (_elapsedMilliseconds % period.inMilliseconds) /
        period.inMilliseconds;
  }

  @override
  void dispose() {
    _shineClock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The legacy row is 680rpx wide after its 35rpx outer margins:
        // 246 + 14 + 246 + 14 + 160. Scale the complete row as one unit so
        // card proportions and text baselines cannot drift independently.
        final scale = constraints.maxWidth / 680;
        final largeWidth = 246 * scale;
        final scanWidth = 160 * scale;
        final height = 140 * scale;
        final gap = 14 * scale;

        return SizedBox(
          height: height,
          child: Row(
            children: [
              SizedBox(
                width: largeWidth,
                height: height,
                child: _LegacyAction(
                  actionId: 'together',
                  title: '一起玩',
                  subtitle: 'TOGETHER PLAY',
                  backgroundAsset: 'assets/legacy/home/H01.png',
                  scale: scale,
                  shineProgress: _progress(),
                  shineRowWidth: constraints.maxWidth,
                  shineCardOffset: 0,
                  onTap: widget.onTogether,
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: largeWidth,
                height: height,
                child: _LegacyAction(
                  actionId: 'party',
                  title: '组局玩',
                  subtitle: 'EXCLUSIVE SEATS',
                  backgroundAsset: 'assets/legacy/home/H02.png',
                  scale: scale,
                  shineProgress: _progress(),
                  shineRowWidth: constraints.maxWidth,
                  shineCardOffset: largeWidth + gap,
                  onTap: widget.onParty,
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                width: scanWidth,
                height: height,
                child: _LegacyAction(
                  actionId: 'scan',
                  title: '',
                  subtitle: 'SCAN QR',
                  backgroundAsset: 'assets/legacy/home/qrcode2.png',
                  foregroundAsset: 'assets/legacy/home/qrcode3.png',
                  scale: scale,
                  shineProgress: _progress(),
                  shineRowWidth: constraints.maxWidth,
                  shineCardOffset: (largeWidth * 2) + (gap * 2),
                  onTap: widget.onScan,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegacyAction extends StatefulWidget {
  const _LegacyAction({
    required this.actionId,
    required this.title,
    required this.subtitle,
    required this.backgroundAsset,
    required this.scale,
    required this.shineProgress,
    required this.shineRowWidth,
    required this.shineCardOffset,
    required this.onTap,
    this.foregroundAsset,
  });

  final String actionId;
  final String title;
  final String subtitle;
  final String backgroundAsset;
  final double scale;
  final double? shineProgress;
  final double shineRowWidth;
  final double shineCardOffset;
  final String? foregroundAsset;
  final VoidCallback onTap;

  @override
  State<_LegacyAction> createState() => _LegacyActionState();
}

class _LegacyActionState extends State<_LegacyAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final isScan = widget.foregroundAsset != null;

    return Semantics(
      button: true,
      label: isScan
          ? '扫码，${widget.subtitle}'
          : '${widget.title}，${widget.subtitle}',
      child: Material(
        color: Colors.transparent,
        child: AnimatedOpacity(
          key: ValueKey('home-quick-opacity-${widget.actionId}'),
          opacity: _pressed ? .7 : 1,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            key: ValueKey('home-quick-${widget.actionId}'),
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (_pressed != value) setState(() => _pressed = value);
            },
            borderRadius: BorderRadius.circular(15 * scale),
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15 * scale),
                gradient: const RadialGradient(
                  center: Alignment(-.6, -.6),
                  radius: 1.6,
                  colors: [Color(0xFFB8A289), Color(0xFF7E6951)],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15 * scale),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _legacyBackground(scale, isScan),
                    if (widget.shineProgress case final progress?)
                      CustomPaint(
                        key: ValueKey('home-quick-shine-${widget.actionId}'),
                        painter: _LegacyShinePainter(
                          progress: progress,
                          rowWidth: widget.shineRowWidth,
                          cardOffset: widget.shineCardOffset,
                        ),
                      ),
                    if (isScan) _scanContent(scale) else _textContent(scale),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legacyBackground(double scale, bool isScan) {
    final position = switch (widget.actionId) {
      'together' => (left: -20 * scale, top: -15 * scale, size: 126 * scale),
      'party' => (left: -50 * scale, top: -20 * scale, size: 140 * scale),
      _ => (left: -65 * scale, top: -15 * scale, size: 110 * scale),
    };

    final image = Opacity(
      opacity: .1,
      child: Image.asset(
        widget.backgroundAsset,
        width: position.size,
        height: position.size,
        fit: BoxFit.fill,
      ),
    );

    return Positioned(
      left: position.left,
      top: position.top,
      child: isScan
          ? Transform.rotate(angle: .7853981634, child: image)
          : image,
    );
  }

  Widget _textContent(double scale) {
    return Padding(
      padding: EdgeInsets.only(right: 30 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * scale),
            child: Text(
              widget.title,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: _darkBrown,
                fontSize: 38 * scale,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          Text(
            widget.subtitle,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: _darkBrown,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanContent(double scale) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6 * scale),
          child: Image.asset(
            widget.foregroundAsset!,
            width: 40 * scale,
            height: 40 * scale,
          ),
        ),
        Text(
          widget.subtitle,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: _darkBrown,
            fontSize: 20 * scale,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _LegacyShinePainter extends CustomPainter {
  const _LegacyShinePainter({
    required this.progress,
    required this.rowWidth,
    required this.cardOffset,
  });

  final double progress;
  final double rowWidth;
  final double cardOffset;

  @override
  void paint(Canvas canvas, Size size) {
    // Every card paints a clipped segment of the same row-space highlight.
    // The center moves linearly across the complete row, so there is one band
    // and one constant speed even while it crosses the black card gaps.
    final bandWidth = rowWidth * .60;
    final layerSize = Size(bandWidth, size.height * 3);
    final layerRect = Rect.fromCenter(
      center: Offset.zero,
      width: layerSize.width,
      height: layerSize.height,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        // The gradient axis stays horizontal; rotating the 200% layer by 30°
        // makes the visible highlight itself diagonal. Combining the WXSS
        // gradient angle with the rotation produced a near-vertical stripe.
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [.25, .5, .75],
        colors: [Colors.transparent, Color(0x4DFFFFFF), Colors.transparent],
      ).createShader(layerRect);

    canvas.save();
    canvas.translate(-cardOffset, 0);
    final centerX = -bandWidth + (progress * (rowWidth + (bandWidth * 2)));
    canvas.translate(centerX, size.height / 2);
    canvas.rotate(.5235987756);
    canvas.drawRect(layerRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LegacyShinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.rowWidth != rowWidth ||
      oldDelegate.cardOffset != cardOffset;
}

enum _PromotionMode { poster, article, video }

class _PromotionGrid extends StatelessWidget {
  const _PromotionGrid({
    required this.onTap,
    required this.loading,
    required this.imageError,
    required this.mode,
    required this.onRecover,
  });

  final ValueChanged<String> onTap;
  final bool loading;
  final bool imageError;
  final _PromotionMode mode;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              if (mode == _PromotionMode.article)
                _ArticlePromotionCard(onTap: () => onTap('最帅小哥哥活动'))
              else if (mode == _PromotionMode.video)
                const _VideoPromotionCard()
              else
                _PosterCard(
                  asset: 'assets/legacy/home/mock_poster_handsome.png',
                  title: '谁是最帅小哥哥',
                  display: 'HANDSOME\nMAN',
                  tag: '投稿有奖',
                  loading: loading,
                  onTap: () => onTap('最帅小哥哥活动'),
                ),
              const SizedBox(height: 8),
              if (imageError)
                _PromotionImageError(title: '生日有礼', onRetry: onRecover)
              else
                _PosterCard(
                  asset: 'assets/legacy/home/mock_poster_birthday.png',
                  title: '生日有礼',
                  display: '解锁小姐姐哥哥特权',
                  palette: const Color(0xFFA82F61),
                  loading: loading,
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
                loading: loading,
                onTap: () => onTap('AI 卡颜局'),
              ),
              const SizedBox(height: 8),
              _PosterCard(
                asset: 'assets/legacy/home/mock_poster_music.png',
                title: '玩音乐能赚钱',
                display: 'PLAY MUSIC',
                loading: loading,
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
    this.loading = false,
  });

  final String asset;
  final String title;
  final String display;
  final String? tag;
  final Color palette;
  final VoidCallback onTap;
  final bool loading;

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
                if (loading)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticlePromotionCard extends StatelessWidget {
  const _ArticlePromotionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '图文内容，谁是最帅小哥哥，阿澈发布，128 次浏览',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF17130F),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: .82,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: Image.asset(
                    'assets/legacy/home/mock_poster_handsome.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '谁是最帅小哥哥',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Color(0xFF3A3026),
                          child: Text('阿', style: TextStyle(fontSize: 9)),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '阿澈',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Icon(Icons.visibility_outlined, size: 12),
                        SizedBox(width: 3),
                        Text('128', style: TextStyle(fontSize: 10)),
                      ],
                    ),
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

class _VideoPromotionCard extends StatefulWidget {
  const _VideoPromotionCard();

  @override
  State<_VideoPromotionCard> createState() => _VideoPromotionCardState();
}

class _VideoPromotionCardState extends State<_VideoPromotionCard> {
  bool _playing = false;
  bool _muted = true;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '视频内容，${_playing ? '正在播放' : '已暂停'}，${_muted ? '静音' : '有声'}',
      child: AspectRatio(
        aspectRatio: .72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/legacy/home/mock_poster_music.png',
                fit: BoxFit.cover,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Center(
                child: IconButton.filledTonal(
                  key: const ValueKey('home-video-toggle'),
                  tooltip: _playing ? '暂停' : '播放',
                  onPressed: () => setState(() => _playing = !_playing),
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Text(_playing ? '正在播放' : '默认暂停'),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: IconButton(
                  key: const ValueKey('home-video-sound'),
                  tooltip: _muted ? '开启声音' : '静音',
                  onPressed: () => setState(() => _muted = !_muted),
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionImageError extends StatelessWidget {
  const _PromotionImageError({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title 图片加载失败',
      child: AspectRatio(
        aspectRatio: .72,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF17130F),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0x557E6951)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_not_supported_outlined, color: _gold),
              const SizedBox(height: 8),
              Text(title),
              TextButton(onPressed: onRetry, child: const Text('查看文字详情')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPromotions extends StatelessWidget {
  const _EmptyPromotions({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-empty-promotions'),
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_outlined, size: 42, color: _gold),
          const SizedBox(height: 10),
          const Text('暂无运营内容'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRestore, child: const Text('恢复 Fake 内容')),
        ],
      ),
    );
  }
}

class _HomeStatusBanner extends StatelessWidget {
  const _HomeStatusBanner({
    required this.icon,
    required this.label,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        key: ValueKey('home-status-$label'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1611),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x667E6951)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _gold),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            if (busy) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
