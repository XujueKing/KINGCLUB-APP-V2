import 'package:flutter/material.dart';

class EditableProfileResult {
  const EditableProfileResult({
    required this.nickname,
    required this.signature,
  });

  final String nickname;
  final String signature;
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    required this.nickname,
    required this.signature,
    super.key,
  });

  final String nickname;
  final String signature;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF8C8378);

  late String _nickname;
  late String _signature;
  String _city = '河南省 · 安阳市';
  String _occupation = '自由职业';
  String _height = '168 cm';
  String _activeTime = '周末晚间';
  String _music = '流行 · R&B';
  String _drink = '微醺';
  String _party = '朋友组局';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname;
    _signature = widget.signature;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _LegacyHeader(title: '我的个人信息', onBack: _handleBack),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                  children: [
                    Center(
                      child: InkWell(
                        key: const ValueKey('edit-profile-empty-avatar'),
                        borderRadius: BorderRadius.circular(58),
                        onTap: _showAvatarNotice,
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0ECE5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    _row('昵称', _nickname, keyName: 'nickname'),
                    _row(
                      '个性签名',
                      _signature.isEmpty ? '未填写' : _signature,
                      keyName: 'signature',
                      maxLength: 40,
                    ),
                    _row('所在城市', _city, keyName: 'city'),
                    _row('职业', _occupation, keyName: 'occupation'),
                    _row('身高', _height, keyName: 'height'),
                    const _SectionLabel('兴趣偏好'),
                    _row('常去时段', _activeTime, keyName: 'activeTime'),
                    _row('音乐偏好', _music, keyName: 'music'),
                    _row('饮酒偏好', _drink, keyName: 'drink'),
                    _row('组局偏好', _party, keyName: 'party'),
                    const SizedBox(height: 34),
                    FilledButton(
                      key: const ValueKey('edit-profile-save'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: _gold,
                        foregroundColor: const Color(0xFF241B13),
                      ),
                      onPressed: _save,
                      child: const Text(
                        '保存',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '当前为离线 UI Mock，资料不会上传服务器。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    required String keyName,
    int maxLength = 16,
  }) {
    return InkWell(
      key: ValueKey('edit-profile-$keyName'),
      onTap: () =>
          _edit(label, value == '未填写' ? '' : value, keyName, maxLength),
      child: Container(
        constraints: const BoxConstraints(minHeight: 61),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: _gold, fontSize: 16)),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: _muted, size: 21),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    String label,
    String value,
    String keyName,
    int maxLength,
  ) async {
    final controller = TextEditingController(text: value);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBAFDA),
          title: Text(
            '修改$label',
            style: const TextStyle(color: Color(0xFF8E075C)),
          ),
          content: TextField(
            key: ValueKey('edit-profile-input-$keyName'),
            controller: controller,
            autofocus: true,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (keyName == 'nickname' && text.isEmpty) {
                  setDialogState(() => error = '昵称不能为空');
                  return;
                }
                Navigator.pop(dialogContext, text);
              },
              child: const Text('确认修改'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _dirty = true;
      switch (keyName) {
        case 'nickname':
          _nickname = result;
        case 'signature':
          _signature = result;
        case 'city':
          _city = result;
        case 'occupation':
          _occupation = result;
        case 'height':
          _height = result;
        case 'activeTime':
          _activeTime = result;
        case 'music':
          _music = result;
        case 'drink':
          _drink = result;
        case 'party':
          _party = result;
      }
    });
  }

  void _save() {
    if (_nickname.trim().isEmpty) return;
    Navigator.pop(
      context,
      EditableProfileResult(nickname: _nickname, signature: _signature),
    );
  }

  void _showAvatarNotice() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('头像按当前确认保持空白，暂不读取相册。')));
  }

  void _handleBack() {
    if (_dirty) {
      _confirmDiscard();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('尚未保存的 Fake 资料将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 5),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF756A5E), fontSize: 13),
      ),
    );
  }
}

class _LegacyHeader extends StatelessWidget {
  const _LegacyHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('legacy-back'),
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFFC9B69E),
              size: 21,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFC9B69E),
                  fontSize: 18,
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
