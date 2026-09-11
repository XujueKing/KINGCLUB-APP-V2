import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../membership_wallet/presentation/asset_ledger_page.dart';
import '../data/profile_cover_store.dart';
import 'about_legal_page.dart';
import 'edit_profile_page.dart';
import 'personal_info_page.dart';
import 'personal_qr_page.dart';
import 'settings_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    this.onOpenAssets,
    this.onOpenEditProfile,
    this.onOpenPersonalInfo,
    this.onOpenPersonalQr,
    this.onOpenSettings,
    this.onOpenAbout,
    this.onOpenOrders,
    this.onSessionResetRequested,
    this.coverStore,
  });

  final ValueChanged<AssetLedgerType>? onOpenAssets;
  final Future<EditableProfileResult?> Function(
    String nickname,
    String signature,
    String coverAsset,
  )?
  onOpenEditProfile;
  final VoidCallback? onOpenPersonalInfo;
  final VoidCallback? onOpenPersonalQr;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAbout;

  // Kept for compatibility with the shell contract. Orders are reached from
  // the dedicated order flow, not from the legacy wallet dashboard.
  final VoidCallback? onOpenOrders;
  final VoidCallback? onSessionResetRequested;
  final ProfileCoverStore? coverStore;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  static const _gold = Color(0xFFC9B69E);
  static const _mutedGold = Color(0x99C9B69E);
  static const _assetRoot = 'assets/legacy/profile';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = math.min(
          constraints.maxWidth,
          MediaQuery.sizeOf(context).width,
        );
        final scale = viewportWidth / 750;
        final contentWidth = math.min(660 * scale, viewportWidth - 32);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final topInset = MediaQuery.paddingOf(context).top;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.62),
              radius: 0.96,
              colors: [Color(0xF52B271F), Color(0xFF100E0B), Colors.black],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SingleChildScrollView(
            key: const ValueKey('my-profile-wallet-scroll'),
            padding: EdgeInsets.only(bottom: 154 + bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: viewportWidth,
                minHeight: math.max(
                  0,
                  constraints.maxHeight - 154 - bottomInset,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: topInset),
                  SizedBox(
                    width: contentWidth,
                    height: 86,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          left: 22 * scale,
                          top: -5,
                          child: _topTool(
                            key: const ValueKey('my-profile-settings'),
                            semanticLabel: '设置',
                            asset: 'ic_setting.png',
                            visualSize: 42 * scale,
                            onTap: _showSettings,
                          ),
                        ),
                        Positioned(
                          top: 33,
                          child: Text(
                            '总余额 (￥)',
                            key: const ValueKey('my-profile-total-title'),
                            style: TextStyle(
                              color: _gold,
                              fontSize: 30 * scale,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _plainTap(
                    key: const ValueKey('my-profile-total-balance'),
                    onTap: () => _showAsset(AssetLedgerType.cashBalance),
                    child: Text(
                      '0.00',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 66 * scale,
                        fontWeight: FontWeight.w600,
                        height: 1.08,
                      ),
                    ),
                  ),
                  SizedBox(height: 28 * scale),
                  SizedBox(
                    width: contentWidth,
                    child: _splitRow(
                      dividerHeight: 25 * scale,
                      left: _accountSummary(
                        key: const ValueKey('my-profile-wallet-account'),
                        amount: '0.00',
                        label: '钱包账户(元)',
                        scale: scale,
                        onTap: () => _showAsset(AssetLedgerType.cashBalance),
                      ),
                      right: _accountSummary(
                        key: const ValueKey('my-profile-voucher-account'),
                        amount: '0.00',
                        label: '代金券账户(元)',
                        scale: scale,
                        onTap: () => _showAsset(AssetLedgerType.cashBalance),
                      ),
                    ),
                  ),
                  SizedBox(height: 38 * scale),
                  SizedBox(
                    width: contentWidth,
                    child: _splitRow(
                      dividerHeight: 25 * scale,
                      left: _currencySummary(
                        key: const ValueKey('my-profile-gold-account'),
                        asset: 'gold.png',
                        value: '200',
                        scale: scale,
                        onTap: () => _showAsset(AssetLedgerType.goldCoin),
                      ),
                      right: _currencySummary(
                        key: const ValueKey('my-profile-diamond-account'),
                        asset: 'diamond.png',
                        value: '0',
                        scale: scale,
                        onTap: () => _showAsset(AssetLedgerType.diamond),
                      ),
                    ),
                  ),
                  SizedBox(height: 55 * scale),
                  SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: [
                        _menuRow(
                          key: const ValueKey('my-profile-menu-qr'),
                          asset: 'menu_barcode.png',
                          label: '我的二维码',
                          scale: scale,
                          onTap: _showQr,
                        ),
                        _menuRow(
                          key: const ValueKey('my-profile-menu-info'),
                          asset: 'menu_my.png',
                          label: '我的个人信息',
                          scale: scale,
                          onTap: _showPersonalInfo,
                        ),
                        _menuRow(
                          key: const ValueKey('my-profile-menu-ledger'),
                          asset: 'menu_list.png',
                          label: '账单记录',
                          scale: scale,
                          onTap: () => _showAsset(AssetLedgerType.cashBalance),
                        ),
                        _menuRow(
                          key: const ValueKey('my-profile-menu-about'),
                          asset: 'menu_about.png',
                          label: '关于KINGBAR',
                          scale: scale,
                          onTap: _showAbout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topTool({
    required Key key,
    required String semanticLabel,
    required String asset,
    required double visualSize,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkResponse(
        key: key,
        onTap: onTap,
        radius: 24,
        highlightShape: BoxShape.circle,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Image.asset(
              '$_assetRoot/$asset',
              width: visualSize,
              height: visualSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _splitRow({
    required Widget left,
    required Widget right,
    required double dividerHeight,
  }) {
    return Row(
      children: [
        Expanded(child: left),
        Container(width: 1, height: dividerHeight, color: _gold),
        Expanded(child: right),
      ],
    );
  }

  Widget _accountSummary({
    required Key key,
    required String amount,
    required String label,
    required double scale,
    required VoidCallback onTap,
  }) {
    return _plainTap(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: TextStyle(
                color: _gold,
                fontSize: 36 * scale,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              label,
              style: TextStyle(
                color: _mutedGold,
                fontSize: 24 * scale,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currencySummary({
    required Key key,
    required String asset,
    required String value,
    required double scale,
    required VoidCallback onTap,
  }) {
    return _plainTap(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              '$_assetRoot/$asset',
              width: 36 * scale,
              height: 36 * scale,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 20 * scale),
            Text(
              value,
              style: TextStyle(
                color: _gold,
                fontSize: 36 * scale,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow({
    required Key key,
    required String asset,
    required String label,
    required double scale,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(50 * scale),
        splashColor: _gold.withValues(alpha: .08),
        highlightColor: _gold.withValues(alpha: .05),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 30 * scale,
              vertical: 19 * scale,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36 * scale,
                  height: 36 * scale,
                  child: Image.asset('$_assetRoot/$asset', fit: BoxFit.contain),
                ),
                SizedBox(width: 20 * scale),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _gold,
                      fontSize: 31 * scale,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Image.asset(
                  '$_assetRoot/next.png',
                  width: 12 * scale,
                  height: 19 * scale,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _plainTap({
    required Key key,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Semantics(
      button: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: child,
      ),
    );
  }

  void _showAsset(AssetLedgerType type) {
    if (widget.onOpenAssets != null) {
      widget.onOpenAssets!(type);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AssetLedgerPage(initialType: type),
      ),
    );
  }

  void _showQr() {
    if (widget.onOpenPersonalQr != null) {
      widget.onOpenPersonalQr!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PersonalQrPage(
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
  }

  void _showSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
      return;
    }
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _showPersonalInfo() {
    if (widget.onOpenPersonalInfo != null) {
      widget.onOpenPersonalInfo!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PersonalInfoPage()),
    );
  }

  void _showAbout() {
    if (widget.onOpenAbout != null) {
      widget.onOpenAbout!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AboutLegalPage(
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
  }
}
