import 'package:flutter/material.dart';

import 'legacy_messaging_components.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({
    super.key,
    this.initialUnreadCount = 3,
    this.onUnreadChanged,
  });

  final int initialUnreadCount;
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  late final List<_FakeNotice> _notices = [
    _FakeNotice(
      source: 'GOLDCOIN 仓库',
      title: '签到获得',
      value: '+ 50 枚',
      time: '今天 11:18',
      kingClub: false,
      details: const [('签到门店：', '株洲 KINGCLUB 清吧')],
    ),
    _FakeNotice(
      source: 'KING CLUB',
      title: '预订状态更新',
      value: '预订成功',
      time: '昨天 21:08',
      kingClub: true,
      details: const [('套餐：', '微醺畅饮套餐'), ('卡座位置：', 'A6')],
    ),
    _FakeNotice(
      source: 'KING CLUB',
      title: '服务维护提醒',
      value: '查看详情',
      time: '08月23日',
      kingClub: true,
      details: const [('说明：', '凌晨 05:00 至 05:20 UI Mock 维护演示')],
    ),
  ];

  @override
  void initState() {
    super.initState();
    final unreadCount = widget.initialUnreadCount.clamp(0, _notices.length);
    for (var index = 0; index < _notices.length; index++) {
      _notices[index].read = index >= unreadCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E090C),
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: '系统消息',
              backgroundColor: const Color(0xFF0E090C),
              onBack: () => Navigator.pop(context),
              trailing: TextButton(
                key: const ValueKey('system-notifications-read-all'),
                onPressed: _notices.every((item) => item.read)
                    ? null
                    : () {
                        setState(() {
                          for (final item in _notices) {
                            item.read = true;
                          }
                        });
                        _notifyUnreadChanged();
                      },
                child: const Text(
                  '全部已读',
                  style: TextStyle(color: legacyMessageGold, fontSize: 12),
                ),
              ),
            ),
            Expanded(
              child: _notices.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无系统消息',
                        style: TextStyle(color: Color(0x66FFFFFF)),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('system-notifications-list'),
                      padding: const EdgeInsets.fromLTRB(30, 14, 30, 42),
                      itemCount: _notices.length,
                      itemBuilder: (context, index) => _NoticeCard(
                        key: ValueKey('system-notice-$index'),
                        notice: _notices[index],
                        onTap: () {
                          final wasUnread = !_notices[index].read;
                          setState(() {
                            _notices[index]
                              ..expanded = !_notices[index].expanded
                              ..read = true;
                          });
                          if (wasUnread) _notifyUnreadChanged();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _notifyUnreadChanged() {
    widget.onUnreadChanged?.call(_notices.where((item) => !item.read).length);
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({super.key, required this.notice, required this.onTap});

  final _FakeNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: notice.read
                    ? null
                    : Border.all(color: const Color(0x66C9B69E)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      notice.kingClub
                          ? const LegacyFakeAvatar(size: 30, kingClub: true)
                          : Image.asset(
                              'assets/legacy/home/gold.png',
                              width: 28,
                              height: 28,
                            ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notice.source,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notice.read)
                        const CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFFD65E6B),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0x14FFFFFF)),
                  Padding(
                    key: ValueKey('system-notice-body-${notice.title}'),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notice.title,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notice.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: notice.expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
                      child: Column(
                        children: notice.details
                            .map(
                              (detail) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 92,
                                      child: Text(
                                        detail.$1,
                                        style: const TextStyle(
                                          color: Color(0x80FFFFFF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        detail.$2,
                                        style: const TextStyle(
                                          color: Color(0xCCFFFFFF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
          child: Text(
            notice.time,
            style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _FakeNotice {
  _FakeNotice({
    required this.source,
    required this.title,
    required this.value,
    required this.time,
    required this.kingClub,
    required this.details,
  });

  final String source;
  final String title;
  final String value;
  final String time;
  final bool kingClub;
  final List<(String, String)> details;
  bool read = false;
  bool expanded = false;
}
