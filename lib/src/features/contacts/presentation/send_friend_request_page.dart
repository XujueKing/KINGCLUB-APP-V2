import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyMuted = Color(0xFFAAAAAA);
const _legacyInput = Color(0xFF313131);

enum SendFriendRequestResult { sent }

enum SendFriendRequestScenario {
  success,
  alreadyPending,
  alreadyFriends,
  resultUnknown,
  targetUnavailable,
  submitError,
  sessionInvalid,
}

class SendFriendRequestPage extends StatefulWidget {
  const SendFriendRequestPage({
    super.key,
    required this.targetRef,
    required this.targetName,
    this.initialScenario = SendFriendRequestScenario.success,
    this.onBack,
    this.onSent,
    this.onOpenChat,
    this.onSessionResetRequested,
  });

  final String targetRef;
  final String targetName;
  final SendFriendRequestScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onSent;
  final VoidCallback? onOpenChat;
  final VoidCallback? onSessionResetRequested;

  @override
  State<SendFriendRequestPage> createState() => _SendFriendRequestPageState();
}

class _SendFriendRequestPageState extends State<SendFriendRequestPage> {
  late final TextEditingController _messageController;
  late final TextEditingController _remarkController;
  bool _submitting = false;
  bool _resultUnknown = false;
  String? _submitError;
  late SendFriendRequestScenario _scenario;

  String get _initialMessage => '我是 KingClub 会员';

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    _messageController = TextEditingController(text: _initialMessage)
      ..addListener(_onDraftChanged);
    _remarkController = TextEditingController(text: widget.targetName)
      ..addListener(_onDraftChanged);
    if (_scenario == SendFriendRequestScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onDraftChanged)
      ..dispose();
    _remarkController
      ..removeListener(_onDraftChanged)
      ..dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasDraftChanges =>
      _messageController.text != _initialMessage ||
      _remarkController.text != widget.targetName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _LegacyRequestHeader(
              onBack: _requestBack,
              onTitleLongPress: _showScenarioPanel,
            ),
            Expanded(child: _buildBody()),
            if (_showsEditor)
              Padding(
                padding: const EdgeInsets.fromLTRB(46, 12, 46, 72),
                child: FilledButton(
                  key: const ValueKey('send-friend-submit'),
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: _legacyGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.black,
                          ),
                        )
                      : const Text('发送'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _showsEditor =>
      _scenario == SendFriendRequestScenario.success ||
      _scenario == SendFriendRequestScenario.resultUnknown ||
      _scenario == SendFriendRequestScenario.submitError;

  Widget _buildBody() {
    if (!_showsEditor) {
      final (icon, title, detail) = switch (_scenario) {
        SendFriendRequestScenario.alreadyPending => (
          Icons.schedule_outlined,
          '好友申请已发送',
          '请等待对方验证，不需要重复发送。',
        ),
        SendFriendRequestScenario.alreadyFriends => (
          Icons.people_outline,
          '你们已经是好友',
          '可以直接开始聊天。',
        ),
        SendFriendRequestScenario.targetUnavailable => (
          Icons.person_off_outlined,
          '暂时无法添加该用户',
          '对方资料不可用或当前不允许接收申请。',
        ),
        SendFriendRequestScenario.sessionInvalid => (
          Icons.lock_outline,
          '登录状态已失效',
          '申请草稿已清理。',
        ),
        _ => (Icons.info_outline, '状态不可用', '请返回后重试。'),
      };
      return Center(
        key: ValueKey('send-friend-state-${_scenario.name}'),
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _legacyGold, size: 62),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _legacyMuted),
              ),
              if (_scenario == SendFriendRequestScenario.alreadyFriends) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: widget.onOpenChat,
                  child: const Text('发消息'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          const _LegacyFieldLabel('发送添加朋友申请'),
          _LegacyRequestField(
            key: const ValueKey('send-friend-message'),
            controller: _messageController,
            maxLength: 80,
            hintText: _initialMessage,
          ),
          const _LegacyFieldLabel('设置备注名'),
          _LegacyRequestField(
            key: const ValueKey('send-friend-remark'),
            controller: _remarkController,
            maxLength: 24,
            hintText: widget.targetName,
          ),
          const SizedBox(height: 12),
          Text(
            '备注仅自己可见，对方接受后才会成为好友',
            style: TextStyle(
              color: _legacyGold.withValues(alpha: 0.38),
              fontSize: 12,
            ),
          ),
          if (_resultUnknown || _submitError != null) ...[
            const SizedBox(height: 16),
            Text(
              _resultUnknown ? '发送结果确认中，请勿重复提交' : _submitError!,
              key: ValueKey(
                _resultUnknown
                    ? 'send-friend-result-unknown'
                    : 'send-friend-submit-error',
              ),
              style: const TextStyle(color: Color(0xFFE06B6B)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_containsControlCharacters(_messageController.text) ||
        _containsControlCharacters(_remarkController.text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内容中不能包含控制字符')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    if (_scenario == SendFriendRequestScenario.resultUnknown) {
      setState(() {
        _submitting = false;
        _resultUnknown = true;
      });
      return;
    }
    if (_scenario == SendFriendRequestScenario.submitError) {
      setState(() {
        _submitting = false;
        _submitError = '发送失败，草稿已保留，请稍后重试';
      });
      return;
    }
    if (widget.onSent != null) {
      widget.onSent!();
    } else {
      Navigator.pop(context, SendFriendRequestResult.sent);
    }
  }

  bool _containsControlCharacters(String value) {
    return value.codeUnits.any(
      (unit) => unit < 32 && unit != 9 && unit != 10 && unit != 13,
    );
  }

  Future<void> _requestBack() async {
    if (!_hasDraftChanges) {
      _finishBack();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171411),
        title: const Text('放弃本次申请？'),
        content: const Text('验证消息或备注名尚未发送，返回后不会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            key: const ValueKey('send-friend-discard'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _finishBack();
  }

  Future<void> _showScenarioPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '发送申请 UI Mock 场景',
                style: TextStyle(color: _legacyGold),
              ),
            ),
            for (final scenario in SendFriendRequestScenario.values)
              ListTile(
                key: ValueKey('send-friend-scenario-${scenario.name}'),
                title: Text(
                  scenario.name,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _scenario = scenario;
                    _submitting = false;
                    _resultUnknown = false;
                    _submitError = null;
                  });
                  if (scenario == SendFriendRequestScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionInvalid() async {
    _messageController.clear();
    _remarkController.clear();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('send-friend-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('验证消息和私有备注已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('send-friend-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _LegacyRequestHeader extends StatelessWidget {
  const _LegacyRequestHeader({required this.onBack, this.onTitleLongPress});

  final VoidCallback onBack;
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: SizedBox.square(
                dimension: 48,
                child: IconButton(
                  key: const ValueKey('send-friend-back'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: Image.asset(
                    'assets/legacy/friendship/back.png',
                    width: 22,
                    color: _legacyGold,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('send-friend-title'),
            onLongPress: onTitleLongPress,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Text(
                '申请添加朋友',
                style: TextStyle(color: _legacyGold, fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyFieldLabel extends StatelessWidget {
  const _LegacyFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(color: _legacyMuted, fontSize: 13),
        ),
      ),
    );
  }
}

class _LegacyRequestField extends StatelessWidget {
  const _LegacyRequestField({
    super.key,
    required this.controller,
    required this.maxLength,
    required this.hintText,
  });

  final TextEditingController controller;
  final int maxLength;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '${controller.text.characters.length}/$maxLength',
        counterStyle: const TextStyle(color: Color(0xFF666666), fontSize: 11),
        filled: true,
        fillColor: _legacyInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: _legacyGold, width: 1),
        ),
      ),
    );
  }
}
