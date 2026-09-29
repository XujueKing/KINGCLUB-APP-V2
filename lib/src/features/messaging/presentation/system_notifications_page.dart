import 'package:flutter/material.dart';

import 'legacy_messaging_components.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({
    super.key,
    this.initialUnreadCount = 3,
    this.onUnreadChanged,
    this.demo = true,
  });

  final int initialUnreadCount;
  final bool demo;
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
      details: const [('套餐：', '微醺畅饮套餐'), ('卡座：', '营业日前一天揭晓')],
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
    if (!widget.demo) _notices.clear();
    final unreadCount = widget.initialUnreadCount.clamp(0, _notices.length);
    for (var index = 0; index < _notices.length; index++) {
      _notices[index].read = index >= unreadCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: '系统消息',
              backgroundColor: const Color(0xFF101010),
              lineColor: const Color(0x1CC9B69E),
              lineWidth: .5,
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
                      padding: EdgeInsets.fromLTRB(
                        45 * MediaQuery.sizeOf(context).width / 750,
                        0,
                        45 * MediaQuery.sizeOf(context).width / 750,
                        30,
                      ),
                      itemCount: _notices.length,
                      itemBuilder: (context, index) => _NoticeCard(
                        key: ValueKey('system-notice-$index'),
                        notice: _notices[index],
                        onTap: () {
                          final wasUnread = !_notices[index].read;
                          setState(() {
                            _notices[index].read = true;
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
    final r = MediaQuery.sizeOf(context).width / 750;
    final bodyStyle = TextStyle(
      color: const Color(0xCCFFFFFF),
      fontSize: 28 * r,
      height: kTextHeightNone,
    );
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20 * r),
          child: Material(
            color: const Color(0x0FFFFFFF),
            borderRadius: BorderRadius.circular(16 * r),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(30 * r),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(bottom: 30 * r),
                      margin: EdgeInsets.only(bottom: 90 * r),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0x14FFFFFF),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              notice.kingClub
                                  ? 'assets/legacy/messaging/system_kingclub.png'
                                  : 'assets/legacy/home/gold.png',
                              width: (notice.kingClub ? 60 : 50) * r,
                              height: (notice.kingClub ? 60 : 50) * r,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 14 * r),
                          Expanded(
                            child: Text(notice.source, style: bodyStyle),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      key: ValueKey('system-notice-body-${notice.title}'),
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4 * r),
                          child: Text(notice.title, style: bodyStyle),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * r,
                            vertical: 20 * r,
                          ),
                          child: Text(
                            notice.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 56 * r,
                              fontWeight: FontWeight.w500,
                              height: kTextHeightNone,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20 * r,
                        50 * r,
                        20 * r,
                        30 * r,
                      ),
                      child: Column(
                        children: [
                          for (final detail in notice.details)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 5 * r),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 152 * r,
                                    child: Text(
                                      detail.$1,
                                      style: bodyStyle.copyWith(
                                        color: const Color(0x80FFFFFF),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(detail.$2, style: bodyStyle),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 30 * r, 0, 10 * r),
          child: Text(
            notice.time,
            style: TextStyle(color: const Color(0x66FFFFFF), fontSize: 24 * r),
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
}
