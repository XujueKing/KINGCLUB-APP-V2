import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF9E9589);
  bool _acknowledged = false;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _DeletionHeader(onBack: () => Navigator.pop(context)),
            Expanded(child: _completed ? _completedView() : _content()),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    const checks = [
      ('无未结订单', '已通过'),
      ('余额、退款与优惠权益', '已处理'),
      ('私人储物柜物品', '无待取物品'),
      ('申诉与纠纷', '无处理中事项'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFC9B69E),
          size: 68,
        ),
        const SizedBox(height: 18),
        const Text(
          '永久注销 KingClub',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '仅注销 KingClub 会员与业务资料；物业账号、物业数据及共享身份不受影响。',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.6),
        ),
        const SizedBox(height: 30),
        _section('注销后将放弃以下权益与数据', const [
          '无法继续登录 KingClub 或恢复历史会员资料',
          '无法查询历史订单、聊天和活动记录',
          '余额、金币、礼品券及优惠权益不可恢复',
          '依法必须留存的交易与安全记录将在期限内保留',
        ]),
        const SizedBox(height: 24),
        const Text(
          '注销资格检查',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...checks.map(
          (item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF8DA783),
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.$1, style: const TextStyle(color: _gold)),
                ),
                Text(
                  item.$2,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        CheckboxListTile(
          key: const ValueKey('account-deletion-ack'),
          value: _acknowledged,
          activeColor: _gold,
          checkColor: Colors.black,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) => setState(() => _acknowledged = value ?? false),
          title: const Text(
            '我已阅读并知悉注销影响与数据处理说明',
            style: TextStyle(color: _gold, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('account-deletion-start'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFF7F2626),
            disabledBackgroundColor: const Color(0xFF392323),
          ),
          onPressed: _acknowledged ? _verifySms : null,
          child: const Text('完成短信验证并永久注销'),
        ),
        const SizedBox(height: 12),
        const Text(
          'UI Mock：不会注销真实账号或清理真实会话。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF554D44), fontSize: 11),
        ),
      ],
    );
  }

  Widget _section(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15120F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: _muted,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifySms() async {
    final controller = TextEditingController();
    String? error;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('短信安全验证'),
          content: TextField(
            key: const ValueKey('account-deletion-sms-input'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: '验证码',
              helperText: 'UI 测试验证码：888888',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text != '888888') {
                  setDialogState(() => error = '验证码不正确');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('验证'),
            ),
          ],
        ),
      ),
    );
    if (verified == true && mounted) _finalConfirm();
  }

  Future<void> _finalConfirm() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('最后确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此操作不可恢复。请输入“永久注销”继续。'),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('account-deletion-confirm-input'),
              controller: controller,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8C2929),
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim() == '永久注销'),
            child: const Text('确认永久注销'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) setState(() => _completed = true);
  }

  Widget _completedView() {
    return Center(
      key: const ValueKey('account-deletion-completed'),
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: _gold, size: 76),
            const SizedBox(height: 22),
            const Text(
              'Fake 注销流程已完成',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '真实 KingClub 与物业账号均未发生变化。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回设置'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletionHeader extends StatelessWidget {
  const _DeletionHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFFC9B69E),
              size: 21,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '账号注销',
                style: TextStyle(
                  color: Color(0xFFC9B69E),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
