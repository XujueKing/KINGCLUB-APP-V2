import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../data/system_notices_repository.dart';
import '../data/system_notices_controller.dart';
import 'system_notice_copy.dart';

import 'legacy_messaging_components.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({
    super.key,
    this.initialUnreadCount = 3,
    this.onUnreadChanged,
    this.demo = true,
    this.controller,
    this.onOpenTarget,
  });

  final int initialUnreadCount;
  final bool demo;
  final ValueChanged<int>? onUnreadChanged;
  final SystemNoticesController? controller;
  final ValueChanged<Map<String, String>>? onOpenTarget;

  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  SystemNoticesController? _controller;
  bool _ownsController = false;
  late final List<_NoticeDisplay> _notices = [
    _NoticeDisplay(
      source: 'GOLDCOIN 仓库',
      title: '签到获得',
      value: '+ 50 枚',
      time: '今天 11:18',
      kingClub: false,
      details: const [('签到门店：', '株洲 KINGCLUB 清吧')],
    ),
    _NoticeDisplay(
      source: 'KING CLUB',
      title: '预订状态更新',
      value: '预订成功',
      time: '昨天 21:08',
      kingClub: true,
      details: const [('套餐：', '微醺畅饮套餐'), ('卡座：', '营业日前一天揭晓')],
    ),
    _NoticeDisplay(
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
    _controller = widget.controller;
    if (!widget.demo && _controller == null && kingclubApiBaseUrl.isNotEmpty) {
      _controller = SystemNoticesController(
        SystemNoticesRepository.secure(kingclubApiBaseUrl),
      );
      _ownsController = true;
    }
    _controller?.addListener(_changed);
    if (_controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller!.refresh());
      });
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      widget.onUnreadChanged?.call(_controller!.summary.unreadCount);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  List<_NoticeDisplay> get _displayNotices {
    if (widget.demo) return _notices;
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode == 'en'
        ? 'en'
        : locale.languageCode == 'th'
        ? 'th'
        : locale.scriptCode == 'Hant' ||
              {'TW', 'HK', 'MO'}.contains(locale.countryCode)
        ? 'zh-TW'
        : 'zh-CN';
    return [
      for (final n in _controller?.notices ?? <SystemNotice>[])
        _NoticeDisplay(
          source: 'KINGCLUB',
          title: systemNoticeText(context, n.kind),
          value: n.amountCents == null
              ? systemNoticeText(context, 'success')
              : '${n.amountCents! ~/ 100}.${(n.amountCents! % 100).toString().padLeft(2, '0')}',
          time: _time(n.occurredAt),
          kingClub: true,
          details: [
            for (final d in n.details)
              (
                systemNoticeText(context, d.$1),
                d.$2 is Map
                    ? (d.$2[language] as String)
                    : d.$1 == 'account'
                    ? systemNoticeText(context, d.$2 as String)
                    : d.$1 == 'expires'
                    ? _expiry(d.$2 as String)
                    : d.$2 as String,
              ),
          ],
          notice: n,
        )..read = n.read,
    ];
  }

  String _expiry(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    return date == null ? value : '${date.year}/${date.month}/${date.day}';
  }

  String _time(DateTime value) {
    final date = value.toLocal(), now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day),
        other = DateTime(date.year, date.month, date.day);
    final days = day.difference(other).inDays;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return days == 0
        ? time
        : days == 1
        ? '${systemNoticeText(context, 'yesterday')} $time'
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} $time';
  }

  @override
  Widget build(BuildContext context) {
    final notices = _displayNotices;
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: widget.demo ? '系统消息' : systemNoticeText(context, 'title'),
              backgroundColor: const Color(0xFF101010),
              lineColor: const Color(0x1CC9B69E),
              lineWidth: .5,
              onBack: () => Navigator.pop(context),
              trailing: TextButton(
                key: const ValueKey('system-notifications-read-all'),
                onPressed:
                    (widget.demo
                        ? notices.every((item) => item.read)
                        : _controller == null ||
                              _controller!.summary.unreadCount == 0 ||
                              _controller!.loading ||
                              _controller!.reading)
                    ? null
                    : () {
                        if (!widget.demo) {
                          unawaited(_controller!.markRead());
                          return;
                        }
                        setState(() {
                          for (final item in _notices) {
                            item.read = true;
                          }
                        });
                        _notifyUnreadChanged();
                      },
                child: Text(
                  systemNoticeText(context, 'read_all'),
                  style: const TextStyle(
                    color: legacyMessageGold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (_controller?.failed == true)
              TextButton(
                onPressed: () => _controller!.refresh(),
                child: Text(systemNoticeText(context, 'retry')),
              ),
            if (_controller?.loading == true && notices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            Expanded(
              child: notices.isEmpty
                  ? Center(
                      child: Text(
                        _controller?.loading == true ||
                                _controller?.failed == true
                            ? ''
                            : systemNoticeText(context, 'empty'),
                        style: const TextStyle(color: Color(0x66FFFFFF)),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('system-notifications-list'),
                      reverse: !widget.demo,
                      padding: EdgeInsets.fromLTRB(
                        45 * MediaQuery.sizeOf(context).width / 750,
                        0,
                        45 * MediaQuery.sizeOf(context).width / 750,
                        30,
                      ),
                      itemCount:
                          notices.length + (_controller?.next != null ? 1 : 0),
                      itemBuilder: (context, index) => index == notices.length
                          ? TextButton(
                              onPressed: _controller!.loading
                                  ? null
                                  : () => _controller!.refresh(more: true),
                              child: Text(systemNoticeText(context, 'more')),
                            )
                          : _NoticeCard(
                              key: ValueKey('system-notice-$index'),
                              notice: notices[index],
                              onTap: () {
                                if (!widget.demo) {
                                  unawaited(
                                    _controller!.markRead(
                                      id: notices[index].notice!.id,
                                    ),
                                  );
                                  final target = notices[index].notice!.target;
                                  if (target != null) {
                                    widget.onOpenTarget?.call(target);
                                  }
                                  return;
                                }
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

  final _NoticeDisplay notice;
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
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (notice.notice?.amountCents != null)
                                  TextSpan(
                                    text: '¥',
                                    style: TextStyle(fontSize: 40 * r),
                                  ),
                                TextSpan(text: notice.value),
                              ],
                            ),
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

class _NoticeDisplay {
  _NoticeDisplay({
    required this.source,
    required this.title,
    required this.value,
    required this.time,
    required this.kingClub,
    required this.details,
    this.notice,
  });

  final String source;
  final String title;
  final String value;
  final String time;
  final bool kingClub;
  final List<(String, String)> details;
  final SystemNotice? notice;
  bool read = false;
}
