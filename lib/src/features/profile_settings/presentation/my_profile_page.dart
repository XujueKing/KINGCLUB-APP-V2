import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../membership_wallet/presentation/asset_ledger_page.dart';
import '../data/profile_cover_store.dart';
import 'edit_profile_page.dart';
import 'profile_image_ref.dart';
import 'personal_qr_page.dart';
import 'settings_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    this.onOpenAssets,
    this.onOpenEditProfile,
    this.onOpenPersonalQr,
    this.onOpenSettings,
    this.onOpenOrders,
    this.onOpenReservations,
    this.onSessionResetRequested,
    this.coverStore,
    this.reselectSignal = 0,
  });

  final ValueChanged<AssetLedgerType>? onOpenAssets;
  final Future<EditableProfileResult?> Function(
    String nickname,
    String signature,
    String coverAsset,
  )?
  onOpenEditProfile;
  final VoidCallback? onOpenPersonalQr;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenReservations;
  final VoidCallback? onSessionResetRequested;
  final ProfileCoverStore? coverStore;
  final int reselectSignal;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  static const _warmWhite = Color(0xFFEAE3D8);
  static const _muted = Color(0xFFB7ADA0);
  int _selectedTab = 0;
  final _scroll = ScrollController();
  final _pages = PageController();
  double _menuPinOffset = 300;
  String _nickname = '杨嘉琪';
  String _signature = '';
  String _coverAsset = kDefaultProfileCoverAsset;
  double _layoutWidth = 393;

  double get _legacyScale => _layoutWidth / 750;

  @override
  void initState() {
    super.initState();
    _loadSavedCover();
  }

  Future<void> _loadSavedCover() async {
    final store = widget.coverStore;
    if (store == null) return;
    try {
      final saved = await store.load();
      if (saved != null && mounted) setState(() => _coverAsset = saved);
    } catch (_) {
      // A missing or unreadable local cover safely falls back to the default.
    }
  }

  @override
  void didUpdateWidget(covariant MyProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal != widget.reselectSignal &&
        _scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  double get _collapseProgress {
    final distance = math.min(160.0, math.max(1.0, _menuPinOffset));
    final t = ((_offset - _menuPinOffset + distance) / distance).clamp(
      0.0,
      1.0,
    );
    return t * t * (3 - 2 * t);
  }

  Widget _fadeProfile(Widget child, String id) => AnimatedBuilder(
    animation: _scroll,
    child: child,
    builder: (context, child) {
      final opacity = 1 - _collapseProgress;
      return IgnorePointer(
        ignoring: opacity <= .01,
        child: ExcludeSemantics(
          excluding: opacity <= .01,
          child: Opacity(key: ValueKey(id), opacity: opacity, child: child),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _layoutWidth = math.min(
          constraints.maxWidth,
          MediaQuery.sizeOf(context).width,
        );
        final scale = _legacyScale;
        final toolbarHeight =
            MediaQuery.paddingOf(context).top +
            math.max(
              6 + 60 * scale,
              17 + MediaQuery.textScalerOf(context).scale(16),
            );
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final tabsHeight =
            24 * scale + math.max(32 * scale * textScale * 1.4, 28);
        return ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scroll,
                  child: _buildCover(),
                  builder: (context, cover) => CustomPaint(
                    painter: _ProfileBackground(400 * scale - _offset, scale),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: -_offset,
                          left: 0,
                          right: 0,
                          child: cover!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CustomScrollView(
                key: const PageStorageKey('my-profile-scroll'),
                controller: _scroll,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfilePinnedHeader(
                      height: toolbarHeight,
                      child: AnimatedBuilder(
                        animation: _scroll,
                        child: Stack(children: [_buildTopTools()]),
                        builder: (context, tools) {
                          final opacity = _collapseProgress;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Opacity(
                                opacity: math.max(
                                  opacity,
                                  (_offset /
                                          math.max(
                                            1,
                                            400 * scale - toolbarHeight,
                                          ))
                                      .clamp(0.0, 1.0),
                                ),
                                child: CustomPaint(
                                  painter: _ProfileBackground(
                                    400 * scale - _offset,
                                    scale,
                                  ),
                                ),
                              ),
                              tools!,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _fadeProfile(
                      Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: math.max(0, 400 * scale - toolbarHeight),
                            ),
                            child: _buildProfilePanel(),
                          ),
                          _buildIdentity(
                            top: math.max(0, 260 * scale - toolbarHeight),
                          ),
                        ],
                      ),
                      'my-profile-info-opacity',
                    ),
                  ),
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final naturalTop = constraints.precedingScrollExtent;
                      _menuPinOffset = naturalTop - toolbarHeight;
                      return SliverPersistentHeader(
                        pinned: true,
                        delegate: _ProfilePinnedHeader(
                          height: tabsHeight,
                          child: AnimatedBuilder(
                            animation: _scroll,
                            child: Container(
                              key: const ValueKey('my-profile-pinned-tabs'),
                              padding: EdgeInsets.symmetric(
                                horizontal: 40 * scale,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0x20FCE9D1),
                                    width: .5,
                                  ),
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: _buildTabs(),
                            ),
                            builder: (context, tabs) => CustomPaint(
                              painter: _ProfileBackground(
                                400 * scale -
                                    _offset -
                                    math.max(
                                      toolbarHeight,
                                      naturalTop - _offset,
                                    ),
                                scale,
                              ),
                              child: tabs,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: math.max(
                        260,
                        constraints.maxHeight - toolbarHeight - tabsHeight,
                      ),
                      child: _buildTabContent(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCover() {
    final scale = _legacyScale;
    return SizedBox(
      key: const ValueKey('my-profile-cover'),
      height: 400 * scale,
      width: double.infinity,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 430 * scale,
        maxHeight: 430 * scale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: profileImageProvider(_coverAsset),
              fit: BoxFit.cover,
              alignment: const Alignment(-0.28, 0.28),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xBB000000),
                  ],
                  stops: [0, .45, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTools() {
    final scale = _legacyScale;
    final height = math.max(32.0, 42 * scale);
    return Positioned(
      left: 20 * scale,
      right: 20 * scale,
      top: MediaQuery.paddingOf(context).top + 5,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: Container(
                key: const ValueKey('my-profile-top-tools'),
                color: Colors.transparent,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    _fadeProfile(
                      Row(
                        children: [
                          _assetTool(
                            key: const ValueKey('my-profile-qr'),
                            imageKey: const ValueKey('my-profile-qr-image'),
                            asset: 'menu_barcode.png',
                            label: '个人二维码',
                            iconSize: 40 * scale,
                            tapWidth: 80 * scale,
                            tapHeight: height,
                            onTap: _showQr,
                          ),
                          Flexible(
                            child: InkWell(
                              key: const ValueKey('my-profile-exp'),
                              onTap: _showLevel,
                              splashFactory: NoSplash.splashFactory,
                              highlightColor: Colors.transparent,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '经验值：0',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _warmWhite,
                                    fontSize: 12,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      'my-profile-exp-opacity',
                    ),
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _scroll,
                        builder: (context, _) => _collapseProgress == 0
                            ? const SizedBox.shrink()
                            : Opacity(
                                opacity: _collapseProgress,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 20 * scale),
                                  child: Text(
                                    _nickname,
                                    key: const ValueKey(
                                      'my-profile-collapsed-name',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _warmWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _assetTool(
              key: const ValueKey('my-profile-settings'),
              imageKey: const ValueKey('my-profile-settings-image'),
              asset: 'ic_setting.png',
              label: '设置',
              iconSize: 40 * scale,
              tapWidth: 80 * scale,
              tapHeight: height,
              onTap: _showSettings,
            ),
          ],
        ),
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
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
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

  Widget _buildIdentity({required double top}) {
    final scale = _legacyScale;
    return Positioned(
      key: const ValueKey('my-profile-identity'),
      left: 50 * scale,
      right: 42 * scale,
      top: top,
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
                        const Flexible(
                          child: Text(
                            '账号：K45600000199',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
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
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30 * scale)),
      child: CustomPaint(
        painter: _ProfileBackground(0, scale),
        child: Padding(
          key: const ValueKey('my-profile-panel'),
          padding: EdgeInsets.fromLTRB(
            40 * scale,
            70 * scale,
            40 * scale,
            20 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStats(),
              SizedBox(height: 26 * scale),
              _buildAssets(),
              SizedBox(height: 28 * scale),
              if (_signature.isNotEmpty)
                Text(
                  _signature,
                  style: TextStyle(color: _warmWhite, fontSize: 28 * scale),
                ),
              SizedBox(height: 30 * scale),
              _buildTags(),
              const SizedBox(height: 26),
              _buildServices(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final scale = _legacyScale;
    const stats = [('获赞', '0'), ('关注', '0'), ('互关', '0'), ('粉丝', '0')];
    final counts = Wrap(
      spacing: 24 * scale,
      runSpacing: 12 * scale,
      children: stats
          .map(
            (item) => InkWell(
              key: ValueKey('my-profile-stat-${item.$1}'),
              onTap: () => _showEmptyList(item.$1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Text(
                    item.$1,
                    style: TextStyle(
                      color: const Color(0xD2FCE9D1),
                      fontSize: 26 * scale,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
    final edit = TextButton(
      key: const ValueKey('my-profile-edit'),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0x307E6951),
        foregroundColor: Colors.white,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: 24 * scale,
          vertical: 12 * scale,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * scale),
        ),
      ),
      onPressed: _showEditProfile,
      child: Text(
        '编辑主页',
        style: TextStyle(fontSize: 26 * scale, fontWeight: FontWeight.w400),
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [counts, const SizedBox(height: 12), edit],
      );
    }
    return Row(
      children: [
        Expanded(child: counts),
        SizedBox(width: 24 * scale),
        edit,
      ],
    );
  }

  Widget _buildAssets() {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        _assetChip('余额：¥ 0.00', null, '我的余额', AssetLedgerType.cashBalance),
        _assetChip('50', 'gold.png', '金币', AssetLedgerType.goldCoin),
        _assetChip('0', 'diamond.png', '钻石', AssetLedgerType.diamond),
      ],
    );
  }

  Widget _buildServices() {
    Widget entry(String id, String label, String asset, VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            key: ValueKey('my-profile-$id'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/legacy/profile/$asset',
                    width: 30,
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                      _warmWhite,
                      BlendMode.srcIn,
                    ),
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _warmWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      key: const ValueKey('my-profile-services'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        entry(
          'bump',
          '初次碰碰',
          'service_bump.svg',
          () => _showSheet(
            title: '初次碰碰',
            child: const Text('功能暂未开放', style: TextStyle(color: _muted)),
          ),
        ),
        entry('orders', '我的订单', 'service_orders.svg', _showOrders),
        entry('reservations', '我的预约', 'service_reservations.svg', () {
          if (widget.onOpenReservations case final open?) {
            open();
          } else {
            _showEmptyList('我的预约');
          }
        }),
        entry('creator', '创作者中心', 'service_creator.svg', _showCreatorCenter),
        entry('support', '专属客服', 'service_support.svg', _showSupportCenter),
      ],
    );
  }

  void _showSupportCenter() {
    _showSheet(
      title: '专属客服',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('常见问题', style: TextStyle(color: _warmWhite, fontSize: 16)),
          SizedBox(height: 18),
          Text('在哪里查看过期储物？', style: TextStyle(color: _warmWhite)),
          SizedBox(height: 6),
          Text(
            '进入私人储物柜，点击右上角“过期储物”查看。',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          SizedBox(height: 18),
          Text('怎样更换主页封面？', style: TextStyle(color: _warmWhite)),
          SizedBox(height: 6),
          Text(
            '进入“编辑主页”，选择封面并保存。',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          SizedBox(height: 24),
          Text('人工客服暂未开放', style: TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }

  void _showCreatorCenter() {
    _showSheet(
      title: '创作者中心',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in [(0, '我的作品'), (2, '我的相册')])
            ListTile(
              title: Text(item.$2, style: const TextStyle(color: _warmWhite)),
              onTap: () {
                Navigator.pop(context);
                _pages.animateToPage(
                  item.$1,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
                _scroll.animateTo(
                  _menuPinOffset.clamp(0, _scroll.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _assetChip(
    String text,
    String? asset,
    String title,
    AssetLedgerType type,
  ) {
    final scale = _legacyScale;
    final radius = BorderRadius.circular(20 * scale);
    return Material(
      color: const Color(0x50000000),
      borderRadius: radius,
      child: InkWell(
        key: ValueKey('my-profile-asset-$title'),
        borderRadius: radius,
        onTap: () => _showAsset(type),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8 * scale,
            4 * scale,
            20 * scale,
            4 * scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (asset != null) ...[
                Image.asset(
                  'assets/legacy/profile/$asset',
                  width: 30 * scale,
                  height: 30 * scale,
                ),
                SizedBox(width: 16 * scale),
              ] else
                SizedBox(width: 16 * scale),
              Text(
                text,
                style: TextStyle(
                  color: _warmWhite,
                  fontSize: 28 * scale,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
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
      spacing: 14 * _legacyScale,
      runSpacing: 16 * _legacyScale,
      children: tags
          .map(
            (tag) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * _legacyScale,
                vertical: 6 * _legacyScale,
              ),
              color: const Color(0x30000000),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tag.startsWith('♂')) ...[
                    Image.asset(
                      'assets/legacy/profile/man5.png',
                      width: 20 * _legacyScale,
                      height: 22 * _legacyScale,
                    ),
                    SizedBox(width: 10 * _legacyScale),
                  ],
                  Text(
                    tag.replaceFirst('♂ ', ''),
                    style: TextStyle(
                      color: const Color(0xBBFCE9D1),
                      fontSize: 24 * _legacyScale,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
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
          onTap: () => _pages.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              4 * _legacyScale,
              32 * _legacyScale,
              4 * _legacyScale,
            ),
            child: Row(
              children: [
                Text(
                  tabs[index],
                  style: TextStyle(
                    color: selected ? Colors.white : _muted,
                    fontSize: (selected ? 32 : 28) * _legacyScale,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Image.asset(
                      'assets/legacy/profile/select.png',
                      key: ValueKey(
                        'my-profile-selected-tab-arrow-${tabs[index]}',
                      ),
                      color: _warmWhite,
                      width: 18 * _legacyScale,
                      height: 13 * _legacyScale,
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
    const empty = ['暂无作品', '暂无动态', '暂无相册内容'];
    return PageView.builder(
      key: const ValueKey('my-profile-pages'),
      controller: _pages,
      itemCount: empty.length,
      onPageChanged: (index) => setState(() => _selectedTab = index),
      itemBuilder: (context, index) => Align(
        key: ValueKey('my-profile-content-$index'),
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Text(
            empty[index],
            style: const TextStyle(color: Color(0x99FCE9D1), fontSize: 13),
          ),
        ),
      ),
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

  void _showOrders() {
    if (widget.onOpenOrders case final callback?) {
      callback();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('订单入口正在准备中，请稍后重试')));
  }

  Future<void> _showEditProfile() async {
    final result = widget.onOpenEditProfile != null
        ? await widget.onOpenEditProfile!(_nickname, _signature, _coverAsset)
        : await Navigator.of(context).push<EditableProfileResult>(
            MaterialPageRoute<EditableProfileResult>(
              builder: (_) => EditProfilePage(
                nickname: _nickname,
                signature: _signature,
                coverAsset: _coverAsset,
                onSessionResetRequested: widget.onSessionResetRequested,
              ),
            ),
          );
    if (result == null || !mounted) return;
    var nextCover = result.coverAsset;
    var coverSaveFailed = false;
    if (widget.coverStore case final store?
        when result.coverAsset != _coverAsset &&
            !result.coverAsset.startsWith('assets/')) {
      try {
        nextCover = await store.persist(result.coverAsset);
      } catch (_) {
        nextCover = _coverAsset;
        coverSaveFailed = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _nickname = result.nickname;
      _signature = result.signature;
      _coverAsset = nextCover;
    });
    if (coverSaveFailed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('封面保存失败，已保留原封面。')));
    }
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
                    icon: Image.asset(
                      'assets/legacy/profile/close.png',
                      width: 18,
                      height: 18,
                      color: _muted,
                    ),
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

/// Flutter performs the pinning in sliver layout, including scroll reversal.
class _ProfilePinnedHeader extends SliverPersistentHeaderDelegate {
  _ProfilePinnedHeader({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant _ProfilePinnedHeader oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}

/// One fixed-radius source gradient, shared by the body and opaque pinned bars.
class _ProfileBackground extends CustomPainter {
  const _ProfileBackground(this.panelTop, this.scale);
  final double panelTop;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Colors.black);
    final gradientRect = Rect.fromCircle(
      center: Offset(size.width / 2, panelTop),
      radius: 1000 * scale,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF362F24), Colors.black],
        ).createShader(gradientRect),
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileBackground oldDelegate) =>
      panelTop != oldDelegate.panelTop || scale != oldDelegate.scale;
}
