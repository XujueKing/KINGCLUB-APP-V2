import 'package:flutter/material.dart';

import 'legacy_club_components.dart';

enum VipPartyCreateScenario {
  ready,
  quoteChanged,
  quoteExpired,
  inventoryConflict,
  offline,
  resultUnknown,
  zeroCash,
}

class VipPartyCreatePage extends StatefulWidget {
  const VipPartyCreatePage({
    super.key,
    required this.onBack,
    this.initialDate = '08.26',
  });

  final VoidCallback onBack;
  final String initialDate;

  @override
  State<VipPartyCreatePage> createState() => _VipPartyCreatePageState();
}

class _VipPartyCreatePageState extends State<VipPartyCreatePage> {
  static const _tables = ['V11', 'V8', 'V6'];
  static const _capacities = [10, 8, 6];
  static const _packages = [
    ('星光香槟套餐', 688, 888),
    ('微醺派对套餐', 488, 588),
    ('鎏金威士忌套餐', 1288, 1588),
  ];

  int _tableIndex = 0;
  int _people = 10;
  int _packageIndex = 0;
  bool _splitPerMember = true;
  bool _publicRecruiting = true;
  bool _termsAccepted = false;
  bool _requoteLoading = false;
  bool _submitting = false;
  VipPartyCreateScenario _scenario = VipPartyCreateScenario.ready;

  bool get _offline => _scenario == VipPartyCreateScenario.offline;
  bool get _quoteExpired => _scenario == VipPartyCreateScenario.quoteExpired;
  bool get _inventoryConflict =>
      _scenario == VipPartyCreateScenario.inventoryConflict;
  int get _packagePrice =>
      _packages[_packageIndex].$2 +
      (_scenario == VipPartyCreateScenario.quoteChanged ? 10 : 0);
  int get _memberDue => _splitPerMember ? (_packagePrice / _people).ceil() : 0;
  int get _hostDue => _scenario == VipPartyCreateScenario.zeroCash
      ? 0
      : _splitPerMember
      ? _memberDue
      : _packagePrice;
  bool get _canCreate =>
      !_offline &&
      !_quoteExpired &&
      !_inventoryConflict &&
      !_requoteLoading &&
      !_submitting &&
      _termsAccepted;

  @override
  Widget build(BuildContext context) {
    return LegacyClubScaffold(
      title: '预定一个卡颜局',
      onBack: widget.onBack,
      showMockLabel: false,
      onTitleLongPress: _showScenarioSheet,
      child: Stack(
        children: [
          ListView(
            key: const ValueKey('vip-create-form'),
            padding: const EdgeInsets.only(bottom: 136),
            children: [
              if (_offline)
                const _StatusBanner(
                  icon: Icons.cloud_off_rounded,
                  message: '当前离线，草稿仅保留在本次页面；不能重报价或创建。',
                ),
              if (_scenario == VipPartyCreateScenario.quoteChanged)
                const _StatusBanner(
                  icon: Icons.price_change_rounded,
                  message: '套餐报价已由 ¥688.00 更新为 ¥698.00，请重新确认规则。',
                ),
              if (_quoteExpired)
                const _StatusBanner(
                  icon: Icons.schedule_rounded,
                  message: '当前报价已过期，请先刷新报价。',
                ),
              if (_inventoryConflict)
                const _StatusBanner(
                  icon: Icons.event_seat_outlined,
                  message: 'V11 卡座刚刚被占用，请重新选择卡座；其他选择已保留。',
                ),
              _section([
                _valueRow('预订时间：', widget.initialDate, accent: true),
                _pickerRow(
                  key: const ValueKey('vip-create-table'),
                  label: '选择一个卡座：',
                  value: _tables[_tableIndex],
                  onTap: _offline
                      ? null
                      : () => _pick(
                          title: '选择一个卡座',
                          options: List.generate(
                            _tables.length,
                            (index) =>
                                '${_tables[index]}卡座 (${_capacities[index]}人)',
                          ),
                          selected: _tableIndex,
                          onSelected: (index) {
                            _tableIndex = index;
                            _people = _capacities[index];
                          },
                        ),
                ),
                _pickerRow(
                  key: const ValueKey('vip-create-people'),
                  label: '聚会人数（最大${_capacities[_tableIndex]}人）：',
                  value: '$_people 人',
                  onTap: _offline
                      ? null
                      : () => _pick(
                          title: '选择聚会人数',
                          options: List.generate(
                            _capacities[_tableIndex],
                            (index) => '${index + 1} 人',
                          ),
                          selected: _people - 1,
                          onSelected: (index) => _people = index + 1,
                        ),
                ),
                _pickerRow(
                  key: const ValueKey('vip-create-package'),
                  label: '选套餐：',
                  value: _packages[_packageIndex].$1,
                  onTap: _offline
                      ? null
                      : () => _pick(
                          title: '选择酒水套餐',
                          options: _packages
                              .map((item) => '${item.$1}  ¥${item.$2}')
                              .toList(),
                          selected: _packageIndex,
                          onSelected: (index) => _packageIndex = index,
                        ),
                ),
                _priceRow(),
              ]),
              _section([
                _switchRow(
                  key: const ValueKey('vip-create-split-switch'),
                  title: '成员各付',
                  hint: '会员加入时按权威报价均摊费用',
                  value: _splitPerMember,
                  onChanged: _offline
                      ? null
                      : (value) =>
                            _changeAndRequote(() => _splitPerMember = value),
                ),
                _switchRow(
                  key: const ValueKey('vip-create-public-switch'),
                  title: '公开招募',
                  hint: '关闭后仅允许受邀会员加入',
                  value: _publicRecruiting,
                  onChanged: _offline
                      ? null
                      : (value) =>
                            _changeAndRequote(() => _publicRecruiting = value),
                ),
              ]),
              _section([
                _valueRow('创建者身份：', '局长', accent: true),
                _valueRow(
                  '成员参考应付：',
                  '¥${_memberDue.toStringAsFixed(2)}',
                  accent: true,
                ),
                _valueRow(
                  '当前报价有效期：',
                  _quoteExpired ? '已过期' : '04:58',
                  accent: _quoteExpired,
                ),
                _valueRow('招募范围：', _publicRecruiting ? '公开招募' : '仅邀请'),
              ]),
              _section([
                InkWell(
                  onTap: _offline
                      ? null
                      : () => setState(() => _termsAccepted = !_termsAccepted),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 20, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: const ValueKey('vip-create-terms'),
                          value: _termsAccepted,
                          onChanged: _offline
                              ? null
                              : (value) => setState(
                                  () => _termsAccepted = value ?? false,
                                ),
                          activeColor: legacyGold,
                          checkColor: Colors.black,
                          side: const BorderSide(color: legacyGold),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            '我已阅读组局、费用、取消和安全规则。创建后套餐、人数和费用方式不可由会员端修改。',
                            style: TextStyle(
                              color: legacyGold,
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showRules(context),
                          child: const Text(
                            '查看',
                            style: TextStyle(color: legacyGold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              if (_requoteLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      '正在刷新报价…',
                      style: TextStyle(color: legacyGold, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          Align(alignment: Alignment.bottomCenter, child: _bottomBar()),
        ],
      ),
    );
  }

  Widget _section(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: Color(0x16C9B69E),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0x22C9B69E)),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _valueRow(String label, String value, {bool accent = false}) {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: legacyGold, fontSize: 14),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: accent ? const Color(0xFFFCA800) : legacyGold,
                fontSize: 14,
                fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerRow({
    required Key key,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 66,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: legacyGold, fontSize: 14),
              ),
            ),
            Flexible(
              child: Material(
                key: key,
                color: const Color(0x15C9B69E),
                borderRadius: BorderRadius.circular(5),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE7D3BA),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0x99C9B69E),
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow() {
    final package = _packages[_packageIndex];
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '套餐价格：',
                style: TextStyle(color: legacyGold, fontSize: 14),
              ),
            ),
            Text(
              '¥${package.$2}.00 元',
              style: const TextStyle(color: Color(0xFFFCA800), fontSize: 15),
            ),
            const SizedBox(width: 8),
            Text(
              '原价¥${package.$3}.00',
              style: const TextStyle(
                color: Color(0xFF777777),
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required Key key,
    required String title,
    required String hint,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 12),
        child: Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: legacyGold, fontSize: 14),
                  children: [
                    TextSpan(text: title),
                    TextSpan(
                      text: '\n（$hint）',
                      style: const TextStyle(
                        color: Color(0x77555555),
                        fontSize: 10,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Switch(
              key: key,
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF9C8B76),
              activeThumbColor: Colors.white,
              inactiveTrackColor: const Color(0x22FFFFFF),
              inactiveThumbColor: const Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      key: const ValueKey('vip-create-bottom-bar'),
      height: 108,
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDDCCB8), Color(0xFF978774)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(color: Color(0xFF271F15)),
                    children: [
                      const TextSpan(
                        text: '实付¥ ',
                        style: TextStyle(fontSize: 14),
                      ),
                      TextSpan(
                        text: _hostDue.toString(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '.00 元'),
                    ],
                  ),
                ),
                Text(
                  _splitPerMember
                      ? '成员加入时参考应付 ¥$_memberDue.00'
                      : '局长请客，成员加入应付 ¥0.00',
                  style: const TextStyle(
                    color: Color(0xFF493C2C),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const ValueKey('vip-create-submit'),
            onPressed: _quoteExpired
                ? (_offline ? null : _refreshQuote)
                : (_canCreate ? _submit : null),
            style: FilledButton.styleFrom(
              minimumSize: const Size(108, 48),
              backgroundColor: const Color(0xFFF4EEE7),
              foregroundColor: const Color(0xFF271F15),
              disabledBackgroundColor: const Color(0x66877B6C),
              disabledForegroundColor: const Color(0x88746A5F),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: Text(
              _quoteExpired
                  ? '刷新报价'
                  : _submitting
                  ? '创建中…'
                  : '确认创建',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick({
    required String title,
    required List<String> options,
    required int selected,
    required ValueChanged<int> onSelected,
  }) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                style: const TextStyle(color: legacyGold, fontSize: 17),
              ),
            ),
            for (var index = 0; index < options.length; index++)
              ListTile(
                key: ValueKey('vip-create-option-$index'),
                title: Text(
                  options[index],
                  style: const TextStyle(color: Color(0xFFE7D3BA)),
                ),
                trailing: Icon(
                  index == selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: legacyGold,
                ),
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _changeAndRequote(() => onSelected(picked));
  }

  Future<void> _changeAndRequote(VoidCallback change) async {
    setState(() {
      change();
      _termsAccepted = false;
      _requoteLoading = true;
      if (_scenario == VipPartyCreateScenario.quoteChanged ||
          _scenario == VipPartyCreateScenario.inventoryConflict) {
        _scenario = VipPartyCreateScenario.ready;
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() => _requoteLoading = false);
  }

  void _refreshQuote() {
    setState(() {
      _scenario = VipPartyCreateScenario.ready;
      _termsAccepted = false;
    });
    showFakeResult(context, '报价已刷新');
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (_scenario == VipPartyCreateScenario.resultUnknown) {
      await _resultDialog(
        title: '创建结果确认中',
        message: '网络响应中断，系统正在确认创建结果；请勿重复提交，不会重复创建。',
      );
      return;
    }
    if (_hostDue == 0) {
      await _resultDialog(title: '组局创建成功', message: '组局席位已确认，当前实付 ¥0.00，无需支付。');
      return;
    }
    await _resultDialog(
      title: '待支付订单已生成',
      message:
          '局长待支付 ¥${_hostDue.toStringAsFixed(2)}，席位将保留 10 分钟，请在有效期内完成支付；支付成功前不会标记为已付款。',
    );
  }

  Future<void> _resultDialog({required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1511),
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFD8C8B8), height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了', style: TextStyle(color: legacyGold)),
          ),
        ],
      ),
    );
  }

  void _showRules(BuildContext context) {
    _resultDialog(
      title: 'VIP 组局规则',
      message: '创建者固定为局长。套餐、人数、费用方式和招募范围以确认创建时的报价为准。请文明饮酒、尊重同桌会员。',
    );
  }

  Future<void> _showScenarioSheet() async {
    final selected = await showModalBottomSheet<VipPartyCreateScenario>(
      context: context,
      backgroundColor: const Color(0xFF1A1511),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '创建页 Fake 状态',
                style: TextStyle(color: legacyGold, fontSize: 17),
              ),
            ),
            for (final option in VipPartyCreateScenario.values)
              ListTile(
                key: ValueKey('vip-create-scenario-${option.name}'),
                title: Text(switch (option) {
                  VipPartyCreateScenario.ready => '正常报价',
                  VipPartyCreateScenario.quoteChanged => '报价发生变化',
                  VipPartyCreateScenario.quoteExpired => '报价已过期',
                  VipPartyCreateScenario.inventoryConflict => '卡座库存冲突',
                  VipPartyCreateScenario.offline => '离线草稿',
                  VipPartyCreateScenario.resultUnknown => '提交结果未知',
                  VipPartyCreateScenario.zeroCash => '免付确认 / 0元创建',
                }, style: const TextStyle(color: Color(0xFFD8C8B8))),
                trailing: Icon(
                  option == _scenario
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: legacyGold,
                ),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scenario = selected;
      _termsAccepted = false;
      _requoteLoading = false;
      _submitting = false;
    });
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33252018),
        border: Border.all(color: const Color(0x66C9B69E)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(icon, color: legacyGold, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: legacyGold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
