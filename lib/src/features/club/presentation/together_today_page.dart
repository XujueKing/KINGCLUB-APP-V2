import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/formatters/money.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_language.dart';
import '../../../core/design_system/king_notice.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/together_feed.dart';
import '../data/together_play.dart';
import '../data/together_read_history.dart';
import '../data/together_store.dart';
import 'together_activity_page.dart';
import 'together_play_page.dart';

class TogetherTodayPage extends StatefulWidget {
  const TogetherTodayPage({
    super.key,
    required this.repository,
    required this.cityCode,
    required this.cityName,
    required this.onHome,
    required this.onSelectCity,
    required this.onJoin,
    required this.onAdmission,
    required this.stores,
    this.account,
    this.readHistory,
    this.avatar,
  });
  final TogetherPlayRepository repository;
  final TogetherStoreRepository stores;
  final String cityCode, cityName;
  final VoidCallback onHome, onSelectCity;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  final String? account;
  final TogetherReadHistory? readHistory;
  final ImageProvider? avatar;
  @override
  State<TogetherTodayPage> createState() => _TogetherTodayPageState();
}

class _TogetherTodayPageState extends State<TogetherTodayPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _seen = <String>{};
  final _cardKeys = <String, GlobalKey>{};
  List<TogetherParty> _items = [];
  TogetherReadHistory? _readHistory;
  File? _avatar;
  ImageProvider? _viewerAvatar;
  String? _next, _error, _storeRef, _storeName, _opening;
  DateTime? _date;
  int _epoch = 0;
  bool _loading = true, _more = false, _navigating = false;
  String _t(String a, String b, String c, String d) =>
      kingText(Localizations.localeOf(context), [a, b, c, d]);
  TogetherFeedRepository get _feed =>
      widget.repository as TogetherFeedRepository;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_scrolled);
    _load();
    _presentation();
  }

  @override
  void didUpdateWidget(TogetherTodayPage old) {
    super.didUpdateWidget(old);
    if (old.cityCode != widget.cityCode ||
        old.repository != widget.repository) {
      _storeRef = null;
      _storeName = null;
      _items = [];
      _cardKeys.clear();
      _load();
    }
  }

  Future<void> _presentation() async {
    try {
      final session = await SecureSessionStore().readSession();
      final account =
          widget.account ??
          (session?['account'] as Map?)?['userAccount'] as String?;
      if (account != null) {
        _readHistory = widget.readHistory ?? TogetherReadHistory(account);
        final refs = await _readHistory!.load();
        if (mounted) setState(() => _seen.addAll(refs));
      }
      if (!mounted || widget.avatar != null) return;
      if (MemberQrMemory.avatar != null) {
        setState(() => _avatar = MemberQrMemory.avatar);
        return;
      }
    } catch (_) {
      /* No sample avatar, account or viewed entitlement fallback. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_navigating) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _scrolled() {
    if (_scroll.position.extentAfter < 450 &&
        _next != null &&
        !_loading &&
        !_more) {
      _load(more: true);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_next == null || _more || _loading)) return;
    final epoch = more ? _epoch : ++_epoch;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _next = null;
      }
      _error = null;
    });
    try {
      final result = await _feed.feed(
        view: TogetherFeedView.recommendations,
        cityCode: widget.cityCode,
        storeRef: _storeRef,
        date: _date,
        after: more ? _next : null,
      );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        final previous = more ? _items : <TogetherParty>[];
        final ids = previous.map((p) => p.ref).toSet();
        _items = [...previous, ...result.items.where((p) => ids.add(p.ref))];
        _next = result.next;
        if (result.avatarBytes != null) {
          _viewerAvatar = MemoryImage(result.avatarBytes!);
        }
        if (!more) {
          _cardKeys.removeWhere((ref, _) => !_items.any((p) => p.ref == ref));
        }
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = more ? '更多活动加载失败' : '暂时无法加载活动');
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  Future<void> _open(TogetherParty party) async {
    if (_navigating) return;
    final box =
        _cardKeys[party.ref]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _navigating = true;
      _opening = party.ref;
    });
    var changed = false;
    try {
      await openTogetherActivity(
        context,
        origin: origin,
        party: party,
        repository: widget.repository,
        onJoin: (value) async {
          changed = true;
          await widget.onJoin(value);
        },
        onLoaded: (value) {
          if (mounted) {
            setState(() {
              _items = _items
                  .map((item) => item.ref == value.ref ? value : item)
                  .toList();
            });
          }
        },
        onAdmission: widget.onAdmission,
        onViewed: () {
          if (!mounted) return;
          setState(() => _seen.add(party.ref));
          unawaited(_readHistory?.mark(party.ref) ?? Future<void>.value());
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _opening = null;
          _navigating = false;
        });
        if (changed) await _load();
      }
    }
  }

  Future<void> _action(TogetherParty party) async {
    if (!_seen.contains(party.ref)) {
      await _open(party);
      return;
    }
    if (_navigating || !party.canAct || party.hasAdmissionTicket) return;
    setState(() => _navigating = true);
    try {
      await widget.onJoin(party);
    } finally {
      if (mounted) {
        setState(() => _navigating = false);
        await _load();
      }
    }
  }

  Future<void> _time() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_t('今日推荐', 'Today’s picks', '今日推薦', 'แนะนำวันนี้')),
              selected: _date == null,
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              title: Text(_t('指定日期', 'Choose a date', '指定日期', 'เลือกวันที่')),
              onTap: () => Navigator.pop(context, 1),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 0) {
      setState(() {
        _date = null;
        _items = [];
      });
      await _load();
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _items = [];
      });
      await _load();
    }
  }

  Future<void> _store() async {
    try {
      final city = widget.cityCode;
      final stores = await widget.stores.list(cityCode: city);
      if (!mounted || city != widget.cityCode) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: ListView(
              children: [
                ListTile(
                  title: Text(_t('全部商店', 'All stores', '全部商店', 'ทุกร้าน')),
                  onTap: () => Navigator.pop(context, ''),
                ),
                ...stores
                    .where((s) => s.cityCode == city)
                    .map(
                      (s) => ListTile(
                        title: Text(s.name),
                        subtitle: Text(s.address),
                        selected: s.ref == _storeRef,
                        onTap: () => Navigator.pop(context, s.ref),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !mounted || city != widget.cityCode) return;
      setState(() {
        _storeRef = selected.isEmpty ? null : selected;
        _storeName = stores.where((s) => s.ref == selected).firstOrNull?.name;
        _items = [];
      });
      await _load();
    } catch (_) {
      if (mounted) KingNotice.of(context).show('暂时无法加载商店，请重试');
    }
  }

  Future<void> _account(TogetherFeedView view) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TogetherMemberActivityPage(
            repository: _feed,
            view: view,
            onAdmission: widget.onAdmission,
            onJoin: widget.onJoin,
          ),
        ),
      );
    } finally {
      _navigating = false;
      if (mounted) await _load();
    }
  }

  PopupMenuItem<String> _item(String value, String label, [String? current]) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Text(label),
            if (current != null) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  current,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      );
  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      PopupMenuButton<String>(
        key: const ValueKey('today-menu'),
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'home':
              widget.onHome();
            case 'city':
              widget.onSelectCity();
            case 'store':
              _store();
            case 'time':
              _time();
          }
        },
        itemBuilder: (_) => [
          _item('home', _t('返回首页', 'Home', '返回首頁', 'หน้าหลัก')),
          _item(
            'city',
            _t('切换城市', 'Change city', '切換城市', 'เปลี่ยนเมือง'),
            widget.cityName,
          ),
          _item(
            'store',
            _t('切换商店', 'Change store', '切換商店', 'เปลี่ยนร้าน'),
            _storeName ?? _t('全部商店', 'All stores', '全部商店', 'ทุกร้าน'),
          ),
          _item(
            'time',
            _t('选择时间', 'Choose time', '選擇時間', 'เลือกเวลา'),
            _date == null
                ? _t('今日推荐', 'Today’s picks', '今日推薦', 'แนะนำวันนี้')
                : '${_date!.year}.${_date!.month}.${_date!.day}',
          ),
        ],
        child: Text(
          _t('今日', 'Today', '今日', 'วันนี้'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
          ),
        ),
      ),
      PopupMenuButton<String>(
        key: const ValueKey('today-avatar-menu'),
        position: PopupMenuPosition.under,
        onSelected: (view) {
          if (view == 'home') {
            widget.onHome();
          } else {
            _account(TogetherFeedView.values.byName(view));
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'tickets',
            child: Text(
              _t('可用活动券', 'Available tickets', '可用活動券', 'บัตรที่ใช้ได้'),
            ),
          ),
          PopupMenuItem(
            value: 'history',
            child: Text(
              _t('历史加入活动', 'Activity history', '歷史加入活動', 'กิจกรรมที่ผ่านมา'),
            ),
          ),
          PopupMenuItem(
            value: 'purchases',
            child: Text(_t('购买记录', 'Purchases', '購買記錄', 'ประวัติการซื้อ')),
          ),
          PopupMenuItem(
            value: 'home',
            child: Text(_t('返回首页', 'Home', '返回首頁', 'หน้าหลัก')),
          ),
        ],
        child: SizedBox.square(
          dimension: 44,
          child: ClipOval(
            child: widget.avatar != null
                ? Image(
                    image: widget.avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
                  )
                : _viewerAvatar != null
                ? Image(
                    image: _viewerAvatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
                  )
                : _avatar != null
                ? Image.file(
                    _avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
                  )
                : const ColoredBox(
                    color: Color(0xFF292929),
                    child: Icon(Icons.person_outline, color: Colors.white60),
                  ),
          ),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RefreshIndicator.noSpinner(
            onRefresh: _load,
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, safe + 68, 20, 30),
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: _loading || _more
                          ? const SizedBox.shrink()
                          : _error != null
                          ? TextButton(
                              onPressed: () => _load(
                                more: _items.isNotEmpty && _next != null,
                              ),
                              child: Text('$_error · 重试'),
                            )
                          : _items.isEmpty
                          ? Text(
                              _t(
                                '当前没有可选活动',
                                'No activities available',
                                '目前沒有可選活動',
                                'ยังไม่มีกิจกรรม',
                              ),
                              style: const TextStyle(color: Colors.white60),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                final party = _items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Opacity(
                    opacity: _opening == party.ref ? 0 : 1,
                    child: SizedBox(
                      key: _cardKeys.putIfAbsent(party.ref, () => GlobalKey()),
                      child: TogetherAvailableRow(
                        party: party,
                        edgeInset: false,
                        showHeading: false,
                        showAction: true,
                        blurFooter: false,
                        actionLabel: _seen.contains(party.ref) ? '加入' : '查看',
                        onTap: () => _open(party),
                        onAction:
                            _seen.contains(party.ref) &&
                                (!party.canAct || party.hasAdmissionTicket)
                            ? null
                            : () => _action(party),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _scroll,
            child: _header(),
            builder: (context, header) {
              final alpha = (1 - (_scroll.hasClients ? _scroll.offset : 0) / 32)
                  .clamp(0.0, 1.0);
              return Positioned(
                top: safe + 8,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  ignoring: alpha <= .05,
                  child: ExcludeSemantics(
                    excluding: alpha <= .05,
                    child: ExcludeFocus(
                      excluding: alpha <= .05,
                      child: Opacity(opacity: alpha, child: header),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: safe,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TogetherMemberActivityPage extends StatefulWidget {
  const TogetherMemberActivityPage({
    super.key,
    required this.repository,
    required this.view,
    required this.onAdmission,
    required this.onJoin,
  });
  final TogetherFeedRepository repository;
  final TogetherFeedView view;
  final Future<void> Function(TogetherParty) onAdmission, onJoin;
  @override
  State<TogetherMemberActivityPage> createState() =>
      _TogetherMemberActivityPageState();
}

class _TogetherMemberActivityPageState
    extends State<TogetherMemberActivityPage> {
  List<TogetherParty> _items = [];
  String? _next, _error;
  bool _loading = true;
  String get _title => switch (widget.view) {
    TogetherFeedView.tickets => '可用活动券',
    TogetherFeedView.history => '历史加入活动',
    _ => '购买记录',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _next == null)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.feed(
        view: widget.view,
        after: more ? _next : null,
      );
      if (mounted) {
        setState(() {
          final previous = more ? _items : <TogetherParty>[];
          final refs = previous.map((p) => p.ref).toSet();
          _items = [...previous, ...page.items.where((p) => refs.add(p.ref))];
          _next = page.next;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法加载，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(context: context, title: Text(_title)),
    body: RefreshIndicator.noSpinner(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ..._items.map(
            (party) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: widget.view == TogetherFeedView.tickets
                  ? TogetherPartyCard(
                      party: party,
                      onTap: () async {
                        await widget.onAdmission(party);
                        if (mounted) await _load();
                      },
                    )
                  : Card(
                      child: ExpansionTile(
                        title: Text(party.theme),
                        subtitle: Text(
                          '${togetherTimeRange(party)}\n${party.storeName}',
                        ),
                        children: [
                          ListTile(
                            title: Text(switch (party.bookingStatus) {
                              'paid' => party.admissionUsed ? '已使用' : '已付款',
                              'pending' => '待付款',
                              'paying' => '付款确认中',
                              'refunded' => '已退款',
                              'cancelled' => '已取消',
                              _ => '记录详情',
                            }),
                            subtitle: Text(
                              party.bookingRef ?? party.ticketNumber ?? '',
                            ),
                            trailing: party.bookingPayableMinor == null
                                ? null
                                : Text(
                                    '报价 ¥${moneyCents(party.bookingPayableMinor!)}',
                                  ),
                          ),
                          if (party.hasAdmissionTicket)
                            TextButton(
                              onPressed: () => widget.onAdmission(party),
                              child: const Text('查看入场券'),
                            ),
                          if (party.actionState ==
                              TogetherJoinState.pendingPayment)
                            TextButton(
                              onPressed: () async {
                                await widget.onJoin(party);
                                if (mounted) await _load();
                              },
                              child: const Text('继续付款'),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          if (_loading)
            const SizedBox.shrink()
          else if (_error != null)
            TextButton(
              onPressed: () => _load(more: _items.isNotEmpty && _next != null),
              child: Text(_error!),
            )
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('暂无记录', style: TextStyle(color: Colors.white60)),
              ),
            )
          else if (_next != null)
            TextButton(
              onPressed: () => _load(more: true),
              child: const Text('加载更多'),
            ),
        ],
      ),
    ),
  );
}
