import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../membership_wallet/presentation/asset_ledger_page.dart';
import 'edit_profile_page.dart';
import 'personal_qr_page.dart';
import 'settings_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    this.onOpenAssets,
    this.onOpenEditProfile,
    this.onOpenPersonalQr,
    this.onOpenSettings,
    this.onSessionResetRequested,
  });

  final ValueChanged<AssetLedgerType>? onOpenAssets;
  final Future<EditableProfileResult?> Function(
    String nickname,
    String signature,
  )?
  onOpenEditProfile;
  final VoidCallback? onOpenPersonalQr;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onSessionResetRequested;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  static const _warmWhite = Color(0xFFEAE3D8);
  static const _muted = Color(0xFFB7ADA0);
  int _selectedTab = 1;
  String _nickname = '杨嘉琪';
  String _signature = '';
  double _layoutWidth = 393;

  double get _legacyScale => _layoutWidth / 750;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final constrainedWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        _layoutWidth = math.min(
          constrainedWidth,
          MediaQuery.sizeOf(context).width,
        );
        return ColoredBox(
          color: Colors.black,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 118),
            child: Stack(
              children: [
                _buildCover(),
                _buildProfilePanel(),
                _buildTopTools(),
                _buildIdentity(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover() {
    final scale = _legacyScale;
    return SizedBox(
      key: const ValueKey('my-profile-cover'),
      height: 540 * scale,
      width: double.infinity,
      child: Image.asset(
        'assets/legacy/profile/my_profile_skyline_v1.png',
        fit: BoxFit.cover,
        alignment: const Alignment(-0.28, 0.28),
      ),
    );
  }

  Widget _buildTopTools() {
    final legacyScale = _legacyScale;
    final iconSize = 40 * legacyScale;
    final tapWidth = 80 * legacyScale;
    final tapHeight = 42 * legacyScale;
    return Positioned(
      left: 20 * legacyScale,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            key: const ValueKey('my-profile-top-tools'),
            padding: EdgeInsets.fromLTRB(
              20 * legacyScale,
              10 * legacyScale,
              10 * legacyScale,
              10 * legacyScale,
            ),
            decoration: BoxDecoration(
              color: const Color(0x50000000),
              borderRadius: BorderRadius.circular(30 * legacyScale),
            ),
            child: Row(
              children: [
                _assetTool(
                  key: const ValueKey('my-profile-qr'),
                  imageKey: const ValueKey('my-profile-qr-image'),
                  asset: 'menu_barcode.png',
                  label: '个人二维码',
                  iconSize: iconSize,
                  tapWidth: tapWidth,
                  tapHeight: tapHeight,
                  onTap: _showQr,
                ),
                _assetTool(
                  key: const ValueKey('my-profile-settings'),
                  imageKey: const ValueKey('my-profile-settings-image'),
                  asset: 'ic_setting.png',
                  label: '设置',
                  iconSize: iconSize,
                  tapWidth: tapWidth,
                  tapHeight: tapHeight,
                  onTap: _showSettings,
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xA6000000),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              key: const ValueKey('my-profile-exp'),
              borderRadius: BorderRadius.circular(22),
              onTap: _showLevel,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'EXP：0',
                  style: TextStyle(
                    color: _warmWhite,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetTool({
    required Key key,
    required Key imageKey,
    required String asset,
    required String label,
    required double iconSize,
    required double tapWidth,
    required double tapHeight,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        key: key,
        width: tapWidth,
        height: tapHeight,
        child: InkResponse(
          onTap: onTap,
          radius: tapWidth / 2,
          child: Center(
            child: Image.asset(
              'assets/legacy/profile/$asset',
              key: imageKey,
              width: iconSize,
              height: iconSize,
              color: _warmWhite,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentity() {
    final scale = _legacyScale;
    return Positioned(
      key: const ValueKey('my-profile-identity'),
      left: 50 * scale,
      right: 42 * scale,
      top: 400 * scale,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            key: const ValueKey('my-profile-empty-avatar'),
            width: 180 * scale,
            height: 180 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 10),
              ],
            ),
          ),
          SizedBox(width: 30 * scale),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, -10 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _nickname,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Image.asset(
                        'assets/legacy/profile/diamond2.png',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        '青铜 L-0',
                        style: TextStyle(
                          color: _warmWhite,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    key: const ValueKey('my-profile-copy-account'),
                    onTap: _copyFakeAccount,
                    child: Row(
                      children: [
                        const Text(
                          '账号：K45600000199',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Image.asset(
                          'assets/legacy/profile/copy.png',
                          width: 14,
                          height: 14,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePanel() {
    final scale = _legacyScale;
    return Container(
      key: const ValueKey('my-profile-panel'),
      margin: EdgeInsets.only(top: 540 * scale),
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height > 226
            ? MediaQuery.sizeOf(context).height - 226
            : 0,
      ),
      padding: EdgeInsets.fromLTRB(20 * scale, 60 * scale, 20 * scale, 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30 * scale)),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.12,
          colors: [Color(0xFF352F26), Color(0xFF0D0C0A), Colors.black],
          stops: [0, .48, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStats(),
          SizedBox(height: 26 * scale),
          _buildAssets(),
          if (_signature.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(_signature, style: const TextStyle(color: _warmWhite)),
          ],
          const SizedBox(height: 28),
          _buildTags(),
          const SizedBox(height: 26),
          _buildTabs(),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF27231E), height: 1),
          _buildTabContent(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final scale = _legacyScale;
    const stats = [('获赞', '0'), ('关注', '0'), ('互关', '0'), ('粉丝', '0')];
    return Row(
      children: [
        ...stats.map(
          (item) => SizedBox(
            width: 104 * scale,
            child: InkWell(
              key: ValueKey('my-profile-stat-${item.$1}'),
              onTap: () => _showEmptyList(item.$1),
              child: Column(
                children: [
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: _warmWhite,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 212 * scale,
          height: 70 * scale,
          child: FilledButton(
            key: const ValueKey('my-profile-edit'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B3329),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
            ),
            onPressed: _showEditProfile,
            child: const Text(
              '编辑主页',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        SizedBox(width: 24 * scale),
      ],
    );
  }

  Widget _buildAssets() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _assetChip('余额：¥ 0.00', null, '我的余额', AssetLedgerType.cashBalance),
        _assetChip('50', 'gold.png', '金币', AssetLedgerType.goldCoin),
        _assetChip('0', 'diamond.png', '钻石', AssetLedgerType.diamond),
      ],
    );
  }

  Widget _assetChip(
    String text,
    String? asset,
    String title,
    AssetLedgerType type,
  ) {
    return Material(
      color: const Color(0xA6000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey('my-profile-asset-$title'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showAsset(type),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (asset != null) ...[
                Image.asset(
                  'assets/legacy/profile/$asset',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTags() {
    const tags = ['♂ 24岁', '颜值：148', '河南省 · 安阳市', '巨蟹座', '单身', '木系灵根'];
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: const Color(0x80000000),
              child: Text(
                tag,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTabs() {
    const tabs = ['作品', '动态', '相册'];
    return Row(
      children: List.generate(tabs.length, (index) {
        final selected = index == _selectedTab;
        return InkWell(
          key: ValueKey('my-profile-tab-${tabs[index]}'),
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 28, 8),
            child: Row(
              children: [
                Text(
                  tabs[index],
                  style: TextStyle(
                    color: selected ? Colors.white : _muted,
                    fontSize: selected ? 17 : 14.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected && index == 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: _warmWhite,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      key: ValueKey('my-profile-content-$_selectedTab'),
      height: 260,
      width: double.infinity,
    );
  }

  void _copyFakeAccount() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('已复制 Fake 账号：K45600000199（未写入系统剪贴板）')),
      );
  }

  void _showQr() {
    if (widget.onOpenPersonalQr != null) {
      widget.onOpenPersonalQr!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonalQrPage(
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
  }

  void _showLevel() {
    _showSheet(
      title: '会员等级',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '青铜 L-0',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0,
            minHeight: 7,
            color: Color(0xFFC7AF8D),
            backgroundColor: Color(0xFF302A23),
          ),
          SizedBox(height: 10),
          Text('EXP 0 / 50', style: TextStyle(color: _muted)),
        ],
      ),
    );
  }

  void _showEmptyList(String title) {
    _showSheet(
      title: title,
      child: const SizedBox(
        height: 150,
        child: Center(
          child: Text('暂无内容', style: TextStyle(color: _muted)),
        ),
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

  void _showSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  Future<void> _showEditProfile() async {
    final result = widget.onOpenEditProfile != null
        ? await widget.onOpenEditProfile!(_nickname, _signature)
        : await Navigator.of(context).push<EditableProfileResult>(
            MaterialPageRoute<EditableProfileResult>(
              builder: (_) => EditProfilePage(
                nickname: _nickname,
                signature: _signature,
                onSessionResetRequested: widget.onSessionResetRequested,
              ),
            ),
          );
    if (result == null || !mounted) return;
    setState(() {
      _nickname = result.nickname;
      _signature = result.signature;
    });
  }

  void _showSheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171411),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
