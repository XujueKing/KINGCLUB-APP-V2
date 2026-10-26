import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/design_system/king_back_gesture.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_play_page.dart';
import 'together_removal_page.dart';

String togetherActivityHeroTag(String ref) => 'together-activity-$ref';

// Match the home card's direct rectangle path and easing, without flying
// the destination page, its list, or its network-backed image widgets.
class TogetherActivityRectTween extends RectTween {
  TogetherActivityRectTween({super.begin, super.end});
  @override
  Rect? lerp(double t) => Rect.lerp(begin, end, Curves.ease.transform(t));
}

RectTween togetherActivityRectTween(Rect? begin, Rect? end) =>
    TogetherActivityRectTween(begin: begin, end: end);

Widget togetherActivityPlaceholder(
  BuildContext context,
  Size size,
  Widget child,
) => SizedBox.fromSize(
  size: size,
  child: Offstage(child: TickerMode(enabled: false, child: child)),
);

Future<void> openTogetherActivity(
  BuildContext context, {
  ui.Image? previewImage,
  required TogetherParty party,
  required TogetherPlayRepository repository,
  required Future<void> Function(TogetherParty) onJoin,
  required Future<void> Function(TogetherParty) onAdmission,
  required VoidCallback onViewed,
  ValueChanged<TogetherParty>? onLoaded,
}) async {
  final route = PageRouteBuilder<void>(
    barrierColor: Colors.transparent,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    pageBuilder: (_, animation, _) => TogetherActivityPage(
      entranceAnimation: animation,
      previewImage: previewImage,
      party: party,
      repository: repository,
      onJoin: onJoin,
      onAdmission: onAdmission,
      onViewed: onViewed,
      onLoaded: onLoaded,
    ),
    transitionsBuilder: (_, _, _, child) => child,
  );
  try {
    await Navigator.of(context).push<void>(route);
    await route.completed;
  } finally {
    previewImage?.dispose();
  }
}

class TogetherActivityPage extends StatefulWidget {
  const TogetherActivityPage({
    super.key,
    required this.party,
    required this.repository,
    required this.onJoin,
    required this.onAdmission,
    required this.onViewed,
    this.onLoaded,
    this.entranceAnimation,
    this.previewImage,
  });
  final TogetherParty party;
  final TogetherPlayRepository repository;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  final VoidCallback onViewed;
  final ValueChanged<TogetherParty>? onLoaded;
  final Animation<double>? entranceAnimation;
  final ui.Image? previewImage;
  @override
  State<TogetherActivityPage> createState() => _TogetherActivityPageState();
}

class _TogetherActivityPageState extends State<TogetherActivityPage> {
  final _cardBodyKey = GlobalKey();
  late TogetherParty _party = widget.party;
  bool _loading = true, _loaded = false, _acting = false, _marked = false;
  bool _started = false;
  Animation<double>? _routeAnimation;
  String? _error;
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _routeAnimation != null) return;
    _routeAnimation =
        widget.entranceAnimation ?? ModalRoute.of(context)?.animation;
    _routeAnimation?.addStatusListener(_transitionChanged);
    if (_routeAnimation == null || _routeAnimation!.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoad());
    }
  }

  void _transitionChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _startLoad();
  }

  void _startLoad() {
    if (_started || !mounted) return;
    if (_routeAnimation != null && !_routeAnimation!.isCompleted) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_transitionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.repository.detail(widget.party.ref);
      if (value.ref != widget.party.ref) throw StateError('Activity mismatch');
      if (!mounted) return;
      setState(() {
        _party = value;
        _loaded = true;
      });
      widget.onLoaded?.call(value);
      if (!_marked) {
        _marked = true;
        widget.onViewed();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法加载活动详情');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    if (_acting ||
        !_loaded ||
        _loading ||
        !_party.canAct ||
        _party.hasAdmissionTicket) {
      return;
    }
    setState(() => _acting = true);
    try {
      await widget.onJoin(_party);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法打开购买页面，请重试');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _cardFlight(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final source = direction == HeroFlightDirection.push ? from : to;
    final image = widget.previewImage;
    return AnimatedBuilder(
      animation: animation,
      child: image != null
          ? RawImage(
              key: const ValueKey('together-card-flight-image'),
              image: image,
              fit: BoxFit.fill,
            )
          : FittedBox(
              fit: BoxFit.fill,
              child: SizedBox.fromSize(
                size: source.size,
                child: TogetherAvailableRow(
                  party: widget.party,
                  onTap: () {},
                  edgeInset: false,
                  showHeading: false,
                  showAction: true,
                  blurFooter: false,
                ),
              ),
            ),
      builder: (_, child) => ClipRRect(
        borderRadius: BorderRadius.circular(22 * (1 - animation.value)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motion =
        widget.entranceAnimation ?? const AlwaysStoppedAnimation(1.0);
    final contentOpacity = CurveTween(
      curve: const Interval(.5, 1, curve: Curves.easeOut),
    ).animate(motion);
    return KingEdgeBackGesture(
      onBack: () => Navigator.maybePop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: motion,
                child: const ColoredBox(color: Color(0xFF1C1C1E)),
              ),
            ),
            ListView(
              key: const ValueKey('together-expanded-scroll'),
              padding: EdgeInsets.zero,
              children: [
                Hero(
                  tag: togetherActivityHeroTag(_party.ref),
                  curve: Curves.linear,
                  reverseCurve: Curves.linear,
                  createRectTween: togetherActivityRectTween,
                  transitionOnUserGestures: true,
                  flightShuttleBuilder: _cardFlight,
                  placeholderBuilder: togetherActivityPlaceholder,
                  child: RepaintBoundary(
                    key: _cardBodyKey,
                    child: TogetherAvailableRow(
                      party: _party,
                      onTap: () {},
                      edgeInset: false,
                      showHeading: false,
                      expanded: true,
                      showAction: true,
                      blurFooter: false,
                      actionLabel: '加入',
                      onAction:
                          _loaded &&
                              !_loading &&
                              !_acting &&
                              _party.canAct &&
                              !_party.hasAdmissionTicket
                          ? _join
                          : null,
                    ),
                  ),
                ),
                if (_started)
                  FadeTransition(
                    opacity: contentOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          TextButton(
                            onPressed: _load,
                            child: Text('$_error · 重试'),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.repository
                                  is TogetherRemovalRepository)
                                TextButton(
                                  onPressed: () async {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => TogetherRemovalPage(
                                          partyRef: _party.ref,
                                          repository:
                                              widget.repository
                                                  as TogetherRemovalRepository,
                                        ),
                                      ),
                                    );
                                    if (mounted) await _load();
                                  },
                                  child: const Text('查看本场参加者'),
                                ),
                              Text(
                                _party.description,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 16,
                                  height: 1.8,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                '${togetherTimeRange(_party)}\n${_party.storeName}\n${_party.place}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 15,
                                  height: 1.8,
                                ),
                              ),
                              if (_party.hasAdmissionTicket)
                                TextButton(
                                  onPressed: () => widget.onAdmission(_party),
                                  child: const Text('查看已有入场券'),
                                ),
                              if (_party.eligibilityReasons.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Text(
                                    _party.eligibilityReasons.join('\n'),
                                    style: const TextStyle(
                                      color: legacyPink,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 26),
                              const Text(
                                '参加须知',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _party.rules.isEmpty
                                    ? '请按时到场，文明参与。购买前请核对本场费用和参加要求。'
                                    : _party.rules,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 15,
                                  height: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 16,
              child: FadeTransition(
                opacity: contentOpacity,
                child: IconButton(
                  key: const ValueKey('together-close-detail'),
                  tooltip: '关闭活动详情',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x66333333),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close, size: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
