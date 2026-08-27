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

class FriendRemarkPage extends StatefulWidget {
  const FriendRemarkPage({
    super.key,
    required this.targetRef,
    required this.initialRemark,
    required this.signature,
    this.initialDescription = '周末一起听现场，也喜欢摄影和旅行',
  });

  final String targetRef;
  final String initialRemark;
  final String initialDescription;
  final String signature;

  @override
  State<FriendRemarkPage> createState() => _FriendRemarkPageState();
}

class _FriendRemarkPageState extends State<FriendRemarkPage> {
  late String _remark;
  late String _description;

  @override
  void initState() {
    super.initState();
    _remark = widget.initialRemark;
    _description = widget.initialDescription;
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
            const _SectionLabel('备注'),
            _LegacyInfoRow(
              key: const ValueKey('friend-remark-name'),
              label: '备注名',
              value: _remark,
              onTap: () => _editField(
                title: '备注名',
                value: _remark,
                maxLength: 24,
                onSaved: (value) => setState(() => _remark = value),
              ),
            ),
            _LegacyInfoRow(
              key: const ValueKey('friend-remark-description'),
              label: '说明',
              value: _description,
              onTap: () => _editField(
                title: '说明',
                value: _description,
                maxLength: 120,
                maxLines: 4,
                onSaved: (value) => setState(() => _description = value),
              ),
            ),
            const _SectionLabel('更多信息'),
            _LegacyInfoRow(label: '签名', value: widget.signature),
            const _LegacyInfoRow(label: '来源', value: '来自 扫一扫'),
            const _LegacyInfoRow(label: '添加时间', value: '2026-08-25'),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _popPage() {
    Navigator.pop(
      context,
      FriendRemarkResult(remark: _remark, description: _description),
    );
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
            left: 18,
            child: IconButton(
              key: ValueKey('relationship-back-$title'),
              tooltip: '返回',
              onPressed: onBack,
              icon: Image.asset(
                'assets/legacy/friendship/back.png',
                width: 22,
                color: _legacyGold,
              ),
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
