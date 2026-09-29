import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/session/secure_session_store.dart';
import '../../messaging/data/messaging_repository.dart';
import '../../messaging/presentation/chat_member_avatar.dart';
import '../../messaging/presentation/direct_chat_page.dart';
import '../../messaging/presentation/legacy_messaging_components.dart';
import 'public_member_page.dart';

enum FriendDiscoveryMode { search, browse, radar, faceGroup }

class FriendDiscoveryPage extends StatefulWidget {
  const FriendDiscoveryPage({
    super.key,
    this.mode = FriendDiscoveryMode.search,
    this.repository,
    this.onBack,
    this.onOpenScanner,
    this.onOpenPersonalQr,
  });
  final FriendDiscoveryMode mode;
  final MessagingRepository? repository;
  final VoidCallback? onBack, onOpenPersonalQr;
  final Future<void> Function()? onOpenScanner;
  @override
  State<FriendDiscoveryPage> createState() => _FriendDiscoveryPageState();
}

class _FriendDiscoveryPageState extends State<FriendDiscoveryPage>
    with WidgetsBindingObserver {
  final _query = TextEditingController();
  MessagingRepository? _repository;
  StreamSubscription<void>? _session;
  Timer? _radarTimer;
  final _avatars = <String, Future<Map<String, dynamic>>>{};
  List<Map<String, dynamic>> _items = [];
  String? _error, _cursor, _interest;
  int? _gender;
  RangeValues _ages = const RangeValues(18, 60);
  bool _busy = false, _searched = false, _invalid = false, _radarActive = false;
  int _generation = 0;
  String _leaseId = const Uuid().v4();
  bool _searchSubmitted = false;

  void _clearSearch() {
    _generation++;
    _query.clear();
    setState(() {
      _searchSubmitted = false;
      _searched = false;
      _busy = false;
      _items = [];
      _cursor = null;
      _error = null;
    });
  }

  String get _title => switch (widget.mode) {
    FriendDiscoveryMode.search => '添加朋友',
    FriendDiscoveryMode.browse => '交友查询',
    FriendDiscoveryMode.radar => '雷达',
    FriendDiscoveryMode.faceGroup => '面对面建群',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository;
    _session = SecureSessionStore.changes.stream.listen((_) {
      _stopRadar();
      _generation++;
      _invalid = true;
      if (mounted) {
        setState(() {
          _items = [];
          _avatars.clear();
          _busy = false;
          _error = '登录状态已变化，请重新进入';
        });
      }
    });
  }

  @override
  void dispose() {
    _stopRadar();
    _session?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _query.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopRadar();
      if (mounted) setState(() {});
    }
  }

  void _stopRadar() {
    _radarTimer?.cancel();
    _radarTimer = null;
    if (_radarActive) {
      _radarActive = false;
      _generation++;
      unawaited(
        _repository
                ?.call('K260930000903', {
                  'action': 'leave',
                  'leaseId': _leaseId,
                })
                .then<void>((_) {})
                .catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
  }

  Future<Map<String, dynamic>> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('请开启手机定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('请在系统设置中允许定位，再重试');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (!p.accuracy.isFinite || p.accuracy > 150) {
      throw StateError('当前位置不够准确，请移到信号较好的地方重试');
    }
    return {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': p.accuracy,
    };
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || _invalid) return;
    final query = _query.text.trim();
    if (widget.mode == FriendDiscoveryMode.search && query.isEmpty) {
      setState(() => _error = '请输入账号或手机号码');
      return;
    }
    if (widget.mode == FriendDiscoveryMode.faceGroup &&
        !RegExp(r'^\d{4}$').hasMatch(query)) {
      setState(() => _error = '请输入与身边朋友相同的四位数字');
      return;
    }
    final generation = _generation;
    final leaseId = _leaseId;
    setState(() {
      _busy = true;
      _error = null;
      if (widget.mode == FriendDiscoveryMode.search) {
        _searchSubmitted = true;
        _searched = false;
        _items = [];
      }
    });
    try {
      final repo = _repository ??= await MessagingRepository.open();
      if (!mounted || _invalid || generation != _generation) return;
      Map<String, dynamic> result;
      switch (widget.mode) {
        case FriendDiscoveryMode.search:
          result = await repo.call('K260930000901', {'query': query});
        case FriendDiscoveryMode.browse:
          result = await repo.call('K260930000902', {
            'gender': ?_gender,
            'minAge': _ages.start.round(),
            'maxAge': _ages.end.round(),
            'interest': ?_interest,
            if (more && _cursor != null) 'after': _cursor,
          });
        case FriendDiscoveryMode.radar:
          final position = await _position();
          if (!mounted || _invalid || generation != _generation) return;
          result = await repo.call('K260930000903', {
            'action': 'refresh',
            'leaseId': leaseId,
            ...position,
          });
        case FriendDiscoveryMode.faceGroup:
          final position = await _position();
          if (!mounted || _invalid || generation != _generation) return;
          result = await repo.call('K260930000904', {
            'code': query,
            ...position,
          });
      }
      if (!mounted || _invalid || generation != _generation) {
        if (widget.mode == FriendDiscoveryMode.radar) {
          unawaited(
            repo
                .call('K260930000903', {'action': 'leave', 'leaseId': leaseId})
                .catchError((Object _) => <String, dynamic>{}),
          );
        }
        return;
      }
      if (widget.mode == FriendDiscoveryMode.faceGroup) {
        await Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(
            builder: (_) => DirectChatPage(
              groupId: result['groupId'] as String,
              peerName: result['groupName'] as String,
              repository: repo,
            ),
          ),
        );
        return;
      }
      final items = (result['items'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      setState(() {
        _items = more ? [..._items, ...items] : items;
        _cursor = result['nextCursor'] as String?;
        _searched = true;
      });
      if (widget.mode == FriendDiscoveryMode.radar && _radarActive) {
        _radarTimer ??= Timer.periodic(
          const Duration(seconds: 15),
          (_) => unawaited(_load()),
        );
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted &&
          (generation == _generation ||
              widget.mode != FriendDiscoveryMode.search)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _profile(String account) async {
    _stopRadar();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PublicMemberPage(account: account, repository: _repository),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _open(FriendDiscoveryMode mode) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FriendDiscoveryPage(mode: mode, repository: _repository),
      ),
    );
  }

  Widget _entry(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? tap,
  ) => ListTile(
    leading: Icon(icon, color: legacyMessageGold),
    title: Text(title),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: Color(0xFF8C867E), fontSize: 13),
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: tap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101010),
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: _title,
            backgroundColor: const Color(0xFF101010),
            lineColor: const Color(0x1CC9B69E),
            lineWidth: .5,
            onBack: widget.onBack ?? () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (widget.mode == FriendDiscoveryMode.search)
                  LegacyConversationSearch(
                    controller: _query,
                    hint: '账号 / 手机号码',
                    maxLength: 64,
                    enabled: !_invalid && !_busy,
                    onChanged: (value) {
                      if (value.isEmpty) _clearSearch();
                    },
                    onClear: _clearSearch,
                    onSubmitted: (_) => _load(),
                  ),
                if (widget.mode == FriendDiscoveryMode.faceGroup)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: TextField(
                      controller: _query,
                      enabled: !_invalid,
                      maxLength: widget.mode == FriendDiscoveryMode.faceGroup
                          ? 4
                          : 64,
                      keyboardType: widget.mode == FriendDiscoveryMode.faceGroup
                          ? TextInputType.number
                          : TextInputType.text,
                      inputFormatters:
                          widget.mode == FriendDiscoveryMode.faceGroup
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: widget.mode == FriendDiscoveryMode.search
                            ? '账号 / 手机号码'
                            : '输入相同的四位数字',
                        prefixIcon: Icon(
                          widget.mode == FriendDiscoveryMode.search
                              ? Icons.search
                              : Icons.pin_outlined,
                        ),
                        suffixIcon: IconButton(
                          tooltip: '查找',
                          onPressed: _busy ? null : () => _load(),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ),
                    ),
                  ),
                if (widget.mode == FriendDiscoveryMode.search &&
                    !_searchSubmitted) ...[
                  _entry(
                    Icons.qr_code_scanner,
                    '扫一扫',
                    '扫描二维码名片',
                    widget.onOpenScanner == null
                        ? null
                        : () => widget.onOpenScanner!(),
                  ),
                  _entry(
                    Icons.person_search_outlined,
                    '交友查询',
                    '按性别、年龄、爱好认识朋友',
                    () => _open(FriendDiscoveryMode.browse),
                  ),
                  _entry(
                    Icons.radar,
                    '雷达',
                    '添加身边同样打开雷达的朋友',
                    () => _open(FriendDiscoveryMode.radar),
                  ),
                  _entry(
                    Icons.groups_outlined,
                    '面对面建群',
                    '和身边的朋友输入同一个四位数字',
                    () => _open(FriendDiscoveryMode.faceGroup),
                  ),
                  if (widget.onOpenPersonalQr != null)
                    _entry(
                      Icons.qr_code,
                      '我的二维码',
                      '让朋友扫一扫添加我',
                      widget.onOpenPersonalQr,
                    ),
                ],
                if (widget.mode == FriendDiscoveryMode.browse)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final entry in <int?, String>{
                              null: '不限',
                              1: '男',
                              2: '女',
                            }.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: _gender == entry.key,
                                onSelected: _busy
                                    ? null
                                    : (_) =>
                                          setState(() => _gender = entry.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '年龄 ${_ages.start.round()}–${_ages.end.round()} 岁',
                        ),
                        RangeSlider(
                          values: _ages,
                          min: 18,
                          max: 100,
                          divisions: 82,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _ages = v),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _interest,
                          decoration: const InputDecoration(labelText: '爱好'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('不限'),
                            ),
                            for (final e in const {
                              'house': 'House 音乐',
                              'techno': 'Techno 音乐',
                              'hip_hop': '嘻哈音乐',
                              'cocktail': '鸡尾酒',
                              'red_wine': '红酒',
                              'beer': '啤酒',
                              'cosplay': 'Cosplay',
                              'car_club': '车友会',
                              'campus_club': '校园社团',
                            }.entries)
                              DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _interest = v),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : () => _load(),
                          child: const Text('查找朋友'),
                        ),
                      ],
                    ),
                  ),
                if (widget.mode == FriendDiscoveryMode.radar)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.radar,
                          size: 100,
                          color: legacyMessageGold,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '开启后，附近约 200 米内同时打开雷达的会员可看到你。离开页面或切到后台后停止展示。',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  if (_radarActive) {
                                    _stopRadar();
                                    setState(() {
                                      _items = [];
                                      _searched = false;
                                    });
                                  } else {
                                    setState(() {
                                      _leaseId = const Uuid().v4();
                                      _radarActive = true;
                                    });
                                    _load();
                                  }
                                },
                          child: Text(_radarActive ? '停止雷达' : '开启雷达'),
                        ),
                      ],
                    ),
                  ),
                if (widget.mode == FriendDiscoveryMode.faceGroup)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '和身边约 200 米内的朋友输入相同四位数字，即可进入同一群聊。入群窗口为 10 分钟，请只向准备加入的朋友告知数字。',
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (_searched && _items.isEmpty && !_busy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂未找到符合条件的朋友', textAlign: TextAlign.center),
                  ),
                for (final item in _items)
                  ListTile(
                    leading: ChatMemberAvatar(
                      profile: _avatars.putIfAbsent(
                        item['account'] as String,
                        () => _repository!.avatarProfile(
                          item['account'] as String,
                        ),
                      ),
                      account: item['account'] as String,
                    ),
                    title: Text(
                      (item['nickname'] as String?)?.isNotEmpty == true
                          ? item['nickname'] as String
                          : item['account'] as String,
                    ),
                    subtitle: Text(
                      [
                        if (item['age'] != null) '${item['age']}岁',
                        if (item['locationCity'] != null) item['locationCity'],
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _profile(item['account'] as String),
                  ),
                if (_cursor != null)
                  TextButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: const Text('加载更多'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
