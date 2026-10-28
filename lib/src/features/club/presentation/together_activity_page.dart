import 'package:flutter/material.dart';

import '../../commerce/presentation/store_home_page.dart';

import '../../../core/design_system/king_back_gesture.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_play_page.dart';
import 'together_removal_page.dart';
import 'together_activity_close.dart';
import 'together_seat_cards.dart';
import 'together_seat_picker.dart';
import '../data/secure_together_play_repository.dart';

import 'package:uuid/uuid.dart';

Future<void> openTogetherStore(
  BuildContext context, {
  required TogetherParty party,
  required TogetherPlayRepository repository,
  required Future<void> Function(TogetherParty) onJoin,
  required Future<void> Function(TogetherParty) onAdmission,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => StoreHomePage(
      storeRef: party.storeRef,
      initialBrandName: party.cardStoreName,
      initialBranchName: party.cardStoreSubtitle,
      onActivity: (storeContext, ref) async {
        final next = await repository.detail(ref);
        if (!storeContext.mounted) return;
        await Navigator.of(storeContext).push<void>(
          MaterialPageRoute(
            builder: (_) => TogetherActivityPage(
              party: next,
              repository: repository,
              onJoin: onJoin,
              onAdmission: onAdmission,
              onViewed: () {},
              initialReadComplete: true,
            ),
          ),
        );
      },
    ),
  ),
);

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
      party: party,
      repository: repository,
      onJoin: onJoin,
      onAdmission: onAdmission,
      onViewed: onViewed,
      onLoaded: onLoaded,
    ),
    transitionsBuilder: (_, _, _, child) => child,
  );
  await Navigator.of(context).push<void>(route);
  await route.completed;
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
    this.initialReadComplete = false,
  });
  final TogetherParty party;
  final TogetherPlayRepository repository;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  final VoidCallback onViewed;
  final ValueChanged<TogetherParty>? onLoaded;
  final Animation<double>? entranceAnimation;
  final bool initialReadComplete;
  @override
  State<TogetherActivityPage> createState() => _TogetherActivityPageState();
}

class _TogetherActivityPageState extends State<TogetherActivityPage> {
  final _cardBodyKey = GlobalKey();
  final _scroll = ScrollController();
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
    if (widget.initialReadComplete) {
      setState(() {
        _loaded = true;
        _loading = false;
        _marked = true;
      });
      widget.onViewed();
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
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

  Future<void> _requestSeatChange() async {
    final choice = await showTogetherSeatPicker(
      context,
      _party,
      changing: true,
    );
    if (choice == null || !mounted) return;
    final input = TextEditingController();
    String? reason;
    try {
      reason = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('填写调座原因'),
          content: TextField(
            controller: input,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '说明希望调整的原因，审批前保留原座位'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (input.text.trim().isNotEmpty) {
                  Navigator.pop(dialog, input.text.trim());
                }
              },
              child: const Text('提交申请'),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
    if (reason == null || !mounted) return;
    try {
      await (widget.repository as SecureTogetherPlayRepository)
          .requestSeatChange(_party.ref, choice, reason, const Uuid().v4());
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '调座申请未提交成功，请重试');
    }
  }

  Future<void> _reviewSeatChange(String ref, bool approve) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await (widget.repository as SecureTogetherPlayRepository)
          .reviewSeatChange(_party.ref, ref, approve);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '调座审核未成功，座位可能已变化，请刷新后重试');
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
    TogetherAvailableRow? sourceRow;
    void findRow(Element element) {
      if (element.widget is TogetherAvailableRow) {
        sourceRow = element.widget as TogetherAvailableRow;
        return;
      }
      element.visitChildren(findRow);
    }

    (source as Element).visitChildren(findRow);
    final sourceParty = sourceRow?.party ?? widget.party;
    if (sourceParty.cardLayout == 'compact') {
      return AnimatedBuilder(
        animation: animation,
        builder: (_, _) {
          final progress = Curves.easeInOut.transform(animation.value);
          return ClipRRect(
            borderRadius: BorderRadius.circular(22 * (1 - progress)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 1 - progress,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: TogetherAvailableRow(
                      party: sourceParty,
                      onTap: () {},
                      edgeInset: false,
                      showHeading: false,
                      showAction: true,
                      blurFooter: false,
                      actionLabel: sourceRow?.actionLabel ?? '查看',
                    ),
                  ),
                ),
                Opacity(
                  opacity: progress,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: TogetherAvailableRow(
                      party: sourceParty,
                      onTap: () {},
                      edgeInset: false,
                      showHeading: false,
                      expanded: true,
                      showAction: true,
                      blurFooter: false,
                      actionLabel: '加入',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    // Re-layout the small, cached card at the flight's actual width. Only its
    // poster grows; typography, footer height, avatars and controls keep their
    // logical size. No screenshot/FittedBox scales the entire composition.
    return AnimatedBuilder(
      animation: animation,
      child: IgnorePointer(
        child: TogetherAvailableRow(
          key: const ValueKey('together-card-flight-content'),
          party: sourceRow?.party ?? widget.party,
          onTap: () {},
          edgeInset: false,
          showHeading: false,
          expanded: true,
          showAction: true,
          blurFooter: false,
          actionLabel: sourceRow?.actionLabel ?? '加入',
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
        backgroundColor: const Color(0xFF1C1C1E),
        body: Stack(
          children: [
            ListView(
              controller: _scroll,
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
                      onStore: () => openTogetherStore(
                        context,
                        party: _party,
                        repository: widget.repository,
                        onJoin: widget.onJoin,
                        onAdmission: widget.onAdmission,
                      ),
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
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: TogetherStoreLogo(
                                  party: _party,
                                  size: 48,
                                ),
                                title: Text(_party.storeName),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => openTogetherStore(
                                  context,
                                  party: _party,
                                  repository: widget.repository,
                                  onJoin: widget.onJoin,
                                  onAdmission: widget.onAdmission,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_party.tables.isNotEmpty) ...[
                                const Text(
                                  '活动卡座',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TogetherSeatCards(party: _party),
                                if (_party.hasAdmissionTicket &&
                                    widget.repository
                                        is SecureTogetherPlayRepository)
                                  TextButton(
                                    onPressed: _party.seatChangePending
                                        ? null
                                        : _requestSeatChange,
                                    child: Text(
                                      _party.seatChangePending
                                          ? '调座申请审核中'
                                          : '申请调整座位',
                                    ),
                                  ),
                                if (widget.repository
                                    is SecureTogetherPlayRepository)
                                  for (final request in _party.seatRequests)
                                    Card(
                                      child: ListTile(
                                        title: Text(
                                          '${request['name'] ?? '会员'}申请调座',
                                        ),
                                        subtitle: Text(
                                          '${request['reason'] ?? ''}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: _acting
                                                  ? null
                                                  : () => _reviewSeatChange(
                                                      request['ref'] as String,
                                                      false,
                                                    ),
                                              child: const Text('拒绝'),
                                            ),
                                            TextButton(
                                              onPressed: _acting
                                                  ? null
                                                  : () => _reviewSeatChange(
                                                      request['ref'] as String,
                                                      true,
                                                    ),
                                              child: const Text('批准'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                const SizedBox(height: 20),
                              ],
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
                child: TogetherActivityClose(
                  source: _party.detailPosters.firstOrNull,
                  cardKey: _cardBodyKey,
                  scroll: _scroll,
                  motion: motion,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
