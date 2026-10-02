import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/media/cached_media_video.dart';
import '../data/home_content_repository.dart';
import 'legacy_home_image.dart';
import 'home_city_page.dart';

String homeLocale(BuildContext context) {
  final l = Localizations.localeOf(context);
  return l.languageCode == 'th'
      ? 'th'
      : l.languageCode == 'en'
      ? 'en'
      : l.scriptCode == 'Hant' || {'TW', 'HK', 'MO'}.contains(l.countryCode)
      ? 'zh-TW'
      : 'zh-CN';
}

class HomeContentImage extends StatelessWidget {
  const HomeContentImage({
    super.key,
    required this.content,
    this.fit = BoxFit.cover,
  });
  final HomeContent content;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => content.cover.startsWith('assets/')
      ? LegacyHomeImage(content.cover, fit: fit)
      : CachedMediaImage(
          content.cover,
          contentKey: '${content.cacheKey}/cover',
          fit: fit,
          private: false,
          placeholder: const ColoredBox(color: Color(0xFF202020)),
        );
}

// The mini-program expands the tapped image in 300ms, while its content
// sheet rises over 700ms. Interpolate every edge directly, without a Hero arc.
class HomeContentRectTween extends RectTween {
  HomeContentRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) => Rect.lerp(
    begin,
    end,
    const Interval(0, 300 / 700, curve: Curves.ease).transform(t),
  );
}

RectTween _contentRectTween(Rect? begin, Rect? end) =>
    HomeContentRectTween(begin: begin, end: end);

class HomeContentMasonry extends StatelessWidget {
  const HomeContentMasonry({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onLike,
  });
  final List<HomeContent> items;
  final ValueChanged<HomeContent> onOpen;
  final Future<void> Function(HomeContent) onLike;
  static const captionStyle = TextStyle(
    color: Color(0xFFEEEEEE),
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = (box.maxWidth - 6) / 2;
      final columns = [<HomeContent>[], <HomeContent>[]], heights = [0.0, 0.0];
      for (final item in items) {
        final title = item.copy(item.titles, homeLocale(context));
        final text = TextPainter(
          text: TextSpan(text: title, style: captionStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(maxWidth: width - 20);
        final height =
            width / item.ratio + (item.mode == 'poster' ? 0 : text.height + 58);
        final index = heights[0] <= heights[1] ? 0 : 1;
        columns[index].add(item);
        heights[index] += height + 6;
      }
      return Row(
        key: const ValueKey('home-content-masonry'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in [0, 1]) ...[
            if (column == 1) const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  for (final item in columns[column])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ContentCard(
                        content: item,
                        onOpen: () => onOpen(item),
                        onLike: () => onLike(item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.content,
    required this.onOpen,
    required this.onLike,
  });
  final HomeContent content;
  final VoidCallback onOpen;
  final Future<void> Function() onLike;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: content.copy(content.titles, homeLocale(context)),
    child: Material(
      color: const Color(0xFF242424),
      borderRadius: BorderRadius.circular(5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('home-card-${content.ref}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'home-content-${content.ref}',
              createRectTween: _contentRectTween,
              flightShuttleBuilder: (context, animation, direction, from, to) =>
                  HomeContentImage(content: content),
              transitionOnUserGestures: true,
              child: AspectRatio(
                aspectRatio: content.ratio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HomeContentImage(content: content),
                    if (content.mode == 'video')
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (content.mode != 'poster')
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.copy(content.titles, homeLocale(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeContentMasonry.captionStyle,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (content.author != null &&
                            content.author!.isNotEmpty) ...[
                          ClipOval(
                            child: content.avatar == null
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                      size: 18,
                                    ),
                                  )
                                : CachedMediaImage(
                                    content.avatar!,
                                    width: 20,
                                    height: 20,
                                    contentKey: '${content.cacheKey}/author',
                                    private: false,
                                  ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              content.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        HomeLikeButton(content: content, onTap: onLike),
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

class HomeLikeButton extends StatefulWidget {
  const HomeLikeButton({super.key, required this.content, required this.onTap});
  final HomeContent content;
  final Future<void> Function() onTap;
  @override
  State<HomeLikeButton> createState() => _HomeLikeButtonState();
}

class _HomeLikeButtonState extends State<HomeLikeButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('home-like-${widget.content.ref}'),
    onTap: _busy
        ? null
        : () async {
            setState(() => _busy = true);
            try {
              await widget.onTap();
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.content.liked ? Icons.favorite : Icons.favorite_border,
            size: 17,
            color: widget.content.liked
                ? const Color(0xFFFA5151)
                : const Color(0xFF999999),
          ),
          const SizedBox(width: 3),
          Text(
            '${widget.content.likeCount}',
            style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

Future<void> openHomeContent(
  BuildContext context,
  HomeContent content,
  Future<void> Function(HomeContent) onLike,
) => Navigator.of(context).push<void>(
  PageRouteBuilder(
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700),
    reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700),
    pageBuilder: (context, animation, secondary) => HomeContentDetailPage(
      content: content,
      onLike: () => onLike(content),
      animation: animation,
    ),
    transitionsBuilder: (context, animation, secondary, child) => child,
  ),
);

class HomeContentDetailPage extends StatefulWidget {
  const HomeContentDetailPage({
    super.key,
    required this.content,
    required this.onLike,
    required this.animation,
  });
  final HomeContent content;
  final Future<void> Function() onLike;
  final Animation<double> animation;
  @override
  State<HomeContentDetailPage> createState() => _HomeContentDetailPageState();
}

class _HomeContentDetailPageState extends State<HomeContentDetailPage>
    with WidgetsBindingObserver {
  Timer? _playTimer;
  bool _playing = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.content.video != null) {
      _playTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _playing = true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: widget.animation,
              child: const ColoredBox(color: Color(0xFF101010)),
            ),
          ),
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Hero(
                tag: 'home-content-${content.ref}',
                createRectTween: _contentRectTween,
                flightShuttleBuilder: (
                  context,
                  animation,
                  direction,
                  from,
                  to,
                ) => HomeContentImage(content: content),
                child: AspectRatio(
                  aspectRatio: content.ratio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      HomeContentImage(content: content),
                      if (content.video != null && _playing)
                        CachedMediaVideo(
                          url: content.video!,
                          scope: 'public',
                          contentKey: '${content.cacheKey}/video',
                          active: _foreground && _playing,
                          muted: false,
                        ),
                      if (content.video != null)
                        Align(
                          alignment: Alignment.topRight,
                          child: SafeArea(
                            child: IconButton.filledTonal(
                              tooltip: homeCopy(
                                context,
                                _playing ? '暂停' : '播放',
                                _playing ? 'Pause' : 'Play',
                                _playing ? '暫停' : '播放',
                                _playing ? 'หยุด' : 'เล่น',
                              ),
                              onPressed: () =>
                                  setState(() => _playing = !_playing),
                              icon: Icon(
                                _playing ? Icons.pause : Icons.play_arrow,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: widget.animation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    MediaQuery.sizeOf(context).height *
                        (1 - Curves.ease.transform(widget.animation.value)),
                  ),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.copy(content.titles, homeLocale(context)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (content.author != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          content.author!,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                      if (content
                          .copy(content.descriptions, homeLocale(context))
                          .isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          content.copy(
                            content.descriptions,
                            homeLocale(context),
                          ),
                          style: const TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      ],
                      if (content.placement == 'card') ...[
                        const SizedBox(height: 20),
                        HomeLikeButton(content: content, onTap: widget.onLike),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: FadeTransition(
              opacity: widget.animation.drive(
                CurveTween(curve: const Interval(300 / 700, 1)),
              ),
              child: IconButton.filledTonal(
                tooltip: homeCopy(context, '关闭', 'Close', '關閉', 'ปิด'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
