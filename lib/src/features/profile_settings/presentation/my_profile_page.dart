import 'package:flutter/material.dart';

import 'edit_profile_page.dart';
import 'personal_qr_page.dart';
import 'settings_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  static const _warmWhite = Color(0xFFEAE3D8);
  static const _muted = Color(0xFFB7ADA0);
  int _selectedTab = 1;
  String _nickname = '杨嘉琪';
  String _signature = '';

  @override
  Widget build(BuildContext context) {
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
  }

  Widget _buildCover() {
    return SizedBox(
      height: 318,
      width: double.infinity,
      child: Image.asset(
        'assets/legacy/profile/my_profile_skyline_v1.png',
        fit: BoxFit.cover,
        alignment: const Alignment(-0.28, 0.28),
      ),
    );
  }

  Widget _buildTopTools() {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xA6000000),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _assetTool(
                  key: const ValueKey('my-profile-qr'),
                  asset: 'menu_barcode.png',
                  label: '个人二维码',
                  onTap: _showQr,
                ),
                const SizedBox(width: 13),
                _assetTool(
                  key: const ValueKey('my-profile-settings'),
                  asset: 'ic_setting.png',
                  label: '设置',
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
                    fontWeight: FontWeight.w700,
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
    required String asset,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: InkResponse(
        key: key,
        onTap: onTap,
        radius: 22,
        child: Image.asset(
          'assets/legacy/profile/$asset',
          width: 29,
          height: 29,
          color: _warmWhite,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildIdentity() {
    return Positioned(
      left: 28,
      right: 22,
      top: 238,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            key: const ValueKey('my-profile-empty-avatar'),
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
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
                            fontSize: 23,
                            height: 1,
                            fontWeight: FontWeight.w800,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                        const SizedBox(width: 5),
                        Image.asset(
                          'assets/legacy/profile/copy.png',
                          width: 14,
                          height: 14,
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
    return Container(
      margin: const EdgeInsets.only(top: 293),
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).height > 226
            ? MediaQuery.sizeOf(context).height - 226
            : 0,
      ),
      padding: const EdgeInsets.fromLTRB(22, 68, 22, 120),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        gradient: RadialGradient(
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
          const SizedBox(height: 25),
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
    const stats = [('获赞', '0'), ('关注', '0'), ('互关', '0'), ('粉丝', '0')];
    return Row(
      children: [
        ...stats.map(
          (item) => Expanded(
            child: InkWell(
              key: ValueKey('my-profile-stat-${item.$1}'),
              onTap: () => _showEmptyList(item.$1),
              child: Column(
                children: [
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: _warmWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 112,
          height: 42,
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
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssets() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _assetChip('余额：¥ 0.00', null, '我的余额'),
        _assetChip('50', 'gold.png', '金币'),
        _assetChip('0', 'diamond.png', '钻石'),
      ],
    );
  }

  Widget _assetChip(String text, String? asset, String title) {
    return Material(
      color: const Color(0xA6000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey('my-profile-asset-$title'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showAsset(title, text),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PersonalQrPage()));
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

  void _showAsset(String title, String value) {
    _showSheet(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '当前为离线 UI Mock，不会产生真实资产变化。',
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  Future<void> _showEditProfile() async {
    final result = await Navigator.of(context).push<EditableProfileResult>(
      MaterialPageRoute<EditableProfileResult>(
        builder: (_) =>
            EditProfilePage(nickname: _nickname, signature: _signature),
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
