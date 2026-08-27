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
import '../../profile_settings/presentation/my_profile_page.dart';
import '../../scanner/presentation/safe_scanner_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.onOpenScanner,
    required this.onOpenTogether,
    required this.onOpenParty,
    this.onOpenOrdering,
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
  }

  Future<void> _openScanner() async {
    if (_scannerOpening) return;
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            onOpenTogether: widget.onOpenTogether,
            onOpenParty: widget.onOpenParty,
            onOpenScanner: _openScanner,
          ),
          IndexedStack(
            index: _messagesPageIndex,
            children: [
              ContactsPage(
                active: _selectedIndex == 1 && _messagesPageIndex == 0,
                onOpenChat: () => setState(() => _messagesPageIndex = 1),
                onIntent: _handleContactIntent,
              ),
              ConversationsPage(
                active: _selectedIndex == 1 && _messagesPageIndex == 1,
                systemUnreadCount: _systemNotificationsUnread,
                initialFriendUnreadCount: _friendConversationUnread,
                onFriendUnreadChanged: (count) {
                  if (!mounted || count == _friendConversationUnread) return;
                  setState(() => _friendConversationUnread = count);
                },
                onOpenContacts: () => setState(() => _messagesPageIndex = 0),
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
            onOpenAuthor: (_) => _showIntent('作者主页安全意图'),
          ),
          const PrivateStoragePage(),
          const MyProfilePage(),
        ],
      ),
      bottomNavigationBar: _LegacyBottomBar(
        selectedIndex: _selectedIndex,
        messageUnreadCount:
            _systemNotificationsUnread + _friendConversationUnread,
        destinations: _destinations,
        onSelected: (index) {
          if (_selectedIndex == index) return;
          setState(() => _selectedIndex = index);
        },
      ),
    );
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
