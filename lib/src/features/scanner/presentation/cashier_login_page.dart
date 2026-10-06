import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../auth/domain/auth_repository.dart';
import '../../club/presentation/legacy_club_components.dart';
import '../data/cashier_login_repository.dart';

class CashierLoginPage extends StatefulWidget {
  const CashierLoginPage({
    super.key,
    required this.challengeId,
    required this.repository,
  });
  final String challengeId;
  final CashierLoginRepository repository;
  @override
  State<CashierLoginPage> createState() => _CashierLoginPageState();
}

class _CashierLoginPageState extends State<CashierLoginPage> {
  CashierLoginChallenge? _challenge;
  String? _store, _error, _terminal;
  bool _busy = true, _invalid = false, _uncertain = false;
  Timer? _expiry;
  StreamSubscription<void>? _session;

  bool get _expired =>
      _challenge != null && !DateTime.now().isBefore(_challenge!.expiresAt);
  bool get _pending =>
      !_invalid &&
      !_uncertain &&
      !_busy &&
      !_expired &&
      _terminal == null &&
      _challenge?.status == 'pending';

  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      setState(() {
        _invalid = true;
        _busy = false;
        _error = '登录状态已变化，请返回重新扫码';
      });
    });
    unawaited(_inspect());
  }

  Future<void> _inspect() async {
    if (_invalid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.inspect(widget.challengeId);
      if (!mounted || _invalid) return;
      _expiry?.cancel();
      setState(() {
        _challenge = result;
        _terminal = result.status == 'pending' ? null : result.status;
        _uncertain = false;
        if (!result.stores.any((s) => s.ref == _store)) {
          _store = result.stores.length == 1 ? result.stores.single.ref : null;
        }
      });
      final remaining = result.expiresAt.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _expiry = Timer(remaining, () {
          if (mounted) setState(() {});
        });
      }
    } on AuthFailure catch (e) {
      if (mounted && !_invalid) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && !_invalid) setState(() => _error = '暂时无法核对登录请求，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(bool approve) async {
    if (!_pending || (approve && _store == null)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = approve
          ? await widget.repository.approve(widget.challengeId, _store!)
          : await widget.repository.reject(widget.challengeId);
      if (!mounted || _invalid) return;
      setState(() => _terminal = status);
    } catch (_) {
      if (mounted && !_invalid) {
        setState(() {
          _uncertain = true;
          _error = '操作结果待核对，请查询结果后再继续';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _session?.cancel();
    super.dispose();
  }

  ButtonStyle get _primaryButtonStyle => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(kingControlHeight),
    backgroundColor: legacyGold,
    foregroundColor: const Color(0xFF24180A),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: LegacyClubScaffold(
      title: '登录 KING 收银台',
      showMockLabel: false,
      onBack: () {
        if (!_busy) Navigator.of(context).pop();
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Icon(
              Icons.desktop_windows_outlined,
              size: 64,
              color: legacyGold,
            ),
          ),
          if (_challenge != null) ...[
            Text(
              _challenge!.deviceLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: legacyGold,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            if (_terminal == null && !_expired) ...[
              const Text(
                '登录门店',
                style: TextStyle(color: legacyGold, fontSize: 16),
              ),
              for (final store in _challenge!.stores)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    store.name,
                    style: const TextStyle(color: legacyGold),
                  ),
                  leading: Icon(
                    _store == store.ref
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: legacyGold,
                  ),
                  onTap: _pending
                      ? () => setState(() => _store = store.ref)
                      : null,
                ),
              if (_challenge!.stores.isEmpty)
                const Text(
                  '你没有可登录的员工门店，请联系门店管理员授权',
                  style: TextStyle(color: legacyGold, height: 1.6),
                ),
            ],
          ],
          if (_terminal != null || _expired)
            Text(
              switch (_terminal) {
                'approved' => '收银台登录已确认',
                'rejected' => '已取消收银台登录',
                _ => '二维码已过期，请在收银台刷新后重新扫码',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: legacyGold,
                fontSize: 18,
                height: 1.6,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: legacyPink, height: 1.5),
              ),
            ),
          if (_busy)
            const Center(child: CircularProgressIndicator(color: legacyGold)),
          const SizedBox(height: 24),
          if (_terminal == null && !_expired && !_invalid) ...[
            FilledButton(
              key: const ValueKey('cashier-login-approve'),
              style: _primaryButtonStyle,
              onPressed: _pending && _store != null
                  ? () => _decide(true)
                  : null,
              child: const Text('确认登录'),
            ),
            TextButton(
              onPressed: _pending ? () => _decide(false) : null,
              child: const Text('取消登录'),
            ),
            if (_error != null)
              TextButton(
                onPressed: _busy ? null : _inspect,
                child: Text(_uncertain ? '查询操作结果' : '重新加载'),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                '确认后，该设备可使用你在所选门店的收银权限。请核对设备及门店。',
                style: TextStyle(
                  color: Color(0xFF958978),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ] else
            FilledButton(
              key: const ValueKey('cashier-login-done'),
              style: _primaryButtonStyle,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
        ],
      ),
    ),
  );
}
