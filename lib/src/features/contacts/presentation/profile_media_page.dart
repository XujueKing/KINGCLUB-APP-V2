import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../../core/media/cached_media_video.dart';
import '../../../core/design_system/king_components.dart';
import '../../auth/data/auth_repository_provider.dart';

class ProfileMediaPage extends StatefulWidget {
  const ProfileMediaPage({
    super.key,
    required this.media,
    required this.contentType,
    required this.account,
    required this.owner,
    required this.visibility,
  });
  final Map<String, dynamic> media;
  final String contentType, account, owner;
  final ValueNotifier<int> visibility;
  @override
  State<ProfileMediaPage> createState() => _ProfileMediaPageState();
}

class _ProfileMediaPageState extends State<ProfileMediaPage> {
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    widget.visibility.addListener(_invalidate);
  }

  void _invalidate() {
    if (mounted) setState(() => _valid = false);
  }

  @override
  void dispose() {
    widget.visibility.removeListener(_invalidate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.media['path'];
    final available =
        _valid &&
        kingclubApiBaseUrl.isNotEmpty &&
        path is String &&
        path.startsWith('/kingclub/profile-media/');
    final headers = (widget.media['headers'] as Map? ?? {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
    final key = 'profile:${widget.owner}:${widget.media['fileId']}';
    final url = "${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}$path";
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Center(
        child: !available
            ? const Text('内容暂不可查看', style: TextStyle(color: Colors.white70))
            : widget.contentType.startsWith('video/')
            ? CachedMediaVideo(
                url: url,
                scope: 'member:${widget.account}',
                active: true,
                muted: false,
                contentKey: key,
                headers: headers,
              )
            : InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedMediaImage(
                  url,
                  private: true,
                  contentKey: key,
                  headers: headers,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }
}
