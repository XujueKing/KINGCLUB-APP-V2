import 'package:get_thumbnail_video/index.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';

import 'media_cache.dart';

/// A silent, static poster: never allocates a playing video texture in a list.
class CachedVideoPoster extends StatefulWidget {
  const CachedVideoPoster({
    super.key,
    required this.url,
    required this.scope,
    required this.contentKey,
    required this.placeholder,
    this.headers,
  });
  final String url, scope, contentKey;
  final Map<String, String>? headers;
  final Widget placeholder;
  @override
  State<CachedVideoPoster> createState() => _CachedVideoPosterState();
}

class _CachedVideoPosterState extends State<CachedVideoPoster> {
  late Future<File> _poster;
  static Future<void> _decoding = Future<void>.value();
  Future<File> _load() => MediaCache.shared.videoPoster(
    widget.url,
    scope: widget.scope,
    contentKey: widget.contentKey,
    headers: widget.headers,
    decode: (file) {
      final result = _decoding.then(
        (_) => VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 320,
          timeMs: 0,
          quality: 80,
        ),
      );
      _decoding = result.then<void>((_) {}, onError: (Object _) {});
      return result;
    },
  );
  @override
  void initState() {
    super.initState();
    _poster = _load();
  }

  @override
  void didUpdateWidget(CachedVideoPoster old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.scope != widget.scope ||
        old.contentKey != widget.contentKey) {
      _poster = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: _poster,
    builder: (context, snapshot) => Stack(
      fit: StackFit.expand,
      children: [
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData)
          Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => widget.placeholder,
          )
        else
          widget.placeholder,
        const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white70,
            size: 28,
          ),
        ),
      ],
    ),
  );
}
