import 'package:flutter/material.dart';

const _legacyGold = Color(0xFFC9B69E);
const _legacyPanel = Color(0x151C1814);
const _legacyLine = Color(0x161C1814);

enum RelationshipChangeResult { blocked, deleted }

class RelationshipPermissionsPage extends StatefulWidget {
  const RelationshipPermissionsPage({
    super.key,
    required this.targetRef,
    required this.displayName,
    this.isMale = true,
  });

  final String targetRef;
  final String displayName;
  final bool isMale;

  @override
  State<RelationshipPermissionsPage> createState() =>
      _RelationshipPermissionsPageState();
}

class _RelationshipPermissionsPageState
    extends State<RelationshipPermissionsPage> {
  bool _messagesOnly = false;
  bool _hideMine = false;
  bool _hideTheirs = false;
  bool _busy = false;

  String get _pronoun => widget.isMale ? '他' : '她';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PermissionTitleBar(onBack: () => Navigator.pop(context)),
              const _PermissionSectionLabel('设置权限'),
              _ChoiceRow(
                key: const ValueKey('relationship-standard'),
                label: '聊天、朋友圈、交友等',
                selected: !_messagesOnly,
                onTap: () => setState(() => _messagesOnly = false),
              ),
              _ChoiceRow(
                key: const ValueKey('relationship-messages-only'),
                label: '仅聊天',
                selected: _messagesOnly,
                onTap: () => setState(() => _messagesOnly = true),
              ),
              const _PermissionSectionLabel('朋友圈和状态'),
              _SwitchRow(
                key: const ValueKey('relationship-hide-mine'),
                label: '不让$_pronoun看',
                value: _hideMine,
                onChanged: (value) => setState(() => _hideMine = value),
              ),
              _SwitchRow(
                key: const ValueKey('relationship-hide-theirs'),
                label: '不看$_pronoun',
                value: _hideTheirs,
                onChanged: (value) => setState(() => _hideTheirs = value),
              ),
              const SizedBox(height: 10),
              _SwitchRow(
                key: const ValueKey('relationship-block'),
                label: '加入黑名单',
                value: false,
                onChanged: (value) {
                  if (value) _confirmBlock();
                },
              ),
              const SizedBox(height: 10),
              _DestructiveRow(onTap: _confirmDelete),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlock() async {
    final confirmed = await _showConfirmation(
      title: '加入黑名单',
      message: '将终止与 ${widget.displayName} 的好友关系、取消待处理申请并禁止互发消息。解除后不会自动恢复好友。',
      action: '确认拉黑',
    );
    if (confirmed) await _finish(RelationshipChangeResult.blocked);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await _showConfirmation(
      title: '删除联系人',
      message: '将解除与 ${widget.displayName} 的好友关系，但不会加入黑名单，也不会在此处删除历史会话。',
      action: '确认删除',
    );
    if (confirmed) await _finish(RelationshipChangeResult.deleted);
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF171411),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              TextButton(
                key: ValueKey('relationship-confirm-$action'),
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7373),
                ),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _finish(RelationshipChangeResult result) async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.pop(context, result);
  }
}

class _PermissionTitleBar extends StatelessWidget {
  const _PermissionTitleBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            child: IconButton(
              key: const ValueKey('relationship-permissions-back'),
              tooltip: '返回',
              onPressed: onBack,
              icon: Image.asset(
                'assets/legacy/friendship/back.png',
                width: 22,
                color: _legacyGold,
              ),
            ),
          ),
          const Text('权限', style: TextStyle(color: _legacyGold, fontSize: 17)),
        ],
      ),
    );
  }
}

class _PermissionSectionLabel extends StatelessWidget {
  const _PermissionSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 25, 46, 10),
      child: Text(
        label,
        style: const TextStyle(color: _legacyGold, fontSize: 13),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _legacyGold, fontSize: 15),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: _legacyGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        height: 54,
        padding: const EdgeInsets.only(left: 46, right: 32),
        decoration: const BoxDecoration(
          color: _legacyPanel,
          border: Border(bottom: BorderSide(color: _legacyLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: _legacyGold, fontSize: 15),
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: value,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF07C160),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: _legacyGold.withValues(alpha: 0.14),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _legacyPanel,
      child: InkWell(
        key: const ValueKey('relationship-delete'),
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: _legacyLine),
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            '删除联系人',
            style: TextStyle(color: Color(0xFFFF7373), fontSize: 15),
          ),
        ),
      ),
    );
  }
}
