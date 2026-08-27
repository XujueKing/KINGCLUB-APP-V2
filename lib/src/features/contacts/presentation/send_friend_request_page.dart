import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyMuted = Color(0xFFAAAAAA);
const _legacyInput = Color(0xFF313131);

enum SendFriendRequestResult { sent }

class SendFriendRequestPage extends StatefulWidget {
  const SendFriendRequestPage({
    super.key,
    required this.targetRef,
    required this.targetName,
  });

  final String targetRef;
  final String targetName;

  @override
  State<SendFriendRequestPage> createState() => _SendFriendRequestPageState();
}

class _SendFriendRequestPageState extends State<SendFriendRequestPage> {
  late final TextEditingController _messageController;
  late final TextEditingController _remarkController;
  bool _submitting = false;

  String get _initialMessage => '我是 KingClub 会员';

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _initialMessage)
      ..addListener(_onDraftChanged);
    _remarkController = TextEditingController(text: widget.targetName)
      ..addListener(_onDraftChanged);
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
            _LegacyRequestHeader(onBack: _requestBack),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                  ],
                ),
              ),
            ),
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
    Navigator.pop(context, SendFriendRequestResult.sent);
  }

  bool _containsControlCharacters(String value) {
    return value.codeUnits.any(
      (unit) => unit < 32 && unit != 9 && unit != 10 && unit != 13,
    );
  }

  Future<void> _requestBack() async {
    if (!_hasDraftChanges) {
      Navigator.pop(context);
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
    if (discard == true && mounted) Navigator.pop(context);
  }
}

class _LegacyRequestHeader extends StatelessWidget {
  const _LegacyRequestHeader({required this.onBack});

  final VoidCallback onBack;

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
          const Text(
            '申请添加朋友',
            style: TextStyle(color: _legacyGold, fontSize: 17),
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
