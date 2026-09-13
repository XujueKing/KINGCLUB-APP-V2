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
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (_sessionInvalid || !mounted) return;
      final type = event['eventType'];
      if (type == 'chat.settings.changed' ||
          type == 'chat.relationship.changed' ||
          type == 'connection.ready') {
        _invalidateAndReload();
      }
    });
    _session = SecureSessionStore.changes.stream.listen((_) {
      _generation++;
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
    setState(() => _profile = null);
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _invalidateAndReload();
  }

  Future<void> _load() async {
    if (_sessionInvalid) return;
    final generation = ++_generation;
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
    setState(() => _saving = true);
    try {
      await _repository!.setRelationship(
        widget.account,
        _profile!['following'] == true ? 'unfollow' : 'follow',
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final width = MediaQuery.sizeOf(context).width;
    final scale = width / 375;
    final top = MediaQuery.paddingOf(context).top;
    final tags = <String>[
      if (profile?['age'] != null) '${profile!['age']}岁',
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: top + 210 * scale,
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: 22 * scale,
                      child: ColoredBox(color: const Color(0xFF161A22)),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 44 * scale,
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
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
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
                      child: CircleAvatar(
                        radius: 47 * scale,
                        backgroundColor: const Color(0xFFE2E2E2),
                        child: Icon(
                          Icons.person,
                          size: 50 * scale,
                          color: const Color(0xFF999999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 135 * scale,
                      right: 18,
                      bottom: 30 * scale,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?['nickname'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
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
                              child: Text(
                                '账号：${profile['memberId']}',
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 12,
                                ),
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
                padding: EdgeInsets.fromLTRB(20 * scale, 16, 20 * scale, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                    if (profile != null) ...[
                      Text(
                        profile['bio'] as String? ?? '',
                        style: const TextStyle(
                          color: Color(0xFF444444),
                          fontSize: 15,
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
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Color(0xFF777777),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
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
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _tab = i),
                            child: Text(
                              ['作品', '动态', '相册'][i],
                              style: TextStyle(
                                color: _tab == i
                                    ? const Color(0xFF222222)
                                    : const Color(0xFF999999),
                                fontSize: 16,
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 42),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    profile == null
                        ? ''
                        : profile['contentVisible'] == false
                        ? '暂时无法查看'
                        : '内容暂不可用',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
