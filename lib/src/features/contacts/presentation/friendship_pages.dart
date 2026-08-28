import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyMuted = Color(0xFFAAA29A);
const _legacyLine = Color(0xFF1A1611);

enum FriendRequestsScenario {
  ready,
  empty,
  partialError,
  offlineCached,
  sessionInvalid,
}

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({
    super.key,
    required this.onOpenAddFriend,
    required this.onOpenChat,
    this.initialScenario = FriendRequestsScenario.ready,
    this.onBack,
    this.onSessionResetRequested,
  });

  final VoidCallback onOpenAddFriend;
  final ValueChanged<String> onOpenChat;
  final FriendRequestsScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onSessionResetRequested;

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  late FriendRequestsScenario _scenario;
  final _requests = <_FriendRequest>[
    _FriendRequest('林晓悦', '想认识一下，一起参加周末活动', '10:36', '待查看'),
    _FriendRequest('阿澈', '我是通过扫一扫添加的', '昨天', '待查看'),
  ];

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    if (_scenario == FriendRequestsScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _LegacyFriendHeader(
              title: '新的朋友',
              onBack: _finishBack,
              onTitleLongPress: _showScenarioPanel,
              trailing: IconButton(
                key: const ValueKey('friend-requests-add'),
                tooltip: '添加好友',
                onPressed: widget.onOpenAddFriend,
                icon: Image.asset(
                  'assets/legacy/friendship/add.png',
                  width: 24,
                  height: 24,
                  color: _legacyGold,
                ),
              ),
            ),
            Expanded(
              child: _scenario == FriendRequestsScenario.empty
                  ? _emptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _requests.length + (_hasStatusBanner ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: _legacyLine),
                      itemBuilder: (context, index) {
                        if (_hasStatusBanner && index == 0) {
                          return _statusBanner();
                        }
                        final request =
                            _requests[index - (_hasStatusBanner ? 1 : 0)];
                        return _RequestTile(
                          key: ValueKey(
                            'friend-request-${index - (_hasStatusBanner ? 1 : 0)}',
                          ),
                          request: request,
                          onTap:
                              _scenario == FriendRequestsScenario.offlineCached
                              ? null
                              : () => _showRequest(
                                  index - (_hasStatusBanner ? 1 : 0),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasStatusBanner =>
      _scenario == FriendRequestsScenario.partialError ||
      _scenario == FriendRequestsScenario.offlineCached;

  Widget _statusBanner() {
    final offline = _scenario == FriendRequestsScenario.offlineCached;
    return Container(
      key: ValueKey('friend-requests-${offline ? 'offline' : 'partial-error'}'),
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF171411),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.cloud_off_outlined : Icons.sync_problem_outlined,
            color: _legacyGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              offline ? '当前离线，仅展示本地只读申请记录' : '刷新部分失败，已保留现有申请记录',
              style: const TextStyle(color: _legacyMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      key: const ValueKey('friend-requests-empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_add_alt_1_outlined,
            color: _legacyGold,
            size: 54,
          ),
          const SizedBox(height: 16),
          const Text('暂无新的好友申请', style: TextStyle(color: _legacyMuted)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: widget.onOpenAddFriend,
            child: const Text('添加好友'),
          ),
        ],
      ),
    );
  }

  Future<void> _showScenarioPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '好友申请 UI Mock 场景',
                style: TextStyle(color: _legacyGold),
              ),
            ),
            for (final scenario in FriendRequestsScenario.values)
              ListTile(
                key: ValueKey('friend-requests-scenario-${scenario.name}'),
                title: Text(
                  _scenarioLabel(scenario),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: scenario == _scenario
                    ? const Icon(Icons.check, color: _legacyGold)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _scenario = scenario);
                  if (scenario == FriendRequestsScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _scenarioLabel(FriendRequestsScenario scenario) => switch (scenario) {
    FriendRequestsScenario.ready => '正常申请列表',
    FriendRequestsScenario.empty => '空列表',
    FriendRequestsScenario.partialError => '分页 / 刷新部分失败',
    FriendRequestsScenario.offlineCached => '离线只读缓存',
    FriendRequestsScenario.sessionInvalid => '会话失效',
  };

  Future<void> _showSessionInvalid() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('friend-requests-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('申请列表和临时处理状态已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('friend-requests-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _showRequest(int index) async {
    final request = _requests[index];
    final resolution = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                request.message,
                style: const TextStyle(color: _legacyMuted),
              ),
              const SizedBox(height: 22),
              if (request.status == '待查看')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('friend-request-reject'),
                        onPressed: () => Navigator.pop(sheetContext, '已拒绝'),
                        child: const Text('拒绝'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('friend-request-accept'),
                        onPressed: () => Navigator.pop(sheetContext, '已添加'),
                        child: const Text('接受'),
                      ),
                    ),
                  ],
                )
              else if (request.status == '已添加')
                FilledButton(
                  key: const ValueKey('friend-request-message'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    widget.onOpenChat(request.name);
                  },
                  child: const Text('发消息'),
                )
              else
                Text(
                  request.status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _legacyGold),
                ),
              const SizedBox(height: 12),
              const Text(
                '当前为离线 UI Mock，不会建立真实好友关系。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF746D65), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || resolution == null) return;
    setState(() => request.status = resolution);
    if (resolution == '已添加') await _showFriendAccepted(request.name);
  }

  Future<void> _showFriendAccepted(String name) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171411),
        icon: const Icon(
          Icons.check_circle,
          color: Color(0xFF29B463),
          size: 44,
        ),
        title: const Text('已添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '你已添加了$name，现在可以开始聊天了。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _legacyMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('friend-accepted-message'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  widget.onOpenChat(name);
                },
                child: const Text('发消息'),
              ),
            ),
            TextButton(
              key: const ValueKey('friend-accepted-done'),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}

enum AddFriendScenario { ready, destinationUnavailable, sessionInvalid }

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({
    super.key,
    required this.onOpenScanner,
    this.onOpenPersonalQr,
    this.initialScenario = AddFriendScenario.ready,
    this.onBack,
    this.onSessionResetRequested,
  });

  final Future<void> Function() onOpenScanner;
  final VoidCallback? onOpenPersonalQr;
  final AddFriendScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onSessionResetRequested;

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  late AddFriendScenario _scenario;
  bool _navigationPending = false;

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    if (_scenario == AddFriendScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _LegacyFriendHeader(
              title: '添加朋友',
              onBack: _finishBack,
              onTitleLongPress: _showScenarioPanel,
            ),
            InkWell(
              key: const ValueKey('add-friend-scan'),
              onTap: _openScanner,
              child: Container(
                height: 82,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x66522B43))),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/legacy/friendship/saoyisao.png',
                      width: 28,
                      height: 28,
                      color: _legacyGold,
                    ),
                    const SizedBox(width: 19),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '扫一扫',
                            style: TextStyle(color: Colors.white, fontSize: 17),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '扫描二维码名片',
                            style: TextStyle(color: _legacyMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/legacy/friendship/next.png',
                      width: 15,
                      height: 15,
                      color: _legacyMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 62),
            InkWell(
              key: const ValueKey('add-friend-personal-qr'),
              onTap: widget.onOpenPersonalQr,
              child: Container(
                key: const ValueKey('add-friend-fake-qr'),
                width: 226,
                height: 226,
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: QrImageView(
                  data: 'KINGCLUB_UI_MOCK_INVALID_FRIEND_INVITE',
                  padding: EdgeInsets.zero,
                  embeddedImage: const AssetImage(
                    'assets/legacy/home/logo_2.png',
                  ),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(36, 36),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '我的短期好友二维码',
              style: TextStyle(color: _legacyMuted, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '点击可查看完整二维码 · 不含永久账号或登录凭证',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF615B55), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    if (_navigationPending) return;
    if (_scenario == AddFriendScenario.destinationUnavailable) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('扫码入口暂时不可用，请稍后重试')));
      return;
    }
    setState(() => _navigationPending = true);
    try {
      await widget.onOpenScanner();
    } finally {
      if (mounted) setState(() => _navigationPending = false);
    }
  }

  Future<void> _showScenarioPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '添加好友 UI Mock 场景',
                style: TextStyle(color: _legacyGold),
              ),
            ),
            for (final scenario in AddFriendScenario.values)
              ListTile(
                key: ValueKey('add-friend-scenario-${scenario.name}'),
                title: Text(switch (scenario) {
                  AddFriendScenario.ready => '正常双入口',
                  AddFriendScenario.destinationUnavailable => '目标页面不可用',
                  AddFriendScenario.sessionInvalid => '会话失效',
                }, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _scenario = scenario);
                  if (scenario == AddFriendScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionInvalid() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('add-friend-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('页面临时状态已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('add-friend-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _LegacyFriendHeader extends StatelessWidget {
  const _LegacyFriendHeader({
    required this.title,
    required this.onBack,
    this.onTitleLongPress,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onTitleLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 14,
            child: IconButton(
              key: ValueKey('friend-page-back-$title'),
              tooltip: '返回',
              onPressed: onBack,
              icon: Image.asset(
                'assets/legacy/friendship/back.png',
                width: 22,
                color: _legacyGold,
              ),
            ),
          ),
          GestureDetector(
            key: ValueKey('friend-page-title-$title'),
            onLongPress: onTitleLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (trailing != null) Positioned(right: 14, child: trailing!),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({super.key, required this.request, required this.onTap});

  final _FriendRequest request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pending = request.status == '待查看';
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            const SizedBox(width: 27),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF211D18),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                request.name.characters.first,
                style: const TextStyle(
                  color: _legacyGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          request.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        request.time,
                        style: const TextStyle(
                          color: Color(0xFF444444),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (pending)
              Container(
                width: 52,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0EA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '查看',
                  style: TextStyle(color: Colors.black, fontSize: 13),
                ),
              )
            else
              Text(
                request.status,
                style: const TextStyle(color: _legacyMuted, fontSize: 13),
              ),
            const SizedBox(width: 27),
          ],
        ),
      ),
    );
  }
}

class _FriendRequest {
  _FriendRequest(this.name, this.message, this.time, this.status);

  final String name;
  final String message;
  final String time;
  String status;
}
