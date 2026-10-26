import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/design_system/king_back_gesture.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_play_page.dart';
import 'together_removal_page.dart';

Future<void> openTogetherActivity(
  BuildContext context, {
  required Rect origin,
  required TogetherParty party,
  required TogetherPlayRepository repository,
  required Future<void> Function(TogetherParty) onJoin,
  required Future<void> Function(TogetherParty) onAdmission,
  required VoidCallback onViewed,
  ValueChanged<TogetherParty>? onLoaded,
}) => Navigator.of(context).push<void>(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 420),
    reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360),
    pageBuilder: (_, animation, _) => TogetherActivityPage(
      entranceAnimation: animation,
      party: party,
      repository: repository,
      onJoin: onJoin,
      onAdmission: onAdmission,
      onViewed: onViewed,
      onLoaded: onLoaded,
    ),
    transitionsBuilder: (context, animation, secondary, child) => LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final size = constraints.biggest;
          final t = Curves.easeOutCubic.transform(animation.value);
          final rect = Rect.lerp(origin, Offset.zero & size, t)!;
          final scale = rect.width / size.width;
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: t)),
              ),
              Positioned.fromRect(
                rect: rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(lerpDouble(22, 0, t)!),
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: size.width,
                    maxWidth: size.width,
                    minHeight: size.height,
                    maxHeight: size.height,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: SizedBox.fromSize(
                        size: size,
                        child: RepaintBoundary(child: child!),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);

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
  });
  final TogetherParty party;
  final TogetherPlayRepository repository;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  final VoidCallback onViewed;
  final ValueChanged<TogetherParty>? onLoaded;
  final Animation<double>? entranceAnimation;
  @override
  State<TogetherActivityPage> createState() => _TogetherActivityPageState();
}

class _TogetherActivityPageState extends State<TogetherActivityPage> {
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

  @override
  Widget build(BuildContext context) => KingEdgeBackGesture(
    onBack: () => Navigator.maybePop(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          ListView(
            key: const ValueKey('together-expanded-scroll'),
            padding: EdgeInsets.zero,
            children: [
              TogetherAvailableRow(
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
              if (_error != null)
                TextButton(onPressed: _load, child: Text('$_error · 重试')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.repository is TogetherRemovalRepository)
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
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
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
        ],
      ),
    ),
  );
}
