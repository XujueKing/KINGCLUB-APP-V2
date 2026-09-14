import '../../../core/media/cached_video_poster.dart';
import 'profile_media_page.dart';
import '../../../core/media/cached_media_image.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../../core/networking/kingclub_realtime.dart';
import 'friend_remark_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_notice.dart';
import '../../../core/session/secure_session_store.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../messaging/presentation/direct_chat_page.dart';

/// Real visitor profile. The image reference defines the geometry; member data
/// is never copied from that reference or from the demonstration profile.
class PublicMemberPage extends StatefulWidget {
  const PublicMemberPage({
    super.key,
    required this.account,
    this.repository,
    this.events,
  });
  final String account;
  final MessagingRepository? repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<PublicMemberPage> createState() => _PublicMemberPageState();
}

class _PublicMemberPageState extends State<PublicMemberPage>
    with WidgetsBindingObserver {
  MessagingRepository? _repository;
  Map<String, dynamic>? _profile;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _sessionInvalid = false;
  int _generation = 0;
  int _tab = 0;
  final _scroll = ScrollController();
  final _visibility = ValueNotifier<int>(0);
  int _contentGeneration = 0;
  List<Map<String, dynamic>> _items = [];
  int? _nextOffset;
  bool _contentLoading = false, _contentLoaded = false;
  String? _contentError;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && _nextOffset != null) {
        unawaited(_loadContent());
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (_sessionInvalid || !mounted) return;
      final type = event['eventType'];
      if (type == 'chat.settings.changed' ||
          type == 'chat.relationship.changed' ||
          type == 'chat.friend-request.changed' ||
          type == 'connection.ready') {
        _invalidateAndReload();
      }
    });
    _session = SecureSessionStore.changes.stream.listen((_) {
      _generation++;
      _clearContent();
      _sessionInvalid = true;
      if (mounted) {
        setState(() {
          _profile = null;
          _repository = null;
          _error = '登录状态已变化，请重新打开';
        });
      }
    });
    unawaited(_load());
  }

  void _invalidateAndReload() {
    if (!mounted || _sessionInvalid) return;
    setState(() {
      _profile = null;
      _clearContent();
    });
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _invalidateAndReload();
  }

  Future<void> _load() async {
    if (_sessionInvalid) return;
    final generation = ++_generation;
    setState(_clearContent);
    try {
      final repository =
          _repository ?? widget.repository ?? await MessagingRepository.open();
      final profile = await repository.call('K260913000612', {
        'peer': widget.account,
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        _repository = repository;
        _profile = profile;
        _error = null;
      });
      if (profile['contentVisible'] == true) await _loadContent(reset: true);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _profile = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _remark() async {
    final profile = _profile;
    if (profile == null || _repository == null) return;
    await Navigator.of(context).push<FriendRemarkResult>(
      MaterialPageRoute(
        builder: (_) => FriendRemarkPage(
          targetRef: widget.account,
          repository: _repository,
          initialRemark: profile['remark'] as String? ?? '',
          signature: profile['bio'] as String? ?? '',
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _follow() async {
    if (_saving || _repository == null || _profile == null) return;
    final unfollow = _profile!['following'] == true;
    final repository = _repository!;
    setState(() => _saving = true);
    try {
      if (unfollow) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('取消关注？'),
            content: const Text('取消后将不再是互相关注的好友。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('保留关注'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('取消关注'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted || _repository != repository) return;
      }
      await repository.setRelationship(
        widget.account,
        unfollow ? 'unfollow' : 'follow',
      );
      await _load();
    } catch (e) {
      if (mounted) KingNotice.of(context).show(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    _scroll.dispose();
    _visibility.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _clearContent() {
    _contentGeneration++;
    _visibility.value++;
    _items = [];
    _nextOffset = null;
    _contentLoading = false;
    _contentLoaded = false;
    _contentError = null;
  }

  Future<void> _loadContent({bool reset = false}) async {
    if (_sessionInvalid ||
        _repository == null ||
        _profile?['contentVisible'] != true ||
        _contentLoading) {
      return;
    }
    final offset = reset ? 0 : _nextOffset;
    if (offset == null) return;
    final generation = _contentGeneration;
    final category = ['work', 'post', 'album'][_tab];
    setState(() {
      _contentLoading = true;
      _contentError = null;
    });
    try {
      final response = await _repository!.call('K260913000614', {
        'peer': widget.account,
        'category': category,
        'offset': offset,
      });
      if (!mounted || generation != _contentGeneration) return;
      final items = (response['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final next = response['nextOffset'] as int?;
      if (next != null && (next <= offset || items.isEmpty)) {
        throw const FormatException('内容分页无效');
      }
      setState(() {
        final byRef = {for (final item in _items) item['ref']: item};
        for (final item in items) {
          byRef[item['ref']] = item;
        }
        _items = byRef.values.toList();
        _nextOffset = next;
        _contentLoaded = true;
      });
    } catch (error) {
      if (!mounted || generation != _contentGeneration) return;
      setState(() {
        // Any failed authorization refresh removes prior content, not just the
        // thumbnail. Existing permissions are never inferred from disk cache.
        _items = [];
        _nextOffset = null;
        _visibility.value++;
        _contentError = '内容加载失败，请重试';
      });
    } finally {
      if (mounted && generation == _contentGeneration) {
        setState(() => _contentLoading = false);
      }
    }
  }

  void _openMedia(Map<String, dynamic> item) {
    final media = item['media'];
    if (media is! Map || _repository == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileMediaPage(
          media: Map<String, dynamic>.from(media),
          contentType: item['contentType'] as String? ?? '',
          account: _repository!.account,
          owner: widget.account,
          visibility: _visibility,
        ),
      ),
    );
  }

  Widget _thumbnail(Map<String, dynamic> item) {
    final video = (item['contentType'] as String? ?? '').startsWith('video/');
    final fallback = ColoredBox(
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          video ? Icons.play_circle_outline : Icons.image_outlined,
          color: const Color(0xFF999999),
          size: 28,
        ),
      ),
    );
    return GestureDetector(
      onTap: () => _openMedia(item),
      child: video
          ? _videoPoster(item['media'], fallback)
          : _mediaImage(item['media'], fallback),
    );
  }

  Widget _videoPoster(dynamic media, Widget fallback) {
    if (media is! Map || _repository == null || kingclubApiBaseUrl.isEmpty) {
      return fallback;
    }
    final path = media['path'];
    if (path is! String || !path.startsWith('/kingclub/profile-media/')) {
      return fallback;
    }
    return CachedVideoPoster(
      key: ValueKey('${_visibility.value}:${media['fileId']}'),
      url: '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}$path',
      scope: 'member:${_repository!.account}',
      contentKey: 'profile:${widget.account}:${media['fileId']}',
      headers: (media['headers'] as Map? ?? {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      placeholder: fallback,
    );
  }

  List<Widget> _contentSlivers(double scale) {
    if (_profile == null) return [const SliverToBoxAdapter(child: SizedBox())];
    if (_profile!['contentVisible'] == false) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('暂时无法查看', style: TextStyle(color: Color(0xFF999999))),
            ),
          ),
        ),
      ];
    }
    return [
      if (_tab == 1)
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = _items[index];
            final date = DateTime.tryParse(item['createdAt']?.toString() ?? '')
                ?.toLocal();
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                20 * scale,
                20 * scale,
                4 * scale,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70 * scale,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: date == null ? '' : '${date.day}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: date == null ? '' : '${date.month}月',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      style: const TextStyle(color: Color(0xFF444444)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF6F6F6),
                      constraints: BoxConstraints(minHeight: 146 * scale),
                      padding: EdgeInsets.all(10 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((item['caption']?.toString() ?? '')
                              .isNotEmpty) ...[
                            Text(
                              item['caption'].toString(),
                              style: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (item['media'] != null)
                            SizedBox.square(
                              dimension: 80 * scale,
                              child: _thumbnail(item),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }, childCount: _items.length),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.only(top: 2),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: _tab == 0 ? 0.75 : 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _thumbnail(_items[index]),
              childCount: _items.length,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _contentError != null
                ? TextButton(
                    onPressed: () => _loadContent(reset: true),
                    child: Text(_contentError!),
                  )
                : _nextOffset != null
                ? TextButton(
                    onPressed: _contentLoading ? null : () => _loadContent(),
                    child: const Text('加载更多'),
                  )
                : Text(
                    _contentLoaded && _items.isEmpty
                        ? ['暂无作品', '暂无动态', '暂无相册内容'][_tab]
                        : '',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }

  Widget _memberImage(String slot, Widget fallback) {
    return _mediaImage(_profile?[slot], fallback);
  }

  Widget _mediaImage(dynamic media, Widget fallback) {
    if (media is! Map || kingclubApiBaseUrl.isEmpty) return fallback;
    final path = media['path'];
    if (path is! String || !path.startsWith('/kingclub/profile-media/')) {
      return fallback;
    }
    final rawHeaders = media['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    // A current authorized profile response is required before creating this
    // widget. Session/relationship events remove the entire profile immediately.
    return CachedMediaImage(
      '${kingclubApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}$path',
      private: true,
      contentKey: 'profile:${widget.account}:${media['fileId']}',
      headers: headers,
      width: double.infinity,
      height: double.infinity,
      placeholder: fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _relationshipActions(Map<String, dynamic> profile) {
    if (_repository?.account == widget.account) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: profile['following'] == true
                    ? const Color(0xFF333333)
                    : Colors.white,
                backgroundColor: profile['following'] == true
                    ? const Color(0xFFF0F0F0)
                    : const Color(0xFFFF2E55),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(fontSize: 15),
              ),
              onPressed: _saving ? null : _follow,
              child: Text(
                profile['friends'] == true
                    ? '互相关注'
                    : profile['following'] == true
                    ? '已关注'
                    : '关注',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFF333333),
                backgroundColor: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(fontSize: 15),
              ),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => DirectChatPage(
                    peerName: profile['nickname'] as String,
                    peerAccount: widget.account,
                    repository: _repository,
                  ),
                ),
              ),
              child: const Text('私信'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final profile = _profile;
        final width = constraints.maxWidth;
        final scale = width / 375;
        final top = MediaQuery.paddingOf(context).top;
        final stats = profile?['stats'] as Map?;
        final tags = <String>[
          if (profile?['age'] != null) '${profile!['age']}岁',
          if (profile?['appearanceScore'] != null)
            '颜值：${profile!['appearanceScore']}',
          if ((profile?['locationCity'] as String?)?.isNotEmpty == true)
            profile!['locationCity'] as String,
          if (profile?['zodiac'] != null) profile!['zodiac'] as String,
          if ((profile?['details'] as Map?)?['relationship'] != null)
            (profile!['details'] as Map)['relationship'] as String,
        ];
        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    // The old profile leaves room above the overlapping 92dp avatar.
                    height: top + 132 * scale,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _memberImage(
                            'cover',
                            const ColoredBox(color: Color(0xFF161A22)),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 22 * scale,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: top + 4,
                          right: KingBackButton.leftOffset(context),
                          child: IconButton(
                            tooltip: '设置备注',
                            onPressed: profile == null ? null : _remark,
                            icon: const Icon(
                              Icons.more_horiz,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          top: top + 4,
                          left: KingBackButton.leftOffset(context),
                          child: KingBackButton(
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Positioned(
                          left: 25 * scale,
                          bottom: 0,
                          child: SizedBox.square(
                            dimension: 92 * scale,
                            child: ClipOval(
                              child: _memberImage(
                                'avatar',
                                ColoredBox(
                                  color: const Color(0xFFE2E2E2),
                                  child: Icon(
                                    Icons.person,
                                    size: 50 * scale,
                                    color: const Color(0xFF999999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 135 * scale,
                          right: 18,
                          bottom: 27 * scale,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?['nickname'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (profile != null)
                                GestureDetector(
                                  onTap: () => Clipboard.setData(
                                    ClipboardData(
                                      text: profile['memberId'].toString(),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '账号：${profile['memberId']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFAAAAAA),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(
                                        Icons.copy_outlined,
                                        color: Color(0xFFAAAAAA),
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20 * scale,
                      16,
                      20 * scale,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        if (profile != null) ...[
                          Wrap(
                            spacing: 20 * scale,
                            runSpacing: 8,
                            children: [
                              for (final entry in const {
                                'praises': '获赞',
                                'following': '关注',
                                'fans': '粉丝',
                              }.entries)
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${stats?[entry.key] ?? '—'} ',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: entry.value),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            profile['bio'] as String? ?? '',
                            style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final tag in tags)
                                ColoredBox(
                                  color: const Color(0xFFEEEEEE),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (tag == '${profile['age']}岁' &&
                                            (profile['gender'] == 1 ||
                                                profile['gender'] == 2)) ...[
                                          Image.asset(
                                            'assets/legacy/friendship/${profile['gender'] == 1 ? 'man3' : 'woman3'}.png',
                                            width: 12,
                                            height: 12,
                                            semanticLabel:
                                                profile['gender'] == 1
                                                ? '男'
                                                : '女',
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          tag,
                                          style: const TextStyle(
                                            color: Color(0xFF777777),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _relationshipActions(profile),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 16 * scale),
                          for (var i = 0; i < 3; i++)
                            SizedBox(
                              width: 56 * scale,
                              child: TextButton(
                                onPressed: () {
                                  if (_tab == i) return;
                                  setState(() {
                                    _tab = i;
                                    _clearContent();
                                  });
                                  unawaited(_loadContent(reset: true));
                                },
                                child: Text(
                                  ['作品', '动态', '相册'][i],
                                  style: TextStyle(
                                    color: _tab == i
                                        ? const Color(0xFF222222)
                                        : const Color(0xFF999999),
                                    fontSize: 14,
                                    fontWeight: _tab == i
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 1, color: Color(0xFFE6E6E6)),
                    ],
                  ),
                ),
                ..._contentSlivers(scale),
              ],
            ),
          ),
        );
      },
    );
  }
}
