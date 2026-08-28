import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum PersonalQrScenario {
  ready,
  nearlyExpired,
  expired,
  offline,
  issueError,
  refreshError,
  delayedIssue,
  sessionInvalid,
}

enum PersonalQrViewState {
  initialLoading,
  ready,
  refreshing,
  expired,
  offline,
  error,
  backgroundHidden,
  sessionInvalid,
}

class PersonalQrPage extends StatefulWidget {
  const PersonalQrPage({
    super.key,
    this.initialScenario = PersonalQrScenario.ready,
    this.onBack,
    this.onSessionResetRequested,
    this.tickInterval = const Duration(seconds: 1),
  });

  final PersonalQrScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onSessionResetRequested;
  final Duration tickInterval;

  @override
  State<PersonalQrPage> createState() => _PersonalQrPageState();
}

class _PersonalQrPageState extends State<PersonalQrPage>
    with WidgetsBindingObserver {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF747474);
  static const _danger = Color(0xFFE06B6B);

  Timer? _timer;
  Timer? _requestTimer;
  late PersonalQrScenario _scenario;
  PersonalQrViewState _viewState = PersonalQrViewState.initialLoading;
  int _remainingSeconds = 600;
  int _visualSeed = 1;
  int _generation = 0;
  bool _refreshInFlight = false;
  String? _statusAnnouncement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scenario = widget.initialScenario;
    _startTicker();
    _applyInitialScenario();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (_viewState == PersonalQrViewState.backgroundHidden) {
        _refresh(forceNormalResult: true);
      }
      return;
    }
    if (_viewState == PersonalQrViewState.sessionInvalid) return;
    _invalidatePendingRequest();
    setState(() {
      _viewState = PersonalQrViewState.backgroundHidden;
      _statusAnnouncement = '二维码已隐藏';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _requestTimer?.cancel();
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _QrHeader(
              onBack: _finishBack,
              onTitleLongPress: _showScenarioPanel,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 34),
                child: Column(
                  children: [
                    _buildMemberIdentity(),
                    const SizedBox(height: 26),
                    _buildQrArea(),
                    const SizedBox(height: 20),
                    const Text(
                      '扫一扫上面的二维码图案，加我成为朋友',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 9),
                    _buildStatusText(),
                    const SizedBox(height: 7),
                    _buildPrimaryAction(),
                    const SizedBox(height: 28),
                    const Divider(color: Color(0xFF211E1A)),
                    const SizedBox(height: 18),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: _gold, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '二维码仅用于发起好友申请，10 分钟内有效。不包含你的永久账号、手机号或登录凭证。',
                            style: TextStyle(
                              color: Color(0xFF6F675E),
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '离线 UI Mock · 不会签发、刷新或撤销真实邀请码',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF494949), fontSize: 11),
                    ),
                    if (_statusAnnouncement != null)
                      Semantics(
                        liveRegion: true,
                        label: _statusAnnouncement,
                        child: const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberIdentity() {
    return const SizedBox(
      width: 276,
      child: Row(
        children: [
          CircleAvatar(radius: 28, backgroundColor: Color(0xFFF0ECE5)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '杨嘉琪',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 17),
                ),
                SizedBox(height: 4),
                Text(
                  'KingClub 好友邀请',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrArea() {
    final ready = _viewState == PersonalQrViewState.ready;
    return Semantics(
      label: ready ? '用于发起好友申请的短期二维码' : _stateLabel,
      image: ready,
      child: Container(
        key: ValueKey('personal-qr-area-${_viewState.name}-$_visualSeed'),
        width: 276,
        height: 276,
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        alignment: Alignment.center,
        child: ready
            ? ExcludeSemantics(
                child: QrImageView(
                  key: ValueKey('personal-qr-code-$_visualSeed'),
                  data: 'KINGCLUB_UI_MOCK_INVALID_$_visualSeed',
                  version: QrVersions.auto,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  embeddedImage: const AssetImage(
                    'assets/legacy/home/logo_2.png',
                  ),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(42, 42),
                  ),
                ),
              )
            : _QrCover(
                icon: _stateIcon,
                label: _stateLabel,
                detail: _stateDetail,
              ),
      ),
    );
  }

  Widget _buildStatusText() {
    if (_viewState == PersonalQrViewState.ready) {
      final nearing = _remainingSeconds <= 60;
      return Text(
        nearing
            ? '即将过期 · ${_formatTime(_remainingSeconds)}'
            : '有效期 ${_formatTime(_remainingSeconds)}',
        key: const ValueKey('personal-qr-countdown'),
        style: TextStyle(
          color: nearing ? _danger : _gold,
          fontSize: 12,
          fontWeight: nearing ? FontWeight.w700 : FontWeight.w400,
        ),
      );
    }
    return Text(
      _stateLabel,
      key: ValueKey('personal-qr-status-${_viewState.name}'),
      style: TextStyle(
        color: _viewState == PersonalQrViewState.sessionInvalid
            ? _danger
            : _gold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildPrimaryAction() {
    if (_viewState == PersonalQrViewState.initialLoading ||
        _viewState == PersonalQrViewState.refreshing ||
        _viewState == PersonalQrViewState.backgroundHidden ||
        _viewState == PersonalQrViewState.sessionInvalid) {
      return const SizedBox(height: 44);
    }
    final label = switch (_viewState) {
      PersonalQrViewState.ready => '立即刷新',
      PersonalQrViewState.expired => '刷新二维码',
      PersonalQrViewState.offline => '重试',
      PersonalQrViewState.error => '重试',
      _ => '刷新',
    };
    return TextButton.icon(
      key: const ValueKey('personal-qr-refresh'),
      onPressed: _refreshInFlight ? null : _refresh,
      icon: const Icon(Icons.refresh, size: 18),
      label: Text(label),
    );
  }

  String get _stateLabel => switch (_viewState) {
    PersonalQrViewState.initialLoading => '正在生成二维码',
    PersonalQrViewState.ready => '二维码可用',
    PersonalQrViewState.refreshing => '正在刷新二维码',
    PersonalQrViewState.expired => '二维码已过期',
    PersonalQrViewState.offline => '当前无法联网',
    PersonalQrViewState.error => '二维码生成失败',
    PersonalQrViewState.backgroundHidden => '二维码已隐藏',
    PersonalQrViewState.sessionInvalid => '登录状态已失效',
  };

  String get _stateDetail => switch (_viewState) {
    PersonalQrViewState.initialLoading => '旧码不会在加载时显示',
    PersonalQrViewState.refreshing => '旧码已失效，请稍候',
    PersonalQrViewState.expired => '请刷新后再向好友出示',
    PersonalQrViewState.offline => '连接网络后重试，不提供离线码',
    PersonalQrViewState.error => '请重试，不会恢复可能已撤销的旧码',
    PersonalQrViewState.backgroundHidden => '为保护隐私，回到前台后将重新生成',
    PersonalQrViewState.sessionInvalid => '二维码和临时状态已清理',
    PersonalQrViewState.ready => '',
  };

  IconData get _stateIcon => switch (_viewState) {
    PersonalQrViewState.initialLoading ||
    PersonalQrViewState.refreshing => Icons.hourglass_top,
    PersonalQrViewState.expired => Icons.timer_off_outlined,
    PersonalQrViewState.offline => Icons.cloud_off_outlined,
    PersonalQrViewState.error => Icons.error_outline,
    PersonalQrViewState.backgroundHidden => Icons.visibility_off_outlined,
    PersonalQrViewState.sessionInvalid => Icons.lock_outline,
    PersonalQrViewState.ready => Icons.qr_code_2,
  };

  void _startTicker() {
    _timer = Timer.periodic(widget.tickInterval, (_) {
      if (!mounted || _viewState != PersonalQrViewState.ready) return;
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
          _viewState = PersonalQrViewState.expired;
          _visualSeed++;
          _statusAnnouncement = '二维码已过期';
        });
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds == 60) {
          _statusAnnouncement = '二维码将在 1 分钟后过期';
        }
      });
    });
  }

  void _applyInitialScenario() {
    switch (_scenario) {
      case PersonalQrScenario.ready:
        _viewState = PersonalQrViewState.ready;
        _remainingSeconds = 600;
      case PersonalQrScenario.nearlyExpired:
        _viewState = PersonalQrViewState.ready;
        _remainingSeconds = 55;
      case PersonalQrScenario.expired:
        _viewState = PersonalQrViewState.expired;
        _remainingSeconds = 0;
      case PersonalQrScenario.offline:
        _viewState = PersonalQrViewState.offline;
      case PersonalQrScenario.issueError:
      case PersonalQrScenario.refreshError:
        _viewState = PersonalQrViewState.error;
      case PersonalQrScenario.delayedIssue:
        _viewState = PersonalQrViewState.initialLoading;
        _scheduleIssueResult();
      case PersonalQrScenario.sessionInvalid:
        _viewState = PersonalQrViewState.sessionInvalid;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSessionInvalid();
        });
    }
  }

  void _scheduleIssueResult() {
    final requestGeneration = ++_generation;
    _requestTimer?.cancel();
    _requestTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || requestGeneration != _generation) return;
      setState(() {
        _viewState = PersonalQrViewState.ready;
        _remainingSeconds = 600;
        _visualSeed++;
        _statusAnnouncement = '新的 Fake 二维码已生成';
      });
    });
  }

  void _invalidatePendingRequest() {
    _generation++;
    _requestTimer?.cancel();
    _requestTimer = null;
    _refreshInFlight = false;
  }

  void _refresh({bool forceNormalResult = false}) {
    if (_refreshInFlight || _viewState == PersonalQrViewState.sessionInvalid) {
      return;
    }
    _invalidatePendingRequest();
    _refreshInFlight = true;
    final requestGeneration = ++_generation;
    setState(() {
      _viewState = PersonalQrViewState.refreshing;
      _visualSeed++;
      _statusAnnouncement = '旧二维码已隐藏，正在刷新';
    });
    _requestTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted || requestGeneration != _generation) return;
      final resultScenario = forceNormalResult
          ? PersonalQrScenario.ready
          : _scenario;
      setState(() {
        _refreshInFlight = false;
        if (resultScenario == PersonalQrScenario.offline) {
          _viewState = PersonalQrViewState.offline;
          _statusAnnouncement = '刷新失败，当前无法联网';
        } else if (resultScenario == PersonalQrScenario.refreshError ||
            resultScenario == PersonalQrScenario.issueError) {
          _viewState = PersonalQrViewState.error;
          _statusAnnouncement = '刷新失败，旧码不会恢复';
        } else {
          _viewState = PersonalQrViewState.ready;
          _remainingSeconds = resultScenario == PersonalQrScenario.nearlyExpired
              ? 55
              : 600;
          _visualSeed++;
          _statusAnnouncement = '新的 Fake 二维码已生成';
        }
      });
    });
  }

  Future<void> _showScenarioPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          children: [
            const Text(
              '个人二维码 UI Mock 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '所有场景只切换本地状态，不会签发真实邀请码。',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 10),
            for (final scenario in PersonalQrScenario.values)
              ListTile(
                key: ValueKey('personal-qr-scenario-${scenario.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _scenarioLabel(scenario),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: scenario == _scenario
                    ? const Icon(Icons.check, color: _gold)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectScenario(scenario);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _selectScenario(PersonalQrScenario scenario) {
    _invalidatePendingRequest();
    setState(() {
      _scenario = scenario;
      _statusAnnouncement = null;
      _visualSeed++;
    });
    _applyInitialScenario();
    if (mounted) setState(() {});
  }

  String _scenarioLabel(PersonalQrScenario scenario) => switch (scenario) {
    PersonalQrScenario.ready => '正常 · 10 分钟',
    PersonalQrScenario.nearlyExpired => '即将过期 · 55 秒',
    PersonalQrScenario.expired => '已过期',
    PersonalQrScenario.offline => '离线 / 刷新失败',
    PersonalQrScenario.issueError => '首次生成失败',
    PersonalQrScenario.refreshError => '刷新失败且不恢复旧码',
    PersonalQrScenario.delayedIssue => '迟到签发响应',
    PersonalQrScenario.sessionInvalid => '会话失效',
  };

  Future<void> _showSessionInvalid() async {
    _invalidatePendingRequest();
    if (!mounted) return;
    setState(() {
      _viewState = PersonalQrViewState.sessionInvalid;
      _remainingSeconds = 0;
      _visualSeed++;
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('personal-qr-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('短期二维码和页面内存状态已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('personal-qr-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (widget.onSessionResetRequested != null) {
      widget.onSessionResetRequested!();
    } else {
      _finishBack();
    }
  }

  void _finishBack() {
    _invalidatePendingRequest();
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
}

class _QrCover extends StatelessWidget {
  const _QrCover({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F2),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == Icons.hourglass_top)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.black54,
                  ),
                )
              else
                Icon(icon, color: Colors.black54, size: 34),
              const SizedBox(height: 13),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({required this.onBack, required this.onTitleLongPress});

  final VoidCallback onBack;
  final VoidCallback onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('personal-qr-back'),
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFFC9B69E),
              size: 21,
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('personal-qr-title'),
              onLongPress: onTitleLongPress,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '我的二维码',
                    style: TextStyle(
                      color: Color(0xFFC9B69E),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
