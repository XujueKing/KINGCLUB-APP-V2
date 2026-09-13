import '../../messaging/data/messaging_repository.dart';

import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/core/design_system/king_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyPanel = Color(0x151C1814);
const _legacyLine = Color(0x161C1814);

class FriendRemarkResult {
  const FriendRemarkResult({required this.remark, required this.description});

  final String remark;
  final String description;
}

enum FriendRemarkScenario { ready, readOnly, saveError, sessionInvalid }

class FriendRemarkPage extends StatefulWidget {
  const FriendRemarkPage({
    super.key,
    required this.targetRef,
    required this.initialRemark,
    required this.signature,
    this.initialDescription = '周末一起听现场，也喜欢摄影和旅行',
    this.initialScenario = FriendRemarkScenario.ready,
    this.repository,
    this.onBack,
    this.onSaved,
    this.onSessionResetRequested,
  });

  final MessagingRepository? repository;
  final String targetRef;
  final String initialRemark;
  final String initialDescription;
  final String signature;
  final FriendRemarkScenario initialScenario;
  final VoidCallback? onBack;
  final ValueChanged<FriendRemarkResult>? onSaved;
  final VoidCallback? onSessionResetRequested;

  @override
  State<FriendRemarkPage> createState() => _FriendRemarkPageState();
}

class _FriendRemarkPageState extends State<FriendRemarkPage> {
  bool _saving = false;
  late String _remark;
  late String _description;
  late FriendRemarkScenario _scenario;

  @override
  void initState() {
    super.initState();
    _remark = widget.initialRemark;
    _description = widget.repository == null ? widget.initialDescription : '';
    _scenario = widget.initialScenario;
    if (_scenario == FriendRemarkScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LegacyTitleBar(title: '朋友资料', onBack: _popPage),
            if (_scenario != FriendRemarkScenario.ready)
              _ScenarioBanner(
                text: switch (_scenario) {
                  FriendRemarkScenario.readOnly => '当前离线，仅可查看已缓存资料',
                  FriendRemarkScenario.saveError => '保存会失败：用于验收草稿保留',
                  FriendRemarkScenario.sessionInvalid => '登录状态已失效，编辑已停用',
                  FriendRemarkScenario.ready => '',
                },
              ),
            const _SectionLabel('备注'),
            _LegacyInfoRow(
              key: const ValueKey('friend-remark-name'),
              label: '备注名',
              value: _remark,
              onTap: _canEdit
                  ? () => _editField(
                      title: '备注名',
                      value: _remark,
                      maxLength: 24,
                      onSaved: (value) => setState(() => _remark = value),
                    )
                  : null,
            ),
            if (widget.repository == null)
              _LegacyInfoRow(
                key: const ValueKey('friend-remark-description'),
                label: '说明',
                value: _description,
                onTap: _canEdit
                    ? () => _editField(
                        title: '说明',
                        value: _description,
                        maxLength: 120,
                        maxLines: 4,
                        onSaved: (value) =>
                            setState(() => _description = value),
                      )
                    : null,
              ),
            const _SectionLabel('更多信息'),
            _LegacyInfoRow(label: '签名', value: widget.signature),
            if (widget.repository == null)
              const _LegacyInfoRow(label: '来源', value: '来自 扫一扫'),
            if (widget.repository == null)
              const _LegacyInfoRow(label: '添加时间', value: '2026-08-25'),
            const Spacer(),
            if (widget.repository != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _saving ? null : _popPage,
                  child: Text(_saving ? '正在保存' : '保存'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _canEdit =>
      !_saving &&
      (_scenario == FriendRemarkScenario.ready ||
          _scenario == FriendRemarkScenario.saveError);

  Future<void> _popPage() async {
    if (_saving) return;
    if (widget.repository != null) {
      setState(() => _saving = true);
      try {
        await widget.repository!.settings(
          widget.targetRef,
          remark: _remark.trim(),
        );
        if (!mounted) return;
      } catch (e) {
        if (mounted) KingNotice.of(context).show(e.toString());
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    final result = FriendRemarkResult(
      remark: _remark,
      description: _description,
    );
    if (_scenario == FriendRemarkScenario.saveError) {
      KingNotice.of(context)
          .showSnackBar(const SnackBar(content: Text('保存失败，修改内容仍保留在当前页面')));
      return;
    }
    if (widget.onSaved != null) widget.onSaved!(result);
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context, result);
    }
  }

  Future<void> _showSessionInvalid() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('friend-remark-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('已停止编辑朋友资料，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('friend-remark-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  Future<void> _editField({
    required String title,
    required String value,
    required int maxLength,
    required ValueChanged<String> onSaved,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: value);
    var draft = value;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '修改$title',
                  style: const TextStyle(
                    color: Color(0xFF53493D),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: ValueKey('friend-remark-input-$title'),
                  controller: controller,
                  autofocus: true,
                  maxLength: maxLength,
                  maxLines: maxLines,
                  minLines: 1,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  onChanged: (value) {
                    draft = value;
                    setDialogState(() {});
                  },
                  style: const TextStyle(color: Color(0xFF53493D)),
                  decoration: InputDecoration(
                    counterText: '${draft.characters.length}/$maxLength',
                    counterStyle: const TextStyle(color: Color(0xFF7A6C5C)),
                    filled: true,
                    fillColor: const Color(0xFFE7D6C1),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFA08E77)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('friend-remark-cancel'),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('friend-remark-confirm'),
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          controller.text.trim(),
                        ),
                        child: const Text('确认修改'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) onSaved(result);
  }
}

class _ScenarioBanner extends StatelessWidget {
  const _ScenarioBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('friend-remark-scenario-banner'),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
    color: const Color(0xFF241F19),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _legacyGold, fontSize: 12),
    ),
  );
}

class _LegacyTitleBar extends StatelessWidget {
  const _LegacyTitleBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: KingBackButton.leftOffset(context),
            top: KingBackButton.safeAreaOffset.dy,
            child: KingBackButton(
              key: ValueKey('relationship-back-$title'),
              tooltip: '返回',
              onPressed: onBack,
            ),
          ),
          Text(title, style: const TextStyle(color: _legacyGold, fontSize: 17)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 25, 46, 10),
      child: Text(
        label,
        style: TextStyle(
          color: _legacyGold.withValues(alpha: 0.45),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LegacyInfoRow extends StatelessWidget {
  const _LegacyInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _legacyPanel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 46),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _legacyLine)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(color: _legacyGold, fontSize: 15),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: _legacyGold.withValues(alpha: 0.72),
                    fontSize: 14,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 10),
                Image.asset(
                  'assets/legacy/friendship/next.png',
                  width: 15,
                  color: _legacyGold.withValues(alpha: 0.65),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
