import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'legacy_club_components.dart';

enum AdmissionTicketScenario {
  readyToEnter,
  notYetAvailable,
  checkedIn,
  exitConfirmation,
  checkedOutReentryAllowed,
  ended,
  revoked,
  offline,
  privacyCovered,
}

class FakeAdmissionRef {
  const FakeAdmissionRef(this.opaqueId);

  final String opaqueId;
}

class AdmissionTicketPage extends StatefulWidget {
  const AdmissionTicketPage({
    super.key,
    required this.onBack,
    this.admissionRef,
  });

  final VoidCallback onBack;
  final FakeAdmissionRef? admissionRef;

  @override
  State<AdmissionTicketPage> createState() => _AdmissionTicketPageState();
}

class _AdmissionTicketPageState extends State<AdmissionTicketPage>
    with WidgetsBindingObserver {
  AdmissionTicketScenario _scenario = AdmissionTicketScenario.readyToEnter;
  AdmissionTicketScenario? _scenarioBeforePrivacyCover;
  Timer? _timer;
  int _seconds = 24;
  int _tokenVersion = 1;
  bool _exitSubmitting = false;
  late final _AdmissionTicketProjection _projection;

  bool get _showsQr => _scenario == AdmissionTicketScenario.readyToEnter;

  String get _fakeToken =>
      'KC-FAKE-ADMISSION-V$_tokenVersion-${_projection.tokenScope}-${_tokenVersion * 7919}';

  @override
  void initState() {
    super.initState();
    _projection = _projectionForRef(widget.admissionRef);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_showsQr || !mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds -= 1;
        } else {
          _seconds = 29;
          _tokenVersion += 1;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_scenario != AdmissionTicketScenario.privacyCovered) {
        _scenarioBeforePrivacyCover = _scenario;
        setState(() => _scenario = AdmissionTicketScenario.privacyCovered);
      }
    } else if (state == AppLifecycleState.resumed &&
        _scenario == AdmissionTicketScenario.privacyCovered &&
        _scenarioBeforePrivacyCover != null) {
      setState(() {
        _scenario = _scenarioBeforePrivacyCover!;
        _scenarioBeforePrivacyCover = null;
        _seconds = 24;
        _tokenVersion += 1;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12020C),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.54),
            radius: .9,
            colors: [Color(0xFF470F24), Color(0xFF12020C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 36),
                  children: [
                    _buildTicketCard(),
                    const SizedBox(height: 28),
                    _buildInstructions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 5,
            child: IconButton(
              tooltip: '返回',
              onPressed: widget.onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: legacyPink,
                size: 22,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('admission-ticket-title'),
            onLongPress: _showScenarioSheet,
            child: const Text(
              'POSITIONING CARD',
              style: TextStyle(
                color: legacyPink,
                fontSize: 14,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            right: 5,
            child: IconButton(
              key: const ValueKey('admission-help'),
              tooltip: '帮助',
              onPressed: _showHelp,
              icon: const Icon(Icons.help_outline_rounded, color: legacyPink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    return Container(
      key: const ValueKey('admission-ticket-card'),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const RadialGradient(
          center: Alignment(1, 1),
          radius: 1.1,
          colors: [Color(0xFFAD016A), Color(0xFF5A1E80)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _projection.zoneLabel,
            style: const TextStyle(
              color: legacyPink,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'POSITIONING CARD',
            style: TextStyle(color: legacyPink, fontSize: 11, letterSpacing: 2),
          ),
          const SizedBox(height: 7),
          Text(
            _projection.sessionTime,
            style: const TextStyle(color: legacyPink, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _StatusPill(scenario: _scenario),
          const SizedBox(height: 18),
          _buildCredentialArea(),
          const SizedBox(height: 18),
          Text(
            _projection.packageName,
            style: const TextStyle(
              color: legacyPink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _secondaryCopy,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xCCFBAFDA),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (_scenario == AdmissionTicketScenario.exitConfirmation) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('confirm-ticket-exit'),
                onPressed: _exitSubmitting ? null : _confirmExit,
                style: FilledButton.styleFrom(
                  backgroundColor: legacyPink,
                  foregroundColor: const Color(0xFF351526),
                ),
                child: Text(_exitSubmitting ? '正在确认…' : '确认登记离场'),
              ),
            ),
          ],
          if (_scenario ==
              AdmissionTicketScenario.checkedOutReentryAllowed) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('ticket-reenter'),
                onPressed: _startReentry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: legacyPink,
                  side: const BorderSide(color: legacyPink),
                ),
                child: const Text('生成新的再次入场码'),
              ),
            ),
          ],
          if (_scenario == AdmissionTicketScenario.offline ||
              _scenario == AdmissionTicketScenario.revoked) ...[
            const SizedBox(height: 18),
            TextButton.icon(
              key: const ValueKey('ticket-assistance'),
              onPressed: _showAssistance,
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('请工作人员协助'),
              style: TextButton.styleFrom(foregroundColor: legacyPink),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCredentialArea() {
    if (_showsQr) {
      return Semantics(
        label: '动态入场二维码，$_seconds 秒后更新，请向工作人员出示',
        image: true,
        child: Column(
          children: [
            Container(
              width: 226,
              height: 226,
              padding: const EdgeInsets.all(13),
              color: legacyPink,
              child: QrImageView(
                key: ValueKey(
                  'admission-qr-${_projection.tokenScope}-v$_tokenVersion',
                ),
                data: _fakeToken,
                version: QrVersions.auto,
                backgroundColor: legacyPink,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '00:${_seconds.toString().padLeft(2, '0')} 后更新',
              style: const TextStyle(color: legacyPink, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final icon = switch (_scenario) {
      AdmissionTicketScenario.checkedIn => Icons.verified_rounded,
      AdmissionTicketScenario.ended => Icons.event_busy_rounded,
      AdmissionTicketScenario.revoked => Icons.block_rounded,
      AdmissionTicketScenario.offline => Icons.cloud_off_rounded,
      AdmissionTicketScenario.privacyCovered => Icons.visibility_off_rounded,
      AdmissionTicketScenario.exitConfirmation => Icons.logout_rounded,
      _ => Icons.schedule_rounded,
    };
    return Container(
      key: const ValueKey('admission-qr-covered'),
      width: 226,
      height: 226,
      color: const Color(0xCC2A1730),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: legacyPink, size: 54),
              const SizedBox(height: 13),
              Text(
                _coveredLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: legacyPink,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
          if (_scenario == AdmissionTicketScenario.checkedIn)
            Transform.rotate(
              angle: -.13,
              child: Container(
                key: const ValueKey('admission-checked-in-stamp'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xDDFFFFFF),
                  border: Border.all(color: const Color(0xFFFF0D66), width: 3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '已入场',
                  style: TextStyle(
                    color: Color(0xFFFF0D66),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _secondaryCopy => switch (_scenario) {
    AdmissionTicketScenario.readyToEnter => '请向工作人员出示动态码，请勿截图、保存或分享',
    AdmissionTicketScenario.notYetAvailable => '凭证将在 20:15 开放，请稍后再来',
    AdmissionTicketScenario.checkedIn => '已于 21:03 入场；离场需要扫描场内离场码',
    AdmissionTicketScenario.exitConfirmation => '已识别有效场内离场上下文，请确认是否登记离场',
    AdmissionTicketScenario.checkedOutReentryAllowed => '已登记离场；场馆规则允许重新生成一次入场码',
    AdmissionTicketScenario.ended => '本场活动已结束，凭证只读留存',
    AdmissionTicketScenario.revoked => '订单或资格状态发生变化，当前凭证已撤销',
    AdmissionTicketScenario.offline => '离线状态不生成长期备用码，也不会延长旧码',
    AdmissionTicketScenario.privacyCovered => 'App 已进入后台或检测到投屏，敏感区域已遮盖',
  };

  String get _coveredLabel => switch (_scenario) {
    AdmissionTicketScenario.notYetAvailable => '20:15 开放',
    AdmissionTicketScenario.checkedIn => '',
    AdmissionTicketScenario.exitConfirmation => '等待确认离场',
    AdmissionTicketScenario.ended => '本场已结束',
    AdmissionTicketScenario.revoked => '凭证已撤销',
    AdmissionTicketScenario.offline => '当前离线\n无法生成凭证',
    AdmissionTicketScenario.privacyCovered => '隐私保护中',
    _ => '凭证暂不可用',
  };

  Widget _buildInstructions() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADMISSION INSTRUCTIONS:',
            style: TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 9),
          Text('1、入场凭证仅限本人和本场次使用；', style: _ruleStyle),
          Text('2、请由工作人员扫码核验，消费者不能自行完成入场；', style: _ruleStyle),
          Text('3、二维码会自动轮换，请勿截图、保存或分享；', style: _ruleStyle),
          Text('4、离线、投屏或凭证异常时，请工作人员协助核验。', style: _ruleStyle),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1018),
        title: const Text('确认登记离场？'),
        content: const Text(
          '确认后当前入场状态会变为已离场。再次入场仍需重新生成全新凭证。',
          style: TextStyle(color: Color(0xFFD8C8D0), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-ticket-exit-dialog'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认离场'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _exitSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() {
      _exitSubmitting = false;
      _scenario = AdmissionTicketScenario.checkedOutReentryAllowed;
    });
    showFakeResult(context, '已登记 Fake 离场状态');
  }

  void _startReentry() {
    setState(() {
      _scenario = AdmissionTicketScenario.readyToEnter;
      _seconds = 29;
      _tokenVersion += 1;
    });
    showFakeResult(context, '已签发全新 Fake 再次入场码');
  }

  Future<void> _showHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1018),
      title: const Text('入场凭证帮助'),
      content: const Text(
        '请把动态二维码直接出示给现场工作人员。不要截图或转发；离线、凭证撤销或识别失败时，请工作人员使用受控方式协助核验。',
        style: TextStyle(color: Color(0xFFD8C8D0), height: 1.55),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  void _showAssistance() => showFakeResult(context, '已打开工作人员协助说明');

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<AdmissionTicketScenario>(
      context: context,
      backgroundColor: const Color(0xFF1A1018),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  '入场凭证 Fake 状态',
                  style: TextStyle(
                    color: legacyPink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final option in AdmissionTicketScenario.values)
                ListTile(
                  key: ValueKey('ticket-scenario-${option.name}'),
                  title: Text(
                    _scenarioName(option),
                    style: const TextStyle(color: Color(0xFFD8C8D0)),
                  ),
                  trailing: Icon(
                    option == _scenario
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == _scenario
                        ? legacyPink
                        : const Color(0x668E7E70),
                  ),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      _seconds = 24;
      if (_showsQr) _tokenVersion += 1;
    });
  }

  String _scenarioName(AdmissionTicketScenario value) => switch (value) {
    AdmissionTicketScenario.readyToEnter => '可入场 / 动态码',
    AdmissionTicketScenario.notYetAvailable => '未到开放时间',
    AdmissionTicketScenario.checkedIn => '已入场',
    AdmissionTicketScenario.exitConfirmation => '确认离场',
    AdmissionTicketScenario.checkedOutReentryAllowed => '已离场 / 可再次入场',
    AdmissionTicketScenario.ended => '活动已结束',
    AdmissionTicketScenario.revoked => '凭证已撤销',
    AdmissionTicketScenario.offline => '离线协助',
    AdmissionTicketScenario.privacyCovered => '隐私遮盖',
  };
}

const _ruleStyle = TextStyle(
  color: Color(0x88FFFFFF),
  fontSize: 12,
  height: 1.75,
);

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.scenario});
  final AdmissionTicketScenario scenario;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (scenario) {
      AdmissionTicketScenario.readyToEnter => (
        '当前可入场',
        const Color(0xFFBFF5D2),
      ),
      AdmissionTicketScenario.notYetAvailable => ('凭证未开放', legacyGold),
      AdmissionTicketScenario.checkedIn => ('已入场', const Color(0xFFBFF5D2)),
      AdmissionTicketScenario.exitConfirmation => ('待确认离场', legacyGold),
      AdmissionTicketScenario.checkedOutReentryAllowed => ('已离场', legacyGold),
      AdmissionTicketScenario.ended => ('已结束', const Color(0xFFBBBBBB)),
      AdmissionTicketScenario.revoked => ('已撤销', const Color(0xFFFFA0A0)),
      AdmissionTicketScenario.offline => ('离线', legacyGold),
      AdmissionTicketScenario.privacyCovered => ('已遮盖', legacyGold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x44000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AdmissionTicketProjection {
  const _AdmissionTicketProjection({
    required this.zoneLabel,
    required this.sessionTime,
    required this.packageName,
    required this.tokenScope,
  });

  final String zoneLabel;
  final String sessionTime;
  final String packageName;
  final String tokenScope;
}

const _defaultAdmissionProjection = _AdmissionTicketProjection(
  zoneLabel: 'VIP 区 V8',
  sessionTime: '08月27日 20:30 - 次日04:00',
  packageName: '星光香槟套餐',
  tokenScope: '20260827-V8',
);

const _a6AdmissionProjection = _AdmissionTicketProjection(
  zoneLabel: 'VIP 区 A6',
  sessionTime: '08月28日 20:30 - 次日04:00',
  packageName: '星光香槟套餐',
  tokenScope: '20260828-A6',
);

_AdmissionTicketProjection _projectionForRef(FakeAdmissionRef? ref) {
  if (ref?.opaqueId.contains('vip-a6') ?? false) {
    return _a6AdmissionProjection;
  }
  return _defaultAdmissionProjection;
}
