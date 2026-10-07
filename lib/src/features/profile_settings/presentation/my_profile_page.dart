import '../../partners/presentation/partner_platform_page.dart';
import '../../partners/presentation/partner_strings.dart';
import '../../partners/data/partner_repository.dart';
import '../../../core/session/secure_session_store.dart';
import '../../commerce/presentation/member_orders_page.dart';
import 'favourite_store_page.dart';
import '../../home/data/home_content_repository.dart';
import '../../home/presentation/home_content_cards.dart';

import 'package:kingclub/src/core/formatters/money.dart';
import 'package:kingclub/src/core/design_system/king_notice.dart';

import 'dart:async';

import '../../../core/session/member_qr_memory.dart';

import 'package:flutter/services.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../data/profile_repository.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../membership_wallet/presentation/asset_ledger_page.dart';
import '../../membership_wallet/presentation/member_balance_page.dart';
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
    this.active = true,
    this.partnerCall,
    this.partnerApprovalUnread = false,
    this.onPartnerViewed,
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
  final bool active;
  final PartnerCall? partnerCall;
  final bool partnerApprovalUnread;
  final VoidCallback? onPartnerViewed;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  static const _warmWhite = Color(0xFFEAE3D8);
  static const _muted = Color(0xFFB7ADA0);
  final ProfileRepository? _repository = kingclubApiBaseUrl.isEmpty
      ? null
      : ProfileRepository();
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _merchantStores = [];
  StreamSubscription<void>? _merchantSession;
  int _merchantEpoch = 0;
  Future<void> _loadMerchantStores() async {
    final call =
        widget.partnerCall ??
        (_repository == null ? null : PartnerRepository().call);
    if (call == null) return;
    final generation = ++_merchantEpoch;
    try {
      final r = await call({'action': 'context'});
      final stores = (r['stores'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (mounted && generation == _merchantEpoch) {
        setState(() => _merchantStores = stores);
      }
    } catch (_) {
      if (mounted && generation == _merchantEpoch) {
        setState(() => _merchantStores = []);
      }
    }
  }

  final Map<int, Future<Map<String, dynamic>>> _contentPages = {};
  String? _avatarPath;
  bool _profileLoading = false;
  String? _profileError;
  int _selectedTab = 1;
  final _scroll = ScrollController();
  final _pages = PageController(initialPage: 1);
  double _menuPinOffset = 300;
  String _nickname = '杨嘉琪';
  String _signature = '';
  String _coverAsset = kDefaultProfileCoverAsset;
  double _layoutWidth = 393;

  double get _legacyScale => _layoutWidth / 750;

  @override
  void initState() {
    super.initState();
    ProfileRepository.changes.addListener(_loadProfile);
    _loadMerchantStores();
    _merchantSession = SecureSessionStore.changes.stream.listen((_) {
      _merchantEpoch++;
      if (mounted) {
        setState(() => _merchantStores = []);
        _loadMerchantStores();
      }
    });
    if (_repository == null) {
      _loadSavedCover();
    } else {
      _nickname = '';
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (_repository == null || _profileLoading) return;
    _profileLoading = true;
    try {
      final p = await _repository.load();
      unawaited(
        _repository.memberQr().then<void>((_) {}, onError: (Object _) {}),
      );
      _contentPages.clear();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nickname = p['nickname'] as String;
        _signature = p['bio'] as String;
        _profileError = null;
      });
      final images = await Future.wait([
        _repository.image(p['avatar'] as Map?),
        _repository.image(p['cover'] as Map?),
      ]);
      if (mounted) MemberQrMemory.avatar = images[0];
      if (!mounted) return;
      setState(() {
        _avatarPath = images[0]?.path;
        _coverAsset = images[1]?.path ?? kDefaultProfileCoverAsset;
      });
    } catch (_) {
      if (mounted) setState(() => _profileError = '资料加载失败，点击重试');
    } finally {
      _profileLoading = false;
    }
  }

  String _field(String key, String preview) =>
      _repository == null ? preview : '${_profile?[key] ?? '—'}';
  String _value(String group, String key, String preview) => _repository == null
      ? preview
      : '${(_profile?[group] as Map?)?[key] ?? '—'}';

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
    if (widget.active && !oldWidget.active) _loadMerchantStores();
    if (widget.active && !oldWidget.active && _repository != null) {
      _loadProfile();
    }
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
    _merchantEpoch++;
    _merchantSession?.cancel();
    ProfileRepository.changes.removeListener(_loadProfile);
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
              math.max(49, 6 + 60 * scale),
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
                  builder: (context, cover) => CustomPaint(
                    painter: _ProfileBackground(400 * scale - _offset, scale),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: -math.max(0.0, _offset),
                          left: 0,
                          right: 0,
                          child: _buildCover(stretch: math.max(0.0, -_offset)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CustomScrollView(
                key: const PageStorageKey('my-profile-scroll'),
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
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

  Widget _buildCover({double stretch = 0}) {
    final scale = _legacyScale;
    return SizedBox(
      key: const ValueKey('my-profile-cover'),
      height: 400 * scale + stretch,
      width: double.infinity,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 430 * scale + stretch,
        maxHeight: 430 * scale + stretch,
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
    final height = math.max(44.0, 42 * scale);
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '经验值：${_field('experience', '0')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFC9B69E),
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
              image: _avatarPath == null
                  ? null
                  : DecorationImage(
                      image: profileImageProvider(_avatarPath!),
                      fit: BoxFit.cover,
                    ),

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
                      SizedBox(width: 18 * scale),
                      ClipPath(
                        clipper: _LevelBadgeClipper(14 * scale),
                        child: Container(
                          key: const ValueKey('my-profile-level-badge'),
                          height: 26 * scale,
                          color: const Color(0xFF362F24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/legacy/profile/diamond2.png',
                                width: 32 * scale,
                                height: 28 * scale,
                              ),
                              SizedBox(width: 6 * scale),
                              Text(
                                _field('levelName', '青铜 L-0'),
                                style: TextStyle(
                                  color: const Color(0xFFC9B69E),
                                  fontSize: 18 * scale,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              SizedBox(width: 14 * scale),
                            ],
                          ),
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
                        Flexible(
                          child: Text(
                            '账号：${_field('memberId', 'K45600000199')}',
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
            16 * scale,
            70 * scale,
            16 * scale,
            10 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_repository != null &&
                        (_profileError != null || _profile == null))
                      GestureDetector(
                        onTap: _loadProfile,
                        child: Text(
                          _profileError ?? '正在加载资料…',
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    _buildStats(),
                    SizedBox(height: 20 * scale),
                    Transform.translate(
                      offset: const Offset(-2, 0),
                      child: _buildAssets(),
                    ),
                    SizedBox(height: 20 * scale),
                    InkWell(
                      key: const ValueKey('my-profile-mood'),
                      onTap: _showEditProfile,
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _signature.isEmpty ? '写下此刻的心情…' : _signature,
                          style: TextStyle(
                            color: _signature.isEmpty ? _muted : _warmWhite,
                            fontSize: 28 * scale,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20 * scale),
                    _buildTags(),
                  ],
                ),
              ),
              SizedBox(height: 18 * scale + 6),
              _buildServices(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final scale = _legacyScale;
    final stats = [
      ('获赞', _value('stats', 'praises', '0')),
      ('关注', _value('stats', 'following', '0')),
      ('互关', _value('stats', 'mutual', '0')),
      ('粉丝', _value('stats', 'fans', '0')),
    ];
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
        _assetChip(
          '余额：¥ ${groupMoney(_value('assets', 'cashBalance', '0.00'))}',
          null,
          '我的余额',
          AssetLedgerType.cashBalance,
        ),
        _assetChip(
          _value('assets', 'goldCoin', '50'),
          'gold.png',
          '金币',
          AssetLedgerType.goldCoin,
        ),
        _assetChip(
          _value('assets', 'diamond', '0'),
          'diamond.png',
          '钻石',
          AssetLedgerType.diamond,
        ),
      ],
    );
  }

  Widget _buildServices() => LayoutBuilder(
    builder: (context, constraints) {
      Widget entry(String id, String label, String asset, VoidCallback onTap) =>
          SizedBox(
            width: constraints.maxWidth / 5,
            child: InkWell(
              key: ValueKey('my-profile-$id'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SvgPicture.asset(
                          'assets/legacy/profile/$asset',
                          width: 26,
                          height: 26,
                          colorFilter: const ColorFilter.mode(
                            _muted,
                            BlendMode.srcIn,
                          ),
                          fit: BoxFit.contain,
                        ),
                        if (id == 'partner' && widget.partnerApprovalUnread)
                          Positioned(
                            top: -3,
                            right: -4,
                            child: Container(
                              key: const ValueKey(
                                'my-profile-partner-unread-dot',
                              ),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE84848),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: MediaQuery.textScalerOf(context).scale(1) <= 1.3
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11.5,
                                  height: 1.15,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            )
                          : Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                                height: 1.15,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
      return _ProfileServiceStrip(
        revealMerchant: _merchantStores.isNotEmpty,
        child: Row(
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
            entry(
              'stored-value',
              '我的储值',
              'service_stored_value.svg',
              _showStoreCards,
            ),
            entry(
              'partner',
              partnerText(context, 'title'),
              'service_partner.svg',
              _showPartnerPlatform,
            ),
            if (_merchantStores.isNotEmpty)
              entry(
                'merchant',
                partnerText(context, 'merchant'),
                'service_merchant.svg',
                () => openMerchantPlatform(
                  context,
                  _merchantStores,
                  call: widget.partnerCall,
                ),
              ),
          ],
        ),
      );
    },
  );

  void _showPartnerPlatform() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartnerPlatformPage(
          call: widget.partnerCall,
          onViewed: widget.onPartnerViewed,
        ),
      ),
    );
  }

  void _showStoreCards() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MemberBalancePage(storeCardsOnly: true),
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
                  fontSize: 26 * scale,
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
    final tags = _repository == null
        ? ['♂ 24岁', '颜值：148', '河南省 · 安阳市', '巨蟹座', '单身', '木系灵根']
        : <String>[
            if (_profile?['age'] != null)
              '${_profile?['gender'] == 1
                  ? '♂ '
                  : _profile?['gender'] == 2
                  ? '♀ '
                  : ''}${_profile!['age']}岁',
            if (_profile?['appearanceScore'] != null)
              '颜值：${_profile!['appearanceScore']}',
            if (_profile?['locationCity'] != null)
              '${_profile!['locationCity']}',
            if (_profile?['zodiac'] != null) '${_profile!['zodiac']}',
            if ((_profile?['details'] as Map?)?['relationship'] != null)
              '${(_profile!['details'] as Map)['relationship']}',
            if (_profile?['element'] != null) '${_profile!['element']}系灵根',
          ];
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
    const tabs = ['作品', '动态', '相册', '收藏', '喜欢'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
                48 * _legacyScale,
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
      ),
    );
  }

  Widget _buildTabContent() {
    const empty = ['暂无作品', '暂无动态', '暂无相册内容', '暂无收藏', '暂无喜欢的作品'];
    return PageView.builder(
      key: const ValueKey('my-profile-pages'),
      controller: _pages,
      itemCount: empty.length,
      onPageChanged: (index) => setState(() => _selectedTab = index),
      itemBuilder: (context, index) => _repository != null
          ? _realContent(index)
          : Align(
              key: ValueKey('my-profile-content-$index'),
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 70),
                child: Text(
                  empty[index],
                  style: const TextStyle(
                    color: Color(0x99FCE9D1),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _realContent(int index) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _contentPages.putIfAbsent(
        index,
        () => _repository!.content(
          ['work', 'post', 'album', 'favorites', 'likes'][index],
          0,
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _contentPages.remove(index)),
              child: const Text('加载失败，点击重试'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final items = snapshot.data!['items'] as List;
        if (items.isEmpty) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 70),
              child: Text(
                ['暂无作品', '暂无动态', '暂无相册内容', '暂无收藏', '暂无喜欢的作品'][index],
                style: const TextStyle(color: Color(0x99FCE9D1), fontSize: 13),
              ),
            ),
          );
        }
        if (index == 3) {
          return ListView.builder(
            padding: const EdgeInsets.only(top: 16),
            itemCount: items.length,
            itemBuilder: (context, i) => FavouriteStoreCard(
              store: items[i] as Map,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FavouriteStorePage(
                    store: items[i] as Map,
                    repository: _repository!,
                  ),
                ),
              ),
            ),
          );
        }
        if (index == 4) {
          return GridView.builder(
            padding: const EdgeInsets.only(top: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: .75,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final content = HomeContent.parse(items[i]);
              return InkWell(
                onTap: () async {
                  await openHomeContent(context, content, (value) async {
                    final result = await HomeContentRepository.secure(
                      kingclubApiBaseUrl,
                    ).like(value, !value.liked, null);
                    value.liked = result.liked;
                    value.likeCount = result.count;
                  });
                  if (mounted) setState(() => _contentPages.remove(4));
                },
                child: HomeContentImage(content: content),
              );
            },
          );
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: .75,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => FutureBuilder(
            future: _repository!.image(items[i]['media'] as Map?),
            builder: (context, image) {
              if (image.data == null) return const SizedBox();
              return Image(
                image: profileImageProvider(image.data!.path),
                fit: BoxFit.cover,
              );
            },
          ),
        );
      },
    );
  }

  void _copyFakeAccount() {
    if (_repository != null) {
      final id = _profile?['memberId'];
      if (id != null) {
        Clipboard.setData(ClipboardData(text: '$id'));
        KingNotice.of(context)
            .showSnackBar(const SnackBar(content: Text('账号已复制')));
      }
      return;
    }
    KingNotice.of(context)
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
        allowSnapshotting: false,
        builder: (_) => PersonalQrPage(
          onSessionResetRequested: widget.onSessionResetRequested,
        ),
      ),
    );
  }

  void _showLevel() {
    if (_repository != null) {
      _showSheet(
        title: '会员等级',
        child: Text(
          '经验值：${_field('experience', '0')}',
          style: const TextStyle(color: _muted),
        ),
      );
      return;
    }
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
        allowSnapshotting: false,
        builder: (_) => type == AssetLedgerType.cashBalance
            ? const MemberBalancePage()
            : AssetLedgerPage(initialType: type),
      ),
    );
  }

  void _showSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        allowSnapshotting: false,
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  void _showOrders() {
    if (widget.onOpenOrders case final callback?) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pageContext) => MemberOrdersPage(
          onBack: () => Navigator.of(pageContext).pop(),
          onOpenOrder: (ref) => Navigator.of(pageContext).push(
            MaterialPageRoute(
              builder: (detailContext) => MemberOrdersPage(
                orderRef: ref,
                onBack: () => Navigator.of(detailContext).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfile() async {
    if (_repository != null) {
      if (_profile == null) {
        await _loadProfile();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          allowSnapshotting: false,
          builder: (_) => EditProfilePage(
            nickname: _nickname,
            signature: _signature,
            coverAsset: _coverAsset,
            realProfile: _profile,
            repository: _repository,
          ),
        ),
      );
      await _loadProfile();
      return;
    }
    final result = widget.onOpenEditProfile != null
        ? await widget.onOpenEditProfile!(_nickname, _signature, _coverAsset)
        : await Navigator.of(context).push<EditableProfileResult>(
            MaterialPageRoute<EditableProfileResult>(
              allowSnapshotting: false,
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
      KingNotice.of(context)
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

/// Clip the background itself so the pointed end has transparent corners.
class _LevelBadgeClipper extends CustomClipper<Path> {
  const _LevelBadgeClipper(this.tipWidth);
  final double tipWidth;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - tipWidth, 0)
    ..lineTo(size.width, size.height / 2)
    ..lineTo(size.width - tipWidth, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_LevelBadgeClipper oldClipper) =>
      tipWidth != oldClipper.tipWidth;
}

/// Keeps only the horizontal strip rebuilding while scrolling.
class _ProfileServiceStrip extends StatefulWidget {
  const _ProfileServiceStrip({
    required this.child,
    required this.revealMerchant,
  });
  final Widget child;
  final bool revealMerchant;
  @override
  State<_ProfileServiceStrip> createState() => _ProfileServiceStripState();
}

class _ProfileServiceStripState extends State<_ProfileServiceStrip> {
  final _scroll = ScrollController();
  bool _alignPending = true, _scheduled = false;
  bool _earlier = false, _later = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateOverflow);
  }

  @override
  void didUpdateWidget(covariant _ProfileServiceStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealMerchant != widget.revealMerchant) _alignPending = true;
  }

  void _updateOverflow() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final earlier = p.pixels > p.minScrollExtent + 1;
    final later = p.pixels < p.maxScrollExtent - 1;
    if (_earlier != earlier || _later != later) {
      setState(() {
        _earlier = earlier;
        _later = later;
      });
    }
  }

  void _syncLayout() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      if (_alignPending) {
        _alignPending = false;
        _scroll.jumpTo(
          widget.revealMerchant ? _scroll.position.maxScrollExtent : 0,
        );
      }
      _updateOverflow();
    });
  }

  void _step(bool forward) {
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + (forward ? 1 : -1) * p.viewportDimension / 5).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _arrow(bool forward) => Positioned(
    left: forward ? null : 0,
    right: forward ? 0 : null,
    top: 0,
    bottom: 0,
    child: Tooltip(
      message: partnerText(
        context,
        forward ? 'moreServices' : 'earlierServices',
      ),
      child: InkWell(
        key: ValueKey(
          forward ? 'my-profile-services-later' : 'my-profile-services-earlier',
        ),
        onTap: () => _step(forward),
        child: SizedBox(
          width: 24,
          child: Icon(
            forward ? Icons.chevron_right : Icons.chevron_left,
            size: 12,
            color: const Color(0xffb7ada0),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncLayout();
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _syncLayout();
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
          if (_earlier) _arrow(false),
          if (_later) _arrow(true),
        ],
      ),
    );
  }
}
