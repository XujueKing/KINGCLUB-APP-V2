import 'package:flutter/material.dart';

class EditableProfileResult {
  const EditableProfileResult({
    required this.nickname,
    required this.signature,
  });

  final String nickname;
  final String signature;
}

enum EditProfileMockSaveOutcome {
  success,
  versionConflict,
  resultUnknown,
  saveError,
  sessionInvalid,
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    required this.nickname,
    required this.signature,
    this.onBack,
    this.onSaved,
    this.onSessionResetRequested,
    super.key,
  });

  final String nickname;
  final String signature;
  final VoidCallback? onBack;
  final ValueChanged<EditableProfileResult>? onSaved;
  final VoidCallback? onSessionResetRequested;

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
  bool _saving = false;
  EditProfileMockSaveOutcome _saveOutcome = EditProfileMockSaveOutcome.success;
  String? _statusMessage;

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
              _LegacyHeader(
                title: '我的个人信息',
                onBack: _handleBack,
                onTitleLongPress: _showMockScenarios,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                  children: [
                    if (_statusMessage != null) ...[
                      _StatusBanner(
                        message: _statusMessage!,
                        onDismiss: () => setState(() => _statusMessage = null),
                      ),
                      const SizedBox(height: 22),
                    ],
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
                    _row('所在城市', _city, keyName: 'city', maxLength: 30),
                    _row(
                      '职业',
                      _occupation,
                      keyName: 'occupation',
                      maxLength: 40,
                    ),
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
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                key: ValueKey('edit-profile-saving'),
                                strokeWidth: 2.4,
                                color: Color(0xFF241B13),
                              ),
                            )
                          : const Text(
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
            final valueText = Text(
              value,
              maxLines: largeText ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
            );
            if (largeText) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: _gold, fontSize: 16),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: valueText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _EditRowArrow(keyName: keyName),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Text(label, style: const TextStyle(color: _gold, fontSize: 16)),
                const SizedBox(width: 18),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: valueText,
                  ),
                ),
                const SizedBox(width: 10),
                _EditRowArrow(keyName: keyName),
              ],
            );
          },
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
                final validationError = _validateField(keyName, text);
                if (validationError != null) {
                  setDialogState(() => error = validationError);
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

  String? _validateField(String keyName, String text) {
    if (keyName == 'nickname' && (text.length < 2 || text.length > 16)) {
      return '昵称需要 2～16 个字符';
    }
    if (keyName == 'height' && text.isNotEmpty) {
      final value = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (value == null || value < 120 || value > 230) {
        return '身高请填写 120～230 cm';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final nicknameError = _validateField('nickname', _nickname.trim());
    final heightError = _validateField('height', _height.trim());
    if (nicknameError != null || heightError != null) {
      setState(() => _statusMessage = nicknameError ?? heightError);
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    switch (_saveOutcome) {
      case EditProfileMockSaveOutcome.success:
        _finishSaved();
      case EditProfileMockSaveOutcome.versionConflict:
        setState(() => _saving = false);
        await _showVersionConflict();
      case EditProfileMockSaveOutcome.resultUnknown:
        setState(() => _saving = false);
        await _showResultUnknown();
      case EditProfileMockSaveOutcome.saveError:
        setState(() {
          _saving = false;
          _statusMessage = '保存失败，草稿已保留，请稍后重试。';
        });
      case EditProfileMockSaveOutcome.sessionInvalid:
        setState(() => _saving = false);
        await _showSessionInvalid();
    }
  }

  void _finishSaved() {
    final result = EditableProfileResult(
      nickname: _nickname,
      signature: _signature,
    );
    if (widget.onSaved != null) {
      widget.onSaved!(result);
    } else {
      Navigator.pop(context, result);
    }
  }

  Future<void> _showAvatarNotice() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '头像 Fake 流程',
                style: TextStyle(
                  color: _gold,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '头像按当前确认保持空白，不会读取真实相册。',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              _mockAction(
                sheetContext,
                key: 'avatar-cancelled',
                label: '模拟：取消选择',
                message: '已取消头像选择，其他草稿未变更。',
              ),
              _mockAction(
                sheetContext,
                key: 'avatar-permission-denied',
                label: '模拟：相册权限被拒绝',
                message: '未获得相册权限，可继续编辑其他资料。',
              ),
              _mockAction(
                sheetContext,
                key: 'avatar-upload-failed',
                label: '模拟：格式/上传/Commit 失败',
                message: '头像处理失败，仅头像受影响，其他草稿已保留。',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    if (_dirty) {
      _confirmDiscard();
    } else {
      _finishBack();
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
    if (discard == true && mounted) _finishBack();
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
  }

  Widget _mockAction(
    BuildContext sheetContext, {
    required String key,
    required String label,
    required String message,
  }) {
    return ListTile(
      key: ValueKey('edit-profile-$key'),
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: _muted),
      onTap: () {
        Navigator.pop(sheetContext);
        setState(() => _statusMessage = message);
      },
    );
  }

  Future<void> _showMockScenarios() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          children: [
            const Text(
              '编辑资料 UI Mock 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择下一次保存的离线结果，不会请求服务器。',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 10),
            for (final outcome in EditProfileMockSaveOutcome.values)
              ListTile(
                key: ValueKey('edit-profile-scenario-${outcome.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _outcomeLabel(outcome),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: outcome == _saveOutcome
                    ? const Icon(Icons.check, color: _gold)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _saveOutcome = outcome;
                    _statusMessage = '已设置：${_outcomeLabel(outcome)}';
                  });
                },
              ),
            ListTile(
              key: const ValueKey('edit-profile-scenario-catalog-expired'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '模拟：偏好目录过期并刷新',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _statusMessage = '偏好目录已刷新，仍有效的选项已保留。';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _outcomeLabel(EditProfileMockSaveOutcome outcome) {
    return switch (outcome) {
      EditProfileMockSaveOutcome.success => '下次保存：成功',
      EditProfileMockSaveOutcome.versionConflict => '下次保存：资料版本冲突',
      EditProfileMockSaveOutcome.resultUnknown => '下次保存：结果未知',
      EditProfileMockSaveOutcome.saveError => '下次保存：失败',
      EditProfileMockSaveOutcome.sessionInvalid => '下次保存：会话失效',
    };
  }

  Future<void> _showVersionConflict() async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('edit-profile-version-conflict'),
        title: const Text('资料已发生变化'),
        content: const Text('服务端 Fake 版本更新，不会静默覆盖。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留当前草稿'),
          ),
          FilledButton(
            key: const ValueKey('edit-profile-conflict-reload'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _saveOutcome = EditProfileMockSaveOutcome.success;
      if (reload == true) {
        _nickname = widget.nickname;
        _signature = widget.signature;
        _dirty = false;
        _statusMessage = '已重新加载最新 Fake 资料。';
      } else {
        _statusMessage = '已保留当前草稿，可手动调整后再保存。';
      }
    });
  }

  Future<void> _showResultUnknown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('edit-profile-result-unknown'),
        title: const Text('保存结果待确认'),
        content: const Text('不会盲目重复提交，可先查询最新 Fake 版本。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            key: const ValueKey('edit-profile-query-latest'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('查询最新资料'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _saveOutcome = EditProfileMockSaveOutcome.success);
    if (confirmed == true) {
      _finishSaved();
    } else {
      setState(() => _statusMessage = '草稿已保留，未发起第二次提交。');
    }
  }

  Future<void> _showSessionInvalid() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('edit-profile-session-invalid'),
        title: const Text('登录状态已失效'),
        content: const Text('本地草稿和媒体临时引用已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('edit-profile-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _nickname = '';
    _signature = '';
    if (widget.onSessionResetRequested != null) {
      widget.onSessionResetRequested!();
    } else {
      Navigator.pop(context);
    }
  }
}

class _EditRowArrow extends StatelessWidget {
  const _EditRowArrow({required this.keyName});

  final String keyName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('edit-profile-arrow-$keyName'),
      width: 24,
      child: const Center(
        child: Icon(
          Icons.chevron_right,
          color: _EditProfilePageState._muted,
          size: 21,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('edit-profile-status-banner'),
      padding: const EdgeInsets.fromLTRB(14, 11, 4, 11),
      decoration: BoxDecoration(
        color: const Color(0xFF241F1A),
        border: Border.all(color: const Color(0x66756A5E)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFC9B69E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFD9D0C5), height: 1.35),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, color: Color(0xFF8C8378), size: 18),
          ),
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
      padding: const EdgeInsets.only(top: 28, bottom: 5),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF756A5E), fontSize: 13),
      ),
    );
  }
}

class _LegacyHeader extends StatelessWidget {
  const _LegacyHeader({
    required this.title,
    required this.onBack,
    required this.onTitleLongPress,
  });
  final String title;
  final VoidCallback onBack;
  final VoidCallback onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
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
            child: GestureDetector(
              key: const ValueKey('edit-profile-title'),
              onLongPress: onTitleLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC9B69E),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
