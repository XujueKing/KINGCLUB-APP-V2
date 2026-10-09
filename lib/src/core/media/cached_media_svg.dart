import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../session/secure_session_store.dart';
import 'media_cache.dart';

/// Signed SVG layers use the same durable, account-scoped media cache as PNGs.
class CachedMediaSvg extends StatefulWidget {
  const CachedMediaSvg(this.url, {super.key, required this.contentKey});
  final String url, contentKey;
  @override
  State<CachedMediaSvg> createState() => _CachedMediaSvgState();
}

class _CachedMediaSvgState extends State<CachedMediaSvg> {
  late Future<String> _svg;
  StreamSubscription<void>? _session;
  Object _identity = Object();
  @override
  void initState() {
    super.initState();
    _svg = _startLoad();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      setState(() {
        _identity = Object();
        _svg = _startLoad();
      });
    });
  }

  Future<String> _startLoad() {
    final pending = _load();
    unawaited(pending.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return pending;
  }

  Future<String> _load() async {
    final session = await SecureSessionStore().readSession();
    final account = session?['account'];
    final id = account is Map ? account['userAccount'] : null;
    if (id is! String || id.isEmpty) throw StateError('请重新登录');
    final file = await MediaCache.shared.get(
      widget.url,
      scope: 'member:$id',
      contentKey: widget.contentKey,
    );
    return file.readAsString();
  }

  @override
  void didUpdateWidget(CachedMediaSvg old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.contentKey != widget.contentKey) {
      if (old.contentKey != widget.contentKey) _identity = Object();
      _svg = _startLoad();
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    key: ObjectKey(_identity),
    future: _svg,
    builder: (context, snapshot) => snapshot.hasData
        ? SvgPicture.string(snapshot.data!, fit: BoxFit.contain)
        : const SizedBox.shrink(),
  );
}
