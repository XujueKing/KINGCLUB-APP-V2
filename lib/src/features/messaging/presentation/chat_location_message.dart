import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_notice.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_location.dart';
import '../data/chat_current_position.dart';
import '../data/chat_media_deletion.dart';
import '../data/chat_saved_locations.dart';

class ChatLocationMessage extends StatelessWidget {
  const ChatLocationMessage({
    super.key,
    required this.location,
    required this.mine,
    required this.onTap,
  });
  final ChatLocation location;
  final bool mine;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '查看位置：${location.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine ? 7 : 0),
            topRight: Radius.circular(mine ? 0 : 7),
            bottomLeft: const Radius.circular(7),
            bottomRight: const Radius.circular(7),
          ),
          child: SizedBox(
            width: 250,
            child: ColoredBox(
              color: const Color(0xFF2C2C2C),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (location.address.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            location.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF929292),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _LocationMapPreview(location: location),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationMapPreview extends StatefulWidget {
  const _LocationMapPreview({required this.location});
  final ChatLocation location;
  @override
  State<_LocationMapPreview> createState() => _LocationMapPreviewState();
}

class _LocationMapPreviewState extends State<_LocationMapPreview> {
  static const _maps = MethodChannel('kingclub/chat-map-preview');
  late Future<Uint8List?> _image;

  Future<Uint8List?> _load() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        widget.location.coordinateSystem != 'wgs84') {
      return null;
    }
    try {
      // The map provider needs coordinates only, never message or member data.
      return await _maps
          .invokeMethod<Uint8List>('snapshot', {
            'latitudeE6': widget.location.latitudeE6,
            'longitudeE6': widget.location.longitudeE6,
            'coordinateSystem': widget.location.coordinateSystem,
          })
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  @override
  void didUpdateWidget(covariant _LocationMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.location.sameAs(widget.location)) _image = _load();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96,
    child: ColoredBox(
      color: const Color(0xFF222627),
      child: FutureBuilder<Uint8List?>(
        future: _image,
        builder: (context, snapshot) => Stack(
          fit: StackFit.expand,
          children: [
            if (snapshot.data != null)
              Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            const Center(
              child: Icon(
                Icons.location_on,
                size: 42,
                color: Color(0xFF07C160),
              ),
            ),
            if (snapshot.data != null)
              const Positioned(
                right: 5,
                bottom: 4,
                child: Text(
                  'Apple Maps',
                  style: TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ),
            if (snapshot.data == null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Text(
                  snapshot.connectionState == ConnectionState.done
                      ? '点击查看位置'
                      : '地图加载中',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF929292),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class ChatLocationDetailsPage extends StatefulWidget {
  const ChatLocationDetailsPage({
    super.key,
    required this.location,
    this.source,
  });
  final ChatLocation location;
  final ChatMediaDeletion? source;
  @override
  State<ChatLocationDetailsPage> createState() =>
      _ChatLocationDetailsPageState();
}

class _ChatLocationDetailsPageState extends State<ChatLocationDetailsPage> {
  static const _maps = MethodChannel('kingclub/chat-map');
  StreamSubscription<void>? _session;
  void Function()? _removeDeletionListener;
  bool _deleted = false;
  bool _valid = true;
  bool _openingMap = false;
  MethodChannel? _mapView;
  Timer? _mapTimeout;
  String _mapStatus = 'loading';
  int _mapGeneration = 0;
  ChatSavedLocations? _bookmarks;
  List<ChatLocation> _saved = [];
  bool _saving = false;
  bool _locating = false;
  double? _distance;
  bool get _nativeMap =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      widget.location.coordinateSystem == 'wgs84';
  bool get _isSaved => _saved.any((p) => p.sameAs(widget.location));

  void _mapState(String? state, int generation) {
    if (!mounted || !_valid || generation != _mapGeneration) return;
    if (state != 'ready' && state != 'failed') return;
    _mapTimeout?.cancel();
    setState(() => _mapStatus = state!);
  }

  Future<void> _attachMap(int id) async {
    final generation = _mapGeneration;
    final channel = MethodChannel('kingclub/location-map/$id');
    _mapView = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'status') {
        _mapState(call.arguments as String?, generation);
      }
    });
    _mapTimeout?.cancel();
    _mapTimeout = Timer(
      const Duration(seconds: 15),
      () => _mapState('failed', generation),
    );
    try {
      _mapState(await channel.invokeMethod<String>('status'), generation);
    } catch (_) {
      _mapState('failed', generation);
    }
  }

  void _retryMap() {
    if (!_valid) return;
    _mapView?.setMethodCallHandler(null);
    _mapView = null;
    _mapTimeout?.cancel();
    setState(() {
      _mapGeneration++;
      _mapStatus = 'loading';
    });
  }

  Future<void> _loadBookmarks() async {
    try {
      final session = await SecureSessionStore().readSession();
      final account = (session?['account'] as Map?)?['userAccount'];
      if (account is! String || account.isEmpty) return;
      final store = ChatSavedLocations(account);
      final saved = await store.read();
      if (!mounted || !_valid) return;
      setState(() {
        _bookmarks = store;
        _saved = saved;
      });
    } catch (_) {
      /* A storage failure must not prevent viewing a location. */
    }
  }

  Future<void> _toggleSaved() async {
    if (!_valid || _saving) return;
    final store = _bookmarks;
    if (store == null) {
      KingNotice.of(context).show('收藏暂不可用，请重新进入');
      return;
    }
    setState(() => _saving = true);
    try {
      final next = _isSaved
          ? _saved.where((p) => !p.sameAs(widget.location)).toList()
          : [..._saved, widget.location];
      await store.save(next);
      if (!mounted || !_valid) return;
      setState(() => _saved = next);
      KingNotice.of(context).show(_isSaved ? '已收藏到本机' : '已取消收藏');
    } catch (_) {
      if (mounted && _valid) {
        KingNotice.of(context).show('收藏失败，请稍后重试（最多200个地点）');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _locate() async {
    if (!_valid || _locating) return;
    setState(() => _locating = true);
    try {
      final position = await const ChatCurrentPosition().current();
      if (!mounted || !_valid) return;
      if (widget.location.coordinateSystem == 'wgs84') {
        setState(
          () => _distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            widget.location.latitudeE6 / 1e6,
            widget.location.longitudeE6 / 1e6,
          ),
        );
        await _mapView?.invokeMethod('locate', {
          'latitudeE6': (position.latitude * 1e6).round(),
          'longitudeE6': (position.longitude * 1e6).round(),
          'coordinateSystem': 'wgs84',
        });
      }
    } catch (error) {
      if (mounted && _valid) {
        KingNotice.of(context).show(
          error is StateError
              ? error.message.toString()
              : '无法获取当前位置，请检查定位权限和定位服务',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _copy() async {
    if (!_valid) return;
    final p = widget.location;
    await Clipboard.setData(
      ClipboardData(
        text:
            '${p.name}\n${p.address}\n${p.latitudeE6 / 1e6}, ${p.longitudeE6 / 1e6} (${p.coordinateSystem})',
      ),
    );
    if (mounted && _valid) KingNotice.of(context).show('地点信息已复制');
  }

  Future<void> _more() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF292929),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in {
              'copy': '复制地点信息',
              if (_nativeMap) 'walk': '步行导航',
              if (_nativeMap) 'target': '回到目的地',
              if (_nativeMap) 'permissions': '定位权限设置',
              'saved': '已收藏的地点（本机）',
            }.entries)
              ListTile(
                title: Text(item.value),
                onTap: () => Navigator.pop(context, item.key),
              ),
          ],
        ),
      ),
    );
    if (!mounted || !_valid) return;
    if (action == 'copy') {
      await _copy();
      return;
    }
    if (action == 'target') {
      try {
        await _mapView?.invokeMethod('target');
      } catch (_) {
        if (mounted && _valid) KingNotice.of(context).show('地图暂不可用，请重试');
      }
      return;
    }
    if (action == 'walk') {
      await _openMap(mode: 'walking');
      return;
    }
    if (action == 'permissions') {
      await Geolocator.openAppSettings();
      return;
    }
    if (action == 'saved') {
      final chosen = await showModalBottomSheet<ChatLocation>(
        context: context,
        backgroundColor: const Color(0xFF292929),
        builder: (context) => SafeArea(
          child: _saved.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('暂无收藏地点'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final place in _saved)
                      ListTile(
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        onTap: () => Navigator.pop(context, place),
                      ),
                  ],
                ),
        ),
      );
      if (chosen != null && mounted && _valid) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatLocationDetailsPage(location: chosen),
          ),
        );
        if (mounted && _valid) await _loadBookmarks();
      }
    }
  }

  Future<void> _openMap({String? mode}) async {
    if (!_valid || _openingMap) return;
    setState(() => _openingMap = true);
    try {
      final data = widget.location.toJson()..remove('address');
      if (mode != null) data['mode'] = mode;
      final opened = await _maps
          .invokeMethod<bool>('open', data)
          .timeout(const Duration(seconds: 10));
      if (opened != true) throw StateError('Map unavailable');
    } catch (_) {
      if (mounted && _valid) {
        KingNotice.of(context).show('无法打开地图，可以复制地点信息');
      }
    } finally {
      if (mounted) setState(() => _openingMap = false);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadBookmarks());
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) _invalidate(false);
    });
    _removeDeletionListener = ChatMediaDeletion.listen((event) {
      final source = widget.source;
      if (!mounted ||
          source == null ||
          event.account != source.account ||
          event.group != source.group ||
          event.messageId != source.messageId) {
        return;
      }
      _invalidate(true);
    });
  }

  void _invalidate(bool deleted) {
    _mapTimeout?.cancel();
    _mapView?.setMethodCallHandler(null);
    final route = ModalRoute.of(context);
    if (route != null && route.isActive && !route.isCurrent) {
      Navigator.of(context)
          .popUntil((candidate) => identical(candidate, route));
    }
    setState(() {
      _deleted = deleted;
      _valid = false;
      _saved = [];
      _bookmarks = null;
    });
  }

  @override
  void dispose() {
    _mapTimeout?.cancel();
    _mapView?.setMethodCallHandler(null);
    _session?.cancel();
    _removeDeletionListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    return Scaffold(
      backgroundColor: const Color(0xFF202324),
      body: !_valid
          ? SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KingBackButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(_deleted ? '内容已移除' : '登录状态已变化，请重新进入'),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_nativeMap)
                        UiKitView(
                          key: ValueKey(_mapGeneration),
                          viewType: 'kingclub/location-map',
                          creationParams: location.toJson(),
                          creationParamsCodec: const StandardMessageCodec(),
                          gestureRecognizers: {
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                          onPlatformViewCreated: _attachMap,
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 56,
                                color: Color(0xFF07C160),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                location.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              TextButton(
                                onPressed: _openMap,
                                child: const Text('打开地图查看位置'),
                              ),
                            ],
                          ),
                        ),
                      if (_nativeMap && _mapStatus != 'ready')
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 64,
                          left: 20,
                          right: 20,
                          child: Material(
                            color: const Color(0xEE303030),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _mapStatus == 'failed'
                                          ? '地图暂未加载，可重试或直接导航'
                                          : '正在加载地图',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (_mapStatus == 'failed')
                                    TextButton(
                                      onPressed: _retryMap,
                                      child: const Text('重试'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 8,
                        child: IconButton.filled(
                          tooltip: '返回',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE8E8E8),
                            foregroundColor: const Color(0xFF252525),
                          ),
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      if (_nativeMap)
                        Positioned(
                          left: 16,
                          bottom: 28,
                          child: IconButton.filled(
                            tooltip: '我的位置',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF303234),
                              foregroundColor: const Color(0xFF2196F3),
                              padding: const EdgeInsets.all(14),
                            ),
                            onPressed: _locating ? null : _locate,
                            icon: _locating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2B2B2B),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .55,
                    ),
                    child: SingleChildScrollView(
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 38,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF484848),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                location.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFE2E2E2),
                                ),
                              ),
                              if (location.address.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  location.address,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: Color(0xFFC5C5C5),
                                  ),
                                ),
                              ],
                              if (_distance != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '直线距离 ${_distance! < 1000 ? '${_distance!.round()} 米' : '${(_distance! / 1000).toStringAsFixed(1)} 公里'}',
                                  style: const TextStyle(
                                    color: Color(0xFF9BA3AB),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _action(
                                      Icons.navigation,
                                      '导航',
                                      _openingMap ? null : _openMap,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _action(
                                      _isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      _isSaved ? '已收藏' : '收藏',
                                      _saving ? null : _toggleSaved,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 48,
                                    child: _action(Icons.more_horiz, '', _more),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _action(
    IconData icon,
    String text,
    VoidCallback? onPressed,
  ) => Tooltip(
    message: text.isEmpty ? '更多' : text,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF434343),
        foregroundColor: const Color(0xFFE3E3E3),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          if (text.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: const TextStyle(fontSize: 16))),
          ],
        ],
      ),
    ),
  );
}
