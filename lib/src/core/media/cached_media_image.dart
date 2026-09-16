import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../session/secure_session_store.dart';
import 'media_cache.dart';

class CachedMediaImage extends StatefulWidget {
  const CachedMediaImage(
    this.url, {
    super.key,
    this.contentKey,
    this.headers,
    this.placeholder,
    this.private = false,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.cache,
    this.cacheOnly = false,
    this.keepSameImageOnRefresh = false,
  });
  final String url;
  final String? contentKey;
  final Map<String, String>? headers;
  final Widget? placeholder;
  final bool private;
  final double? width, height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final MediaCache? cache;
  final bool cacheOnly;
  final bool keepSameImageOnRefresh;
  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  late Future<File> _file;
  Object _imageIdentity = Object();
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    _file = _load();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted || !widget.private) return;
      setState(() {
        _imageIdentity = Object();
        _file = _load();
      });
    });
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CachedMediaImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.contentKey != widget.contentKey ||
        old.private != widget.private ||
        old.cache != widget.cache ||
        old.cacheOnly != widget.cacheOnly ||
        !mapEquals(old.headers, widget.headers)) {
      if (!widget.keepSameImageOnRefresh ||
          widget.contentKey == null ||
          old.contentKey != widget.contentKey ||
          old.private != widget.private ||
          old.cache != widget.cache) {
        _imageIdentity = Object();
      }
      _file = _load();
    }
  }

  Future<File> _load() async {
    var scope = 'public';
    if (widget.private) {
      final session = await SecureSessionStore().readSession();
      final account = session?['account'];
      final id = account is Map ? account['userAccount'] : null;
      if (id == null) throw StateError('请重新登录');
      scope = 'member:$id';
    }
    final cache = widget.cache ?? MediaCache.shared;
    if (widget.cacheOnly) {
      final key = widget.contentKey;
      if (key == null) throw StateError('缺少缓存标识');
      return cache.cachedImage(scope: scope, contentKey: key);
    }
    return cache.get(
      widget.url,
      scope: scope,
      contentKey: widget.contentKey,
      headers: widget.headers,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    // Only an explicitly retained, identical content ID may keep its pixels.
    key: ObjectKey(_imageIdentity),
    future: _file,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.file(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
        );
      }
      if (snapshot.hasError) {
        return widget.errorBuilder?.call(context, snapshot.error!, null) ??
            const Icon(Icons.broken_image_outlined);
      }
      if (widget.placeholder != null) return widget.placeholder!;
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 1),
          ),
        ),
      );
    },
  );
}
