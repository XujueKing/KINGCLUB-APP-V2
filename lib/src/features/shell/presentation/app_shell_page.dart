import 'package:flutter/material.dart';

import '../../content/presentation/content_feed_page.dart';
import '../../contacts/presentation/contacts_page.dart';
import '../../contacts/presentation/blacklist_page.dart';
import '../../contacts/presentation/friendship_pages.dart';
import '../../contacts/presentation/user_profile_page.dart';
import '../../club/presentation/private_storage_page.dart';
import '../../home/presentation/home_page.dart';
import '../../messaging/presentation/conversations_page.dart';
import '../../messaging/presentation/direct_chat_page.dart';
import '../../messaging/presentation/system_notifications_page.dart';
import '../../membership_wallet/presentation/asset_ledger_page.dart';
import '../../profile_settings/presentation/edit_profile_page.dart';
import '../../profile_settings/presentation/my_profile_page.dart';
import '../../scanner/presentation/safe_scanner_page.dart';

enum AppShellDemoState {
  ready,
  offline,
  sessionTransition,
  membershipTransition,
}

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.onOpenScanner,
    required this.onOpenTogether,
    required this.onOpenParty,
    this.onOpenOrdering,
    this.onOpenAssets,
    this.onOpenEditProfile,
    this.onOpenPersonalQr,
    this.onOpenSettings,
    this.onSessionResetRequested,
    this.onOpenFriendRequests,
    this.onOpenAddFriend,
    this.onOpenBlacklist,
    this.onOpenUserProfile,
    this.onOpenContentAuthor,
    this.onMembershipReviewRequested,
    this.onDestinationReselected,
    this.initialDemoState = AppShellDemoState.ready,
    this.initialIndex = 0,
    this.initialSystemUnreadCount = 3,
    this.initialFriendUnreadCount = 2,
  });

  final Future<SafeScanDestination?> Function(
    BuildContext context,
    int originIndex,
  )
  onOpenScanner;
  final VoidCallback onOpenTogether;
  final VoidCallback onOpenParty;
  final VoidCallback? onOpenOrdering;
  final ValueChanged<AssetLedgerType>? onOpenAssets;
  final Future<EditableProfileResult?> Function(
    String nickname,
    String signature,
  )?
  onOpenEditProfile;
  final VoidCallback? onOpenPersonalQr;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onSessionResetRequested;
  final VoidCallback? onOpenFriendRequests;
  final VoidCallback? onOpenAddFriend;
  final VoidCallback? onOpenBlacklist;
  final ValueChanged<String>? onOpenUserProfile;
  final ValueChanged<String>? onOpenContentAuthor;
  final VoidCallback? onMembershipReviewRequested;
  final ValueChanged<int>? onDestinationReselected;
  final AppShellDemoState initialDemoState;
  final int initialIndex;
  final int initialSystemUnreadCount;
  final int initialFriendUnreadCount;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  late int _selectedIndex;
  bool _scannerOpening = false;
  int _messagesPageIndex = 0;
  late int _systemNotificationsUnread;
  late int _friendConversationUnread;
  late AppShellDemoState _shellState;
  int _homeReselectSignal = 0;

  static const _destinations = [
    _ShellDestination('首页', 'tabBar_home.png', 'tabBar_home_a.png'),
    _ShellDestination('消息', 'tabBar_chat.png', 'tabBar_chat_a.png'),
    _ShellDestination('内容', 'tabBar_py.png', 'tabBar_py_a.png'),
    _ShellDestination('私人储物柜', 'tabBar_bx.png', 'tabBar_bx_a.png'),
    _ShellDestination('我的', 'tabBar_my.png', 'tabBar_my_a.png'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _destinations.length - 1);
    _systemNotificationsUnread = widget.initialSystemUnreadCount.clamp(0, 9999);
    _friendConversationUnread = widget.initialFriendUnreadCount.clamp(0, 9999);
    _shellState = widget.initialDemoState;
  }

  Future<void> _openScanner() async {
    if (_scannerOpening || _navigationLocked) return;
    _scannerOpening = true;
    final destination = await widget.onOpenScanner(context, _selectedIndex);
    if (!mounted) return;
    if (destination != null) {
      _openScannedDestination(context, destination);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _scannerOpening = false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0 || _navigationLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _selectedIndex == 0 || _navigationLocked) return;
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: [
                HomePage(
                  reselectSignal: _homeReselectSignal,
                  onOpenTogether: widget.onOpenTogether,
                  onOpenParty: widget.onOpenParty,
                  onOpenScanner: _openScanner,
                  onSessionResetRequested: widget.onSessionResetRequested,
                ),
                IndexedStack(
                  index: _messagesPageIndex,
                  children: [
                    ContactsPage(
                      active: _selectedIndex == 1 && _messagesPageIndex == 0,
                      onOpenChat: () => setState(() => _messagesPageIndex = 1),
                      onIntent: _handleContactIntent,
                      onSessionResetRequested: widget.onSessionResetRequested,
                    ),
                    ConversationsPage(
                      active: _selectedIndex == 1 && _messagesPageIndex == 1,
                      systemUnreadCount: _systemNotificationsUnread,
                      initialFriendUnreadCount: _friendConversationUnread,
                      onFriendUnreadChanged: (count) {
                        if (!mounted || count == _friendConversationUnread) {
                          return;
                        }
                        setState(() => _friendConversationUnread = count);
                      },
                      onOpenContacts: () =>
                          setState(() => _messagesPageIndex = 0),
                      onAddFriend: _openAddFriend,
                      onOpenSystemNotifications: _openSystemNotifications,
                      onOpenDirectChat: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const DirectChatPage(),
                        ),
                      ),
                    ),
                  ],
                ),
                ContentFeedPage(
                  active: _selectedIndex == 2,
                  onOpenAuthor: (targetRef) {
                    if (widget.onOpenContentAuthor != null) {
                      widget.onOpenContentAuthor!(targetRef);
                    } else {
                      _showIntent('作者主页安全意图');
                    }
                  },
                  onReturnHome: () => setState(() => _selectedIndex = 0),
                  onSessionResetRequested: widget.onSessionResetRequested,
                ),
                const PrivateStoragePage(),
                MyProfilePage(
                  onOpenAssets: widget.onOpenAssets,
                  onOpenEditProfile: widget.onOpenEditProfile,
                  onOpenPersonalQr: widget.onOpenPersonalQr,
                  onOpenSettings: widget.onOpenSettings,
                  onSessionResetRequested: widget.onSessionResetRequested,
                ),
              ],
            ),
            if (_shellState == AppShellDemoState.offline)
              _OfflineBanner(
                onDismissed: () =>
                    setState(() => _shellState = AppShellDemoState.ready),
              ),
            if (_shellState == AppShellDemoState.sessionTransition)
              _ShellTransitionOverlay(
                key: const ValueKey('shell-session-transition'),
                icon: Icons.lock_reset_rounded,
                title: '正在安全退出',
                message: '本地会话与页面状态将被清理，然后返回手机号登录。',
                actionLabel: '返回登录',
                onAction: widget.onSessionResetRequested,
              ),
            if (_shellState == AppShellDemoState.membershipTransition)
              _ShellTransitionOverlay(
                key: const ValueKey('shell-membership-transition'),
                icon: Icons.verified_user_outlined,
                title: '会员状态已更新',
                message: '当前业务页面已停止使用，请返回会员审核状态页查看。',
                actionLabel: '查看审核状态',
                onAction: widget.onMembershipReviewRequested,
              ),
          ],
        ),
        bottomNavigationBar: IgnorePointer(
          ignoring: _navigationLocked,
          child: _LegacyBottomBar(
            selectedIndex: _selectedIndex,
            messageUnreadCount:
                _systemNotificationsUnread + _friendConversationUnread,
            destinations: _destinations,
            onSelected: _selectDestination,
          ),
        ),
      ),
    );
  }

  bool get _navigationLocked =>
      _shellState == AppShellDemoState.sessionTransition ||
      _shellState == AppShellDemoState.membershipTransition;

  void _selectDestination(int index) {
    if (_navigationLocked) return;
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      return;
    }

    if (index == 1 && _messagesPageIndex != 0) {
      setState(() => _messagesPageIndex = 0);
      return;
    }
    if (index == 0) {
      setState(() => _homeReselectSignal += 1);
    }
    widget.onDestinationReselected?.call(index);
  }

  void _showIntent(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已生成$label；目标 UI 将在对应页面批次接入。')));
  }

  Future<void> _openSystemNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SystemNotificationsPage(
          initialUnreadCount: _systemNotificationsUnread,
          onUnreadChanged: (count) {
            if (!mounted || count == _systemNotificationsUnread) return;
            setState(() => _systemNotificationsUnread = count);
          },
        ),
      ),
    );
  }

  void _handleContactIntent(ContactRouteIntent intent) {
    switch (intent.kind) {
      case ContactIntentKind.friendRequests:
        if (widget.onOpenFriendRequests != null) {
          widget.onOpenFriendRequests!();
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FriendRequestsPage(
              onOpenAddFriend: _openAddFriend,
              onOpenChat: (peerName) => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => DirectChatPage(peerName: peerName),
                ),
              ),
            ),
          ),
        );
      case ContactIntentKind.addFriend:
        _openAddFriend();
      case ContactIntentKind.blacklist:
        if (widget.onOpenBlacklist != null) {
          widget.onOpenBlacklist!();
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => BlacklistPage(
              onOpenAddFriend: _openAddFriend,
              onOpenUserProfile: (targetRef) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => UserProfilePage(
                      targetRef: targetRef,
                      initialRelationship: UserProfileRelationship.blockedByMe,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      case ContactIntentKind.userProfile:
        if (widget.onOpenUserProfile != null) {
          widget.onOpenUserProfile!(intent.targetRef ?? 'contact-chenxi');
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => UserProfilePage(
              targetRef: intent.targetRef ?? 'contact-chenxi',
            ),
          ),
        );
    }
  }

  void _openAddFriend() {
    if (widget.onOpenAddFriend != null) {
      widget.onOpenAddFriend!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => AddFriendPage(
          onOpenScanner: () async {
            final destination = await widget.onOpenScanner(pageContext, 1);
            if (!pageContext.mounted || destination == null) return;
            _openScannedDestination(pageContext, destination);
          },
        ),
      ),
    );
  }

  void _openScannedDestination(
    BuildContext pageContext,
    SafeScanDestination destination,
  ) {
    if (destination == SafeScanDestination.friendProfile) {
      Navigator.of(pageContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const UserProfilePage(
            targetRef: 'contact-alice',
            initialRelationship: UserProfileRelationship.stranger,
          ),
        ),
      );
      return;
    }
    if (destination == SafeScanDestination.tableOrdering &&
        widget.onOpenOrdering != null) {
      widget.onOpenOrdering!();
      return;
    }
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(content: Text('已生成${destination.label}安全分流意图；当前为 UI Mock。')),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onDismissed});

  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Semantics(
          liveRegion: true,
          label: '当前网络不可用，页面状态已保留',
          child: Container(
            key: const ValueKey('shell-offline-banner'),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0xF52B251E),
              border: Border.all(color: const Color(0xFF8D7A62)),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 20),
                const SizedBox(width: 9),
                const Flexible(child: Text('网络不可用，当前页面状态已保留')),
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey('shell-offline-dismiss'),
                  tooltip: '关闭网络提示',
                  onPressed: onDismissed,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellTransitionOverlay extends StatelessWidget {
  const _ShellTransitionOverlay({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xF0000000),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: const Color(0xFFD4BEA0)),
                  const SizedBox(height: 18),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegacyBottomBar extends StatelessWidget {
  const _LegacyBottomBar({
    required this.selectedIndex,
    required this.messageUnreadCount,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final int messageUnreadCount;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xF51A1611),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: List.generate(
            destinations.length,
            (index) => Expanded(
              child: _LegacyNavItem(
                destination: destinations[index],
                selected: selectedIndex == index,
                center: index == 2,
                unreadCount: index == 1 ? messageUnreadCount : 0,
                onTap: () => onSelected(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegacyNavItem extends StatelessWidget {
  const _LegacyNavItem({
    required this.destination,
    required this.selected,
    required this.center,
    required this.unreadCount,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final bool center;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = selected ? destination.selectedAsset : destination.asset;
    final unreadSemantics = unreadCount > 0
        ? '，${unreadCount > 99 ? '99 条以上' : '$unreadCount 条'}未读'
        : '';
    return Semantics(
      selected: selected,
      button: true,
      label: '${destination.label}，标签$unreadSemantics${selected ? '，已选中' : ''}',
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: center ? 50 : 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected && !center
                  ? const Color(0xFF090806)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: center
                ? Container(
                    width: 42,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5F0),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.favorite,
                      size: 20,
                      color: Color(0xFFD65E6B),
                    ),
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/legacy/navigation/$asset',
                        width: 32,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 1,
                          right: 0,
                          child: ExcludeSemantics(
                            child: Container(
                              key: const ValueKey('shell-message-unread-badge'),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE84848),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: const Color(0xFF1A1611),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.asset, this.selectedAsset);

  final String label;
  final String asset;
  final String selectedAsset;
}
