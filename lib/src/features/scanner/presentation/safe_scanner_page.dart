import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_theme.dart';

enum SafeScanDestination {
  friendProfile('好友资料预览'),
  tableOrdering('桌台点单'),
  admissionContext('入场凭证');

  const SafeScanDestination(this.label);

  final String label;
}

enum SafeScannerDemoState {
  rationale,
  cameraActive,
  permissionDenied,
  permissionPermanentlyDenied,
  unsupported,
  expiredOrUsed,
  recoverableError,
  sessionInvalid,
}

enum _ScannerViewState {
  rationale,
  requestingPermission,
  cameraActive,
  capturedResolving,
  permissionDenied,
  permissionPermanentlyDenied,
  unsupported,
  expiredOrUsed,
  recoverableError,
  navigating,
  sessionInvalid,
}

enum _PermissionOutcome { allowed, denied, permanentlyDenied }

class SafeScannerPage extends StatefulWidget {
  const SafeScannerPage({
    super.key,
    required this.onClose,
    required this.onResolved,
    this.onSessionResetRequested,
    this.initialState = SafeScannerDemoState.rationale,
    this.fakeDelay = const Duration(milliseconds: 450),
  });

  final VoidCallback onClose;
  final ValueChanged<SafeScanDestination> onResolved;
  final VoidCallback? onSessionResetRequested;
  final SafeScannerDemoState initialState;
  final Duration fakeDelay;

  @override
  State<SafeScannerPage> createState() => _SafeScannerPageState();
}

class _SafeScannerPageState extends State<SafeScannerPage>
    with WidgetsBindingObserver {
  late _ScannerViewState _state;
  _PermissionOutcome _permissionOutcome = _PermissionOutcome.allowed;
  SafeScanDestination? _destination;
  bool _torchEnabled = false;
  bool _showTestScenarios = false;
  bool _cameraPaused = false;
  bool _requesting = false;
  bool _resolving = false;
  bool _closed = false;
  bool _navigationEmitted = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = _viewStateFor(widget.initialState);
  }

  @override
  void didUpdateWidget(covariant SafeScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialState != oldWidget.initialState) {
      _invalidateAttempt();
      _state = _viewStateFor(widget.initialState);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (_cameraPaused) setState(() => _cameraPaused = false);
      return;
    }
    if (_state == _ScannerViewState.cameraActive && !_cameraPaused) {
      setState(() {
        _cameraPaused = true;
        _torchEnabled = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invalidateAttempt();
    super.dispose();
  }

  _ScannerViewState _viewStateFor(
    SafeScannerDemoState state,
  ) => switch (state) {
    SafeScannerDemoState.rationale => _ScannerViewState.rationale,
    SafeScannerDemoState.cameraActive => _ScannerViewState.cameraActive,
    SafeScannerDemoState.permissionDenied => _ScannerViewState.permissionDenied,
    SafeScannerDemoState.permissionPermanentlyDenied =>
      _ScannerViewState.permissionPermanentlyDenied,
    SafeScannerDemoState.unsupported => _ScannerViewState.unsupported,
    SafeScannerDemoState.expiredOrUsed => _ScannerViewState.expiredOrUsed,
    SafeScannerDemoState.recoverableError => _ScannerViewState.recoverableError,
    SafeScannerDemoState.sessionInvalid => _ScannerViewState.sessionInvalid,
  };

  void _invalidateAttempt() {
    _generation += 1;
    _requesting = false;
    _resolving = false;
    _torchEnabled = false;
    _destination = null;
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _invalidateAttempt();
    widget.onClose();
  }

  Future<void> _requestPermission() async {
    if (_requesting || _closed) return;
    _requesting = true;
    final generation = ++_generation;
    setState(() => _state = _ScannerViewState.requestingPermission);
    await Future<void>.delayed(widget.fakeDelay);
    if (!mounted || _closed || generation != _generation) return;
    setState(() {
      _requesting = false;
      _state = switch (_permissionOutcome) {
        _PermissionOutcome.allowed => _ScannerViewState.cameraActive,
        _PermissionOutcome.denied => _ScannerViewState.permissionDenied,
        _PermissionOutcome.permanentlyDenied =>
          _ScannerViewState.permissionPermanentlyDenied,
      };
    });
  }

  Future<void> _resolve({
    SafeScanDestination? destination,
    _ScannerViewState? failure,
  }) async {
    if (_resolving || _closed || _cameraPaused) return;
    _resolving = true;
    final generation = ++_generation;
    setState(() {
      _torchEnabled = false;
      _destination = destination;
      _state = _ScannerViewState.capturedResolving;
    });
    await Future<void>.delayed(widget.fakeDelay);
    if (!mounted || _closed || generation != _generation) return;
    setState(() {
      _resolving = false;
      _state = destination == null
          ? (failure ?? _ScannerViewState.unsupported)
          : _ScannerViewState.navigating;
    });
  }

  void _resumeScanning() {
    _invalidateAttempt();
    setState(() {
      _state = _ScannerViewState.cameraActive;
      _cameraPaused = false;
      _navigationEmitted = false;
    });
  }

  void _emitResolved() {
    if (_navigationEmitted || _closed || _destination == null) return;
    _navigationEmitted = true;
    widget.onResolved(_destination!);
  }

  @override
  Widget build(BuildContext context) {
    final cameraActive = _state == _ScannerViewState.cameraActive;
    return Scaffold(
      backgroundColor: KingColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _close,
          tooltip: '关闭扫码',
          icon: const Icon(Icons.close),
        ),
        title: const Text('扫一扫'),
        actions: [
          IconButton(
            onPressed: cameraActive
                ? () => setState(() => _torchEnabled = !_torchEnabled)
                : null,
            tooltip: _torchEnabled ? '关闭手电筒' : '打开手电筒',
            icon: Icon(
              _torchEnabled ? Icons.flashlight_on : Icons.flashlight_off,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ScannerViewport(
                    state: _state,
                    torchEnabled: _torchEnabled,
                    destination: _destination,
                    cameraPaused: _cameraPaused,
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: _buildControls(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    switch (_state) {
      case _ScannerViewState.rationale:
        return _ControlPanel(
          key: const ValueKey('rationale'),
          eyebrow: '安全识别',
          title: '只识别 KingClub 可信场景',
          message: '扫码前会先说明用途。二维码原文不会展示、复制或写入日志。',
          primaryLabel: '开始扫码',
          onPrimary: _requestPermission,
          footer: _PermissionScenarioPicker(
            value: _permissionOutcome,
            onChanged: (value) => setState(() => _permissionOutcome = value),
          ),
        );
      case _ScannerViewState.requestingPermission:
        return const _ControlPanel(
          key: ValueKey('requesting'),
          eyebrow: '权限模拟',
          title: '正在请求相机权限…',
          message: '这是离线 UI 演示，不会调用系统权限或真实相机。',
          busy: true,
        );
      case _ScannerViewState.cameraActive:
        return _ControlPanel(
          key: const ValueKey('active'),
          eyebrow: 'FAKE CAMERA',
          title: '将二维码放入框内',
          message: '当前画面为模拟取景器。选择测试场景可验证安全分流和异常恢复。',
          footer: _ScenarioControls(
            expanded: _showTestScenarios,
            onToggle: () =>
                setState(() => _showTestScenarios = !_showTestScenarios),
            onDestination: (value) => _resolve(destination: value),
            onFailure: (value) => _resolve(failure: value),
          ),
        );
      case _ScannerViewState.capturedResolving:
        return const _ControlPanel(
          key: ValueKey('resolving'),
          eyebrow: '本地校验',
          title: '正在安全识别…',
          message: '取景已暂停，正在核对类型、有效期和允许的去向。',
          busy: true,
        );
      case _ScannerViewState.permissionDenied:
        return _ControlPanel(
          key: const ValueKey('denied'),
          eyebrow: '未获得权限',
          title: '暂时无法使用相机',
          message: '你可以再次请求权限，或关闭扫码回到原页面。',
          primaryLabel: '再次请求',
          onPrimary: () {
            _permissionOutcome = _PermissionOutcome.allowed;
            _requestPermission();
          },
          secondaryLabel: '返回原页面',
          onSecondary: _close,
        );
      case _ScannerViewState.permissionPermanentlyDenied:
        return _ControlPanel(
          key: const ValueKey('permanent-denied'),
          eyebrow: '权限已关闭',
          title: '请在系统设置中允许相机',
          message: '演示会模拟从系统设置返回；不会真的打开设置页。',
          primaryLabel: '模拟打开系统设置',
          onPrimary: () {
            _permissionOutcome = _PermissionOutcome.allowed;
            _requestPermission();
          },
          secondaryLabel: '返回原页面',
          onSecondary: _close,
        );
      case _ScannerViewState.unsupported:
        return _failurePanel(
          key: 'unsupported',
          eyebrow: '已安全拦截',
          title: '不支持此二维码',
          message: '仅支持好友资料、桌台点单和入场凭证。网页、支付及其他类型不会打开。',
        );
      case _ScannerViewState.expiredOrUsed:
        return _failurePanel(
          key: 'expired',
          eyebrow: '无法继续',
          title: '二维码已失效或已使用',
          message: '请让对方刷新二维码，或返回对应业务页面重新生成。',
        );
      case _ScannerViewState.recoverableError:
        return _failurePanel(
          key: 'recoverable',
          eyebrow: '网络异常',
          title: '暂时无法完成校验',
          message: '你的页面状态仍被保留，可以重试扫码或稍后再试。',
        );
      case _ScannerViewState.navigating:
        final destination = _destination!;
        return _ControlPanel(
          key: const ValueKey('navigating'),
          eyebrow: '识别成功',
          title: destination.label,
          message: '已生成受控页面意图，不携带二维码原文，也不会直接执行加好友、下单或核销。',
          primaryLabel: '进入${destination.label}',
          onPrimary: _emitResolved,
          secondaryLabel: '继续扫码',
          onSecondary: _resumeScanning,
        );
      case _ScannerViewState.sessionInvalid:
        return _ControlPanel(
          key: const ValueKey('session-invalid'),
          eyebrow: '会话已终止',
          title: '登录状态已失效',
          message: '扫码画面和本次识别内容已清理，请返回登录。',
          primaryLabel: '返回登录',
          onPrimary: widget.onSessionResetRequested ?? _close,
        );
    }
  }

  Widget _failurePanel({
    required String key,
    required String eyebrow,
    required String title,
    required String message,
  }) {
    return _ControlPanel(
      key: ValueKey(key),
      eyebrow: eyebrow,
      title: title,
      message: message,
      primaryLabel: '重新扫码',
      onPrimary: _resumeScanning,
      secondaryLabel: '返回原页面',
      onSecondary: _close,
    );
  }
}

class _ScannerViewport extends StatelessWidget {
  const _ScannerViewport({
    required this.state,
    required this.torchEnabled,
    required this.destination,
    required this.cameraPaused,
  });

  final _ScannerViewState state;
  final bool torchEnabled;
  final SafeScanDestination? destination;
  final bool cameraPaused;

  @override
  Widget build(BuildContext context) {
    final active = state == _ScannerViewState.cameraActive && !cameraPaused;
    final resolving = state == _ScannerViewState.capturedResolving;
    final success = state == _ScannerViewState.navigating;
    return AspectRatio(
      aspectRatio: 0.92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: torchEnabled
                  ? const [Color(0xFF514839), Color(0xFF1B1814)]
                  : const [Color(0xFF282621), Color(0xFF0C0B0A)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (active || resolving) ...[
                const _FakeCameraTexture(),
                Center(child: _ScanFrame(active: active)),
              ],
              if (!active || resolving)
                ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
              if (cameraPaused) const ColoredBox(color: Color(0xAA000000)),
              Center(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: switch (state) {
                    _ScannerViewState.rationale => const _ViewportMessage(
                      icon: Icons.security_outlined,
                      label: '安全扫码',
                    ),
                    _ScannerViewState.requestingPermission =>
                      const CircularProgressIndicator(),
                    _ScannerViewState.capturedResolving =>
                      const CircularProgressIndicator(),
                    _ScannerViewState.permissionDenied ||
                    _ScannerViewState.permissionPermanentlyDenied =>
                      const _ViewportMessage(
                        icon: Icons.no_photography_outlined,
                        label: '相机权限未开启',
                      ),
                    _ScannerViewState.unsupported => const _ViewportMessage(
                      icon: Icons.block_outlined,
                      label: '类型已拦截',
                    ),
                    _ScannerViewState.expiredOrUsed => const _ViewportMessage(
                      icon: Icons.timer_off_outlined,
                      label: '二维码已失效',
                    ),
                    _ScannerViewState.recoverableError =>
                      const _ViewportMessage(
                        icon: Icons.cloud_off_outlined,
                        label: '校验暂不可用',
                      ),
                    _ScannerViewState.sessionInvalid => const _ViewportMessage(
                      icon: Icons.lock_outline,
                      label: '会话已失效',
                    ),
                    _ScannerViewState.navigating => _ViewportMessage(
                      icon: Icons.verified_user_outlined,
                      label: destination!.label,
                      color: KingColors.success,
                    ),
                    _ScannerViewState.cameraActive =>
                      cameraPaused
                          ? const _ViewportMessage(
                              icon: Icons.pause_circle_outline,
                              label: '扫码已暂停',
                            )
                          : const SizedBox.shrink(),
                  },
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    success ? 'SAFE ROUTE INTENT' : 'OFFLINE UI MOCK',
                    style: const TextStyle(
                      color: KingColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeCameraTexture extends StatelessWidget {
  const _FakeCameraTexture();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: 54,
            child: Container(
              width: 210,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF6C5841),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: 72,
            child: Container(
              width: 180,
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFF3B3228),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.qr_code_2, size: 124, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      height: 236,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: active ? KingColors.brandStrong : KingColors.textDisabled,
          width: 2,
        ),
      ),
      child: active
          ? Align(
              alignment: const Alignment(0, -0.15),
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: KingColors.brandStrong,
              ),
            )
          : null,
    );
  }
}

class _ViewportMessage extends StatelessWidget {
  const _ViewportMessage({
    required this.icon,
    required this.label,
    this.color = KingColors.brandStrong,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(label),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 64),
        const SizedBox(height: 14),
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.footer,
    this.busy = false,
  });

  final String eyebrow;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? footer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: KingColors.brand, letterSpacing: 1.8),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          if (busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          if (primaryLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

class _PermissionScenarioPicker extends StatelessWidget {
  const _PermissionScenarioPicker({
    required this.value,
    required this.onChanged,
  });

  final _PermissionOutcome value;
  final ValueChanged<_PermissionOutcome> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('UI 测试权限'),
      subtitle: const Text('仅改变 Fake 状态'),
      children: [
        SegmentedButton<_PermissionOutcome>(
          segments: const [
            ButtonSegment(value: _PermissionOutcome.allowed, label: Text('允许')),
            ButtonSegment(value: _PermissionOutcome.denied, label: Text('暂拒')),
            ButtonSegment(
              value: _PermissionOutcome.permanentlyDenied,
              label: Text('关闭'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _ScenarioControls extends StatelessWidget {
  const _ScenarioControls({
    required this.expanded,
    required this.onToggle,
    required this.onDestination,
    required this.onFailure,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<SafeScanDestination> onDestination;
  final ValueChanged<_ScannerViewState> onFailure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onToggle,
          icon: Icon(expanded ? Icons.expand_less : Icons.science_outlined),
          label: Text(expanded ? '收起测试场景' : '展开 UI 测试场景'),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _scenarioChip(
                '好友资料',
                () => onDestination(SafeScanDestination.friendProfile),
              ),
              _scenarioChip(
                '桌台点单',
                () => onDestination(SafeScanDestination.tableOrdering),
              ),
              _scenarioChip(
                '入场凭证',
                () => onDestination(SafeScanDestination.admissionContext),
              ),
              _scenarioChip(
                '不支持/网页',
                () => onFailure(_ScannerViewState.unsupported),
              ),
              _scenarioChip(
                '过期/已使用',
                () => onFailure(_ScannerViewState.expiredOrUsed),
              ),
              _scenarioChip(
                '离线异常',
                () => onFailure(_ScannerViewState.recoverableError),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _scenarioChip(String label, VoidCallback onPressed) {
    return ActionChip(label: Text(label), onPressed: onPressed);
  }
}
