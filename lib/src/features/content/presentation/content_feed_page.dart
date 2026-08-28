import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_theme.dart';

enum ContentFeedDemoState {
  content,
  initialLoading,
  empty,
  initialError,
  refreshing,
  loadingMore,
  loadMoreError,
  buffering,
  mediaError,
  unavailable,
  authorUnavailable,
  posterOnly,
  sessionInvalid,
}

class ContentFeedPage extends StatefulWidget {
  const ContentFeedPage({
    super.key,
    required this.active,
    required this.onOpenAuthor,
    this.initialState = ContentFeedDemoState.initialLoading,
    this.onReturnHome,
    this.onSessionResetRequested,
  });

  final bool active;
  final ValueChanged<String> onOpenAuthor;
  final ContentFeedDemoState initialState;
  final VoidCallback? onReturnHome;
  final VoidCallback? onSessionResetRequested;

  @override
  State<ContentFeedPage> createState() => _ContentFeedPageState();
}

class _ContentFeedPageState extends State<ContentFeedPage>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  late ContentFeedDemoState _state;
  int _currentIndex = 0;
  bool _muted = true;
  bool _paused = true;
  bool _loadedOnce = false;

  static const _items = [
    _FakeContent(
      authorRef: 'social-target-neon',
      author: 'NEON 阿澈',
      initials: 'N',
      caption: '灯光落下前，先把今晚交给音乐。',
      tag: '#电音现场',
      location: '株洲 · KingClub',
      colors: [Color(0xFF2B202E), Color(0xFF6B304D), Color(0xFF111012)],
      icon: Icons.graphic_eq_rounded,
    ),
    _FakeContent(
      authorRef: 'social-target-table',
      author: '周末组局官',
      initials: '局',
      caption: '新朋友也能自然入场的一桌，今晚 21:30 见。',
      tag: '#周末组局',
      location: '株洲 · 神农城',
      colors: [Color(0xFF15282B), Color(0xFF335B56), Color(0xFF0E1212)],
      icon: Icons.celebration_outlined,
    ),
    _FakeContent(
      authorRef: 'social-target-dance',
      author: 'MIA',
      initials: 'M',
      caption: '城市入夜后的第一支舞，不必等到周末。',
      tag: '#夜生活方式',
      location: '株洲',
      colors: [Color(0xFF30251B), Color(0xFF745B36), Color(0xFF12100D)],
      icon: Icons.nightlife_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = widget.initialState;
    _loadedOnce = _state != ContentFeedDemoState.initialLoading;
    _paused = _state != ContentFeedDemoState.content || !widget.active;
    if (_state == ContentFeedDemoState.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    } else if (widget.active && !_loadedOnce) {
      unawaited(_loadFirst());
    }
  }

  @override
  void didUpdateWidget(covariant ContentFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      setState(() => _paused = true);
    } else if (!oldWidget.active && widget.active) {
      if (_loadedOnce) {
        setState(() => _paused = false);
      } else {
        unawaited(_loadFirst());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => _paused = true);
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _state = ContentFeedDemoState.initialLoading;
      _paused = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || !widget.active) return;
    setState(() {
      _loadedOnce = true;
      _state = ContentFeedDemoState.content;
      _paused = false;
    });
  }

  Future<void> _showSessionInvalid() async {
    _paused = true;
    _currentIndex = 0;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('content-feed-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('已停止播放并清除当前作品引用，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('content-feed-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  void _setScenario(ContentFeedDemoState value) {
    Navigator.pop(context);
    setState(() {
      _state = value;
      _paused = value != ContentFeedDemoState.content;
    });
    if (value == ContentFeedDemoState.sessionInvalid) {
      _showSessionInvalid();
    }
  }

  void _showScenarios() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KingColors.elevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('UI 测试场景', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '只切换离线 Fake 状态，不读取视频、位置或用户数据。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _scenarioChip('正常内容', ContentFeedDemoState.content),
                  _scenarioChip('首屏加载', ContentFeedDemoState.initialLoading),
                  _scenarioChip('空内容', ContentFeedDemoState.empty),
                  _scenarioChip('加载失败', ContentFeedDemoState.initialError),
                  _scenarioChip('刷新中', ContentFeedDemoState.refreshing),
                  _scenarioChip('加载更多', ContentFeedDemoState.loadingMore),
                  _scenarioChip('分页失败', ContentFeedDemoState.loadMoreError),
                  _scenarioChip('缓冲中', ContentFeedDemoState.buffering),
                  _scenarioChip('媒体失败', ContentFeedDemoState.mediaError),
                  _scenarioChip('内容下架', ContentFeedDemoState.unavailable),
                  _scenarioChip(
                    '作者不可见',
                    ContentFeedDemoState.authorUnavailable,
                  ),
                  _scenarioChip('低流量模式', ContentFeedDemoState.posterOnly),
                  _scenarioChip('会话失效', ContentFeedDemoState.sessionInvalid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scenarioChip(String label, ContentFeedDemoState state) {
    return ActionChip(label: Text(label), onPressed: () => _setScenario(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KingColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [_buildBody(), _topBar(context)],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!widget.active && !_loadedOnce) {
      return const _FeedCenteredState(
        icon: Icons.explore_outlined,
        title: '发现',
        message: '进入发现后加载离线示例内容',
      );
    }
    return switch (_state) {
      ContentFeedDemoState.initialLoading => const _FeedCenteredState(
        icon: Icons.play_circle_outline,
        title: '正在准备发现内容',
        message: '首次进入默认静音 · OFFLINE UI MOCK',
        busy: true,
      ),
      ContentFeedDemoState.empty => _FeedCenteredState(
        icon: Icons.video_library_outlined,
        title: '暂时没有新作品',
        message: '稍后再来看看，或返回首页浏览今晚活动。',
        actionLabel: '刷新 Fake 内容',
        onAction: _loadFirst,
        secondaryActionLabel: widget.onReturnHome == null ? null : '返回首页',
        onSecondaryAction: widget.onReturnHome,
      ),
      ContentFeedDemoState.initialError => _FeedCenteredState(
        icon: Icons.cloud_off_outlined,
        title: '内容加载失败',
        message: '当前内容没有丢失，可以安全重试。',
        actionLabel: '重新加载',
        onAction: _loadFirst,
      ),
      ContentFeedDemoState.sessionInvalid => const _FeedCenteredState(
        icon: Icons.lock_reset_outlined,
        title: '登录状态已失效',
        message: '作品引用已清除，当前没有媒体实例在播放。',
      ),
      _ => PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: (index) => setState(() {
          _currentIndex = index;
          _paused = !widget.active;
          if (_state != ContentFeedDemoState.posterOnly &&
              _state != ContentFeedDemoState.authorUnavailable) {
            _state = ContentFeedDemoState.content;
          }
        }),
        itemBuilder: (context, index) => _ContentCard(
          content: _items[index],
          active: widget.active && _currentIndex == index,
          muted: _muted,
          paused: _paused,
          state: _state,
          onTogglePlayback: () => setState(() => _paused = !_paused),
          onToggleMuted: () => setState(() => _muted = !_muted),
          onOpenAuthor: () => _openAuthor(_items[index].authorRef),
          onRetry: () => setState(() {
            _state = ContentFeedDemoState.content;
            _paused = false;
          }),
        ),
      ),
    };
  }

  void _openAuthor(String authorRef) {
    if (_state == ContentFeedDemoState.authorUnavailable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('作者资料暂不可见')));
      return;
    }
    widget.onOpenAuthor(authorRef);
  }

  Widget _topBar(BuildContext context) {
    return Positioned(
      left: 18,
      right: 18,
      top: 10,
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('content-feed-title'),
            onLongPress: _showScenarios,
            child: Text(
              '发现',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              '只读作品',
              style: TextStyle(fontSize: 11, color: KingColors.textSecondary),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.content,
    required this.active,
    required this.muted,
    required this.paused,
    required this.state,
    required this.onTogglePlayback,
    required this.onToggleMuted,
    required this.onOpenAuthor,
    required this.onRetry,
  });

  final _FakeContent content;
  final bool active;
  final bool muted;
  final bool paused;
  final ContentFeedDemoState state;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleMuted;
  final VoidCallback onOpenAuthor;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final unavailable = state == ContentFeedDemoState.unavailable;
    final mediaError = state == ContentFeedDemoState.mediaError;
    final buffering = state == ContentFeedDemoState.buffering;
    final posterOnly = state == ContentFeedDemoState.posterOnly;
    final refreshing = state == ContentFeedDemoState.refreshing;
    final loadingMore = state == ContentFeedDemoState.loadingMore;
    final loadMoreError = state == ContentFeedDemoState.loadMoreError;

    return Semantics(
      label: _semanticLabel(buffering, mediaError, unavailable, posterOnly),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unavailable || mediaError || posterOnly
            ? null
            : onTogglePlayback,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: content.colors,
                ),
              ),
            ),
            _PosterArtwork(content: content),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black87],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
            if (paused &&
                !unavailable &&
                !mediaError &&
                !buffering &&
                !posterOnly)
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 82,
                  color: Colors.white70,
                ),
              ),
            if (buffering)
              const _ContentOverlay(
                icon: Icons.hourglass_top_rounded,
                title: '正在缓冲',
                message: '保留封面，不切换到其他作品',
                busy: true,
              ),
            if (mediaError)
              _ContentOverlay(
                icon: Icons.broken_image_outlined,
                title: '当前作品播放失败',
                message: '只重试这一条，不重置整个内容流',
                actionLabel: '重试当前作品',
                onAction: onRetry,
              ),
            if (unavailable)
              _ContentOverlay(
                icon: Icons.visibility_off_outlined,
                title: '内容暂不可用',
                message: '作品已下架或当前不可见，不会从缓存继续播放',
                actionLabel: '查看下一条',
                onAction: onRetry,
              ),
            if (posterOnly)
              const Positioned(
                left: 18,
                top: 76,
                child: _ModePill(
                  icon: Icons.data_saver_on_outlined,
                  label: '低流量 · 封面模式',
                ),
              ),
            if (refreshing)
              const Positioned(
                left: 18,
                right: 18,
                top: 76,
                child: _FeedStatusBanner(
                  icon: Icons.refresh_rounded,
                  label: '正在刷新，当前作品已暂停',
                  busy: true,
                ),
              ),
            if (loadingMore)
              const Positioned(
                left: 18,
                right: 18,
                top: 76,
                child: _FeedStatusBanner(
                  icon: Icons.expand_more_rounded,
                  label: '正在加载更多作品',
                  busy: true,
                ),
              ),
            if (loadMoreError)
              Positioned(
                left: 18,
                right: 18,
                top: 76,
                child: _FeedStatusBanner(
                  icon: Icons.sync_problem_outlined,
                  label: '更多作品加载失败，当前作品仍可浏览',
                  actionLabel: '重试',
                  onAction: onRetry,
                ),
              ),
            Positioned(
              left: 20,
              right: 18,
              // The shell deliberately draws its floating legacy navigation
              // over the body. Keep every feed action above that 64dp bar,
              // its 14dp safe-area margin, and the visual breathing room.
              bottom: 100,
              child: _ContentDetails(
                content: content,
                muted: muted,
                paused: paused || !active || posterOnly,
                posterOnly: posterOnly,
                onToggleMuted: onToggleMuted,
                onOpenAuthor: onOpenAuthor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _semanticLabel(
    bool buffering,
    bool mediaError,
    bool unavailable,
    bool posterOnly,
  ) {
    final playback = unavailable
        ? '内容不可用'
        : mediaError
        ? '播放失败'
        : buffering
        ? '正在缓冲'
        : posterOnly
        ? '封面模式，未播放'
        : state == ContentFeedDemoState.refreshing
        ? '正在刷新，已暂停'
        : state == ContentFeedDemoState.loadingMore
        ? '正在加载更多'
        : state == ContentFeedDemoState.loadMoreError
        ? '更多内容加载失败'
        : paused || !active
        ? '已暂停'
        : '正在播放';
    return '${content.author}的作品，$playback，${muted ? '静音' : '有声'}';
  }
}

class _PosterArtwork extends StatelessWidget {
  const _PosterArtwork({required this.content});

  final _FakeContent content;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 126,
          left: -42,
          child: Transform.rotate(
            angle: -0.18,
            child: Container(
              width: 290,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(52),
              ),
            ),
          ),
        ),
        Positioned(
          right: -56,
          bottom: 198,
          child: Container(
            width: 260,
            height: 310,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.19),
              borderRadius: BorderRadius.circular(90),
            ),
          ),
        ),
        Center(
          child: Icon(
            content.icon,
            size: 168,
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        const Positioned(
          right: 18,
          top: 78,
          child: _ModePill(icon: Icons.auto_awesome, label: '合成示例内容'),
        ),
      ],
    );
  }
}

class _ContentDetails extends StatelessWidget {
  const _ContentDetails({
    required this.content,
    required this.muted,
    required this.paused,
    required this.posterOnly,
    required this.onToggleMuted,
    required this.onOpenAuthor,
  });

  final _FakeContent content;
  final bool muted;
  final bool paused;
  final bool posterOnly;
  final VoidCallback onToggleMuted;
  final VoidCallback onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onOpenAuthor,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: KingColors.brand,
                        foregroundColor: KingColors.onBrand,
                        child: Text(
                          content.initials,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          content.author,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${content.tag}  ·  ${content.location}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: KingColors.brandStrong),
              ),
              const SizedBox(height: 6),
              Text(
                posterOnly
                    ? '封面模式'
                    : paused
                    ? '已暂停'
                    : '正在播放',
                style: const TextStyle(
                  color: KingColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: muted ? '当前静音，点击开启声音' : '当前有声，点击静音',
          child: FilledButton.tonalIcon(
            onPressed: posterOnly ? null : onToggleMuted,
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
            label: Text(muted ? '静音' : '有声'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: Colors.black54,
              foregroundColor: KingColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContentOverlay extends StatelessWidget {
  const _ContentOverlay({
    required this.icon,
    required this.title,
    required this.message,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: KingColors.brandStrong),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (busy) ...[
                const SizedBox(height: 18),
                const SizedBox(width: 120, child: LinearProgressIndicator()),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCenteredState extends StatelessWidget {
  const _FeedCenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.busy = false,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 68, color: KingColors.brandStrong),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (busy) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (secondaryActionLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedStatusBanner extends StatelessWidget {
  const _FeedStatusBanner({
    required this.icon,
    required this.label,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: KingColors.brandStrong),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: KingColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: KingColors.brandStrong),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: KingColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeContent {
  const _FakeContent({
    required this.authorRef,
    required this.author,
    required this.initials,
    required this.caption,
    required this.tag,
    required this.location,
    required this.colors,
    required this.icon,
  });

  final String authorRef;
  final String author;
  final String initials;
  final String caption;
  final String tag;
  final String location;
  final List<Color> colors;
  final IconData icon;
}
