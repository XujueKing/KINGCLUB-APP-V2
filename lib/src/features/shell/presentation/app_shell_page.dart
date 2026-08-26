import 'package:flutter/material.dart';

import '../../content/presentation/content_feed_page.dart';
import '../../contacts/presentation/contacts_page.dart';
import '../../contacts/presentation/friendship_pages.dart';
import '../../club/presentation/private_storage_page.dart';
import '../../home/presentation/home_page.dart';
import '../../messaging/presentation/conversations_page.dart';
import '../../profile_settings/presentation/my_profile_page.dart';
import '../../scanner/presentation/safe_scanner_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.onOpenScanner,
    required this.onOpenTogether,
    required this.onOpenParty,
    this.initialIndex = 0,
  });

  final Future<SafeScanDestination?> Function(
    BuildContext context,
    int originIndex,
  )
  onOpenScanner;
  final VoidCallback onOpenTogether;
  final VoidCallback onOpenParty;
  final int initialIndex;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  late int _selectedIndex;
  bool _scannerOpening = false;
  int _messagesPageIndex = 0;

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
  }

  Future<void> _openScanner() async {
    if (_scannerOpening) return;
    _scannerOpening = true;
    final destination = await widget.onOpenScanner(context, _selectedIndex);
    if (!mounted) return;
    if (destination != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已生成${destination.label}安全分流意图；当前为 UI Mock。')),
      );
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
                onOpenContacts: () => setState(() => _messagesPageIndex = 0),
                onAddFriend: _openAddFriend,
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

  void _handleContactIntent(ContactRouteIntent intent) {
    switch (intent.kind) {
      case ContactIntentKind.friendRequests:
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FriendRequestsPage(onOpenAddFriend: _openAddFriend),
          ),
        );
      case ContactIntentKind.addFriend:
        _openAddFriend();
      case ContactIntentKind.blacklist:
      case ContactIntentKind.userProfile:
        _showIntent('${intent.label}安全意图');
    }
  }

  void _openAddFriend() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => AddFriendPage(
          onOpenScanner: () async {
            final destination = await widget.onOpenScanner(pageContext, 1);
            if (!pageContext.mounted || destination == null) return;
            ScaffoldMessenger.of(pageContext).showSnackBar(
              SnackBar(content: Text('已生成${destination.label} Fake 分流意图。')),
            );
          },
        ),
      ),
    );
  }
}

class _LegacyBottomBar extends StatelessWidget {
  const _LegacyBottomBar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
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
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final bool center;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = selected ? destination.selectedAsset : destination.asset;
    return Semantics(
      selected: selected,
      button: true,
      label: '${destination.label}，标签${selected ? '，已选中' : ''}',
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
                : Image.asset(
                    'assets/legacy/navigation/$asset',
                    width: 32,
                    height: 24,
                    fit: BoxFit.contain,
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
