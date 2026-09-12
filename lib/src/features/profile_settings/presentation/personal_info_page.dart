import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design_system/king_components.dart';
import '../data/profile_avatar_store.dart';
import 'avatar_crop_page.dart';
import 'payment_security_page.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({
    super.key,
    this.onBack,
    this.onOpenPaymentSecurity,
    this.avatarStore,
    this.pickAvatarImage,
    this.adjustAvatarImage,
  });

  final VoidCallback? onBack;
  final VoidCallback? onOpenPaymentSecurity;
  final ProfileAvatarStore? avatarStore;
  final Future<String?> Function()? pickAvatarImage;
  final Future<String?> Function(String sourcePath)? adjustAvatarImage;

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _valueColor = Color(0xFFAAAAAA);
  static const _assetRoot = 'assets/legacy/profile';

  String _memberName = '';
  String _signature = '还未设置';
  String? _avatarPath;
  bool _avatarBusy = false;

  ProfileAvatarStore get _avatarStore =>
      widget.avatarStore ?? LocalProfileAvatarStore.instance;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = math.min(
              constraints.maxWidth,
              MediaQuery.sizeOf(context).width,
            );
            final scale = viewportWidth / 750;
            final contentWidth = math.min(660 * scale, viewportWidth - 28);

            return Column(
              children: [
                _PersonalInfoHeader(onBack: _finishBack),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('personal-info-scroll'),
                    padding: EdgeInsets.only(bottom: 80 * scale),
                    child: Column(
                      children: [
                        SizedBox(height: 20 * scale),
                        Semantics(
                          button: true,
                          label: '更换头像',
                          child: InkWell(
                            key: const ValueKey('personal-info-avatar-action'),
                            customBorder: const CircleBorder(),
                            onTap: _avatarBusy ? null : _changeAvatar,
                            child: ClipOval(
                              child: SizedBox.square(
                                dimension: 200 * scale,
                                child: _avatarPath == null
                                    ? Image.asset(
                                        '$_assetRoot/touxiang.png',
                                        key: const ValueKey(
                                          'personal-info-avatar',
                                        ),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                      )
                                    : Image.file(
                                        File(_avatarPath!),
                                        key: const ValueKey(
                                          'personal-info-avatar',
                                        ),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder: (_, _, _) => Image.asset(
                                          '$_assetRoot/touxiang.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 60 * scale),
                        SizedBox(
                          width: contentWidth,
                          child: Column(
                            children: [
                              _row(
                                id: 'member-name',
                                label: '会员称呼',
                                value: _memberName,
                                editable: true,
                                scale: scale,
                                onTap: () => _editText(
                                  title: '会员称呼',
                                  currentValue: _memberName,
                                  onChanged: (value) =>
                                      setState(() => _memberName = value),
                                ),
                              ),
                              _row(
                                id: 'signature',
                                label: '签名',
                                value: _signature,
                                editable: true,
                                scale: scale,
                                onTap: () => _editText(
                                  title: '签名',
                                  currentValue: _signature == '还未设置'
                                      ? ''
                                      : _signature,
                                  maxLength: 40,
                                  onChanged: (value) => setState(
                                    () => _signature = value.isEmpty
                                        ? '还未设置'
                                        : value,
                                  ),
                                ),
                              ),
                              _row(
                                id: 'age-gender',
                                label: '年龄/性别',
                                value: '24岁/女',
                                scale: scale,
                              ),
                              _row(
                                id: 'appearance',
                                label: '颜值',
                                value: '89分',
                                scale: scale,
                              ),
                              _row(
                                id: 'energy-level',
                                label: '能量值 | 等级',
                                value: '200 | 1',
                                leadingAsset: 'nengliang.png',
                                scale: scale,
                              ),
                              _row(
                                id: 'spirit-root',
                                label: '灵根',
                                value: '木',
                                scale: scale,
                              ),
                              _row(
                                id: 'mobile',
                                label: '手机号码',
                                value: '186****3253',
                                scale: scale,
                              ),
                              _row(
                                id: 'member-id',
                                label: '会员号',
                                value: 'K45600000799',
                                scale: scale,
                              ),
                              _row(
                                id: 'payment-password',
                                label: '修改支付密码',
                                value: '********',
                                editable: true,
                                scale: scale,
                                onTap: _openPaymentSecurity,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row({
    required String id,
    required String label,
    required String value,
    required double scale,
    bool editable = false,
    String? leadingAsset,
    VoidCallback? onTap,
  }) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: EdgeInsets.symmetric(
        horizontal: 30 * scale,
        vertical: 26 * scale,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
      ),
      child: Row(
        children: [
          if (leadingAsset != null) ...[
            Image.asset(
              '$_assetRoot/$leadingAsset',
              width: 24 * scale,
              height: 36 * scale,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            SizedBox(width: 12 * scale),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _gold,
                fontSize: 30 * scale,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(
            width: 286 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _valueColor,
                      fontSize: 28 * scale,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                SizedBox(width: 20 * scale),
                SizedBox(
                  key: ValueKey('personal-info-arrow-$id'),
                  width: 12 * scale,
                  child: editable
                      ? Image.asset(
                          '$_assetRoot/next.png',
                          width: 12 * scale,
                          height: 19 * scale,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!editable) {
      return KeyedSubtree(key: ValueKey('personal-info-$id'), child: row);
    }
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: ValueKey('personal-info-$id'),
        onTap: onTap,
        splashColor: _gold.withValues(alpha: .08),
        highlightColor: _gold.withValues(alpha: .05),
        child: row,
      ),
    );
  }

  Future<void> _editText({
    required String title,
    required String currentValue,
    required ValueChanged<String> onChanged,
    int maxLength = 16,
  }) async {
    var draft = currentValue;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: ValueKey('personal-info-dialog-$title'),
        backgroundColor: const Color(0xFF171411),
        title: Text('修改$title', style: const TextStyle(color: _gold)),
        content: TextFormField(
          key: ValueKey('personal-info-input-$title'),
          initialValue: currentValue,
          onChanged: (value) => draft = value,
          autofocus: true,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '请输入$title',
            hintStyle: const TextStyle(color: Color(0xFF77716A)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0x66756A5E)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _gold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            key: ValueKey('personal-info-confirm-$title'),
            onPressed: () => Navigator.pop(dialogContext, draft.trim()),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
    if (value != null && mounted) onChanged(value);
  }

  Future<void> _loadAvatar() async {
    try {
      final saved = await _avatarStore.load();
      if (saved != null && mounted) setState(() => _avatarPath = saved);
    } catch (_) {
      // The packaged legacy avatar remains the safe fallback.
    }
  }

  Future<void> _changeAvatar() async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);
    String? selected;
    try {
      selected = widget.pickAvatarImage != null
          ? await widget.pickAvatarImage!()
          : (await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 92,
              requestFullMetadata: false,
            ))?.path;
    } on PlatformException {
      _showAvatarMessage('无法读取相册图片，请检查相册权限后重试。');
    }
    if (selected == null || !mounted) {
      if (mounted) setState(() => _avatarBusy = false);
      return;
    }

    try {
      final adjusted = widget.adjustAvatarImage != null
          ? await widget.adjustAvatarImage!(selected)
          : await Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                builder: (_) => AvatarCropPage(imagePath: selected!),
              ),
            );
      if (adjusted == null || !mounted) {
        if (mounted) setState(() => _avatarBusy = false);
        return;
      }
      final saved = await _avatarStore.persist(adjusted);
      if (!mounted) return;
      setState(() {
        _avatarPath = saved;
        _avatarBusy = false;
      });
      _showAvatarMessage('头像已更新');
    } catch (_) {
      if (!mounted) return;
      setState(() => _avatarBusy = false);
      _showAvatarMessage('头像保存失败，请重新选择图片。');
    }
  }

  void _showAvatarMessage(String message) {
    if (!mounted) return;
    setState(() => _avatarBusy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openPaymentSecurity() {
    if (widget.onOpenPaymentSecurity != null) {
      widget.onOpenPaymentSecurity!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PaymentSecurityPage()),
    );
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _PersonalInfoHeader extends StatelessWidget {
  const _PersonalInfoHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: KingBackButton.leftOffset(context),
            top: KingBackButton.safeAreaOffset.dy,
            child: KingBackButton(
              key: const ValueKey('personal-info-back'),
              onPressed: onBack,
            ),
          ),
          const Text(
            '我的个人信息',
            style: TextStyle(
              color: Color(0xFFC9B69E),
              fontSize: 19,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
