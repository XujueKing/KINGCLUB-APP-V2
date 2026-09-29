import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_notice.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_location.dart';
import '../data/chat_media_deletion.dart';

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

  Future<void> _openMap() async {
    if (!_valid || _openingMap) return;
    setState(() => _openingMap = true);
    try {
      final data = widget.location.toJson()..remove('address');
      final opened = await _maps.invokeMethod<bool>('open', data);
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
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => _valid = false);
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
      setState(() {
        _deleted = true;
        _valid = false;
      });
    });
  }

  @override
  void dispose() {
    _session?.cancel();
    _removeDeletionListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final coordinates =
        '${(location.latitudeE6 / 1e6).toStringAsFixed(6)}, '
        '${(location.longitudeE6 / 1e6).toStringAsFixed(6)}';
    final system = location.coordinateSystem == 'gcj02' ? 'GCJ-02' : 'WGS84';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: kingAppBar(
        context: context,
        title: const Text('位置'),
        backgroundColor: Colors.black,
        leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: !_valid
              ? Text(_deleted ? '内容已移除' : '登录状态已变化，请重新进入')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    if (location.address.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        location.address,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      '经纬度：$coordinates',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '坐标系：$system',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('在高德地图查看'),
                      onPressed: _openingMap ? null : _openMap,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('复制地点信息'),
                      onPressed: () async {
                        if (!_valid) return;
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${location.name}\n${location.address}\n$coordinates ($system)',
                          ),
                        );
                        if (context.mounted && _valid) {
                          KingNotice.of(context).show('地点信息已复制');
                        }
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
