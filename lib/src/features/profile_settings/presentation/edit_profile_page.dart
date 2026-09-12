import 'package:image_cropper/image_cropper.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../data/profile_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'cover_adjust_page.dart';
import 'profile_image_ref.dart';

const kDefaultProfileCoverAsset =
    'assets/legacy/profile/my_profile_skyline_v1.png';

class ProfileCoverOption {
  const ProfileCoverOption({required this.label, required this.asset});

  final String label;
  final String asset;
}

const kProfileCoverOptions = <ProfileCoverOption>[
  ProfileCoverOption(label: '城市夜景', asset: kDefaultProfileCoverAsset),
  ProfileCoverOption(
    label: 'KingClub 招募',
    asset: 'assets/legacy/home/mock_hero_recruitment.png',
  ),
  ProfileCoverOption(
    label: '音乐现场',
    asset: 'assets/legacy/home/mock_poster_music.png',
  ),
];

class EditableProfileResult {
  const EditableProfileResult({
    required this.nickname,
    required this.signature,
    required this.coverAsset,
  });

  final String nickname;
  final String signature;
  final String coverAsset;
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
    this.coverAsset = kDefaultProfileCoverAsset,
    this.onBack,
    this.onSaved,
    this.onSessionResetRequested,
    this.realProfile,
    this.repository,
    this.pickCoverImage,
    this.adjustCoverImage,
    super.key,
  });

  final String nickname;
  final String signature;
  final String coverAsset;
  final Map<String, dynamic>? realProfile;
  final ProfileRepository? repository;
  final VoidCallback? onBack;
  final ValueChanged<EditableProfileResult>? onSaved;
  final VoidCallback? onSessionResetRequested;
  final Future<String?> Function()? pickCoverImage;
  final Future<String?> Function(String imagePath)? adjustCoverImage;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF8C8378);

  late String _nickname;
  late String _signature;
  late String _coverAsset;
  String _city = '河南省 · 安阳市';
  String _occupation = '自由职业';
  String _height = '168 cm';
  String _activeTime = '周末晚间';
  String _music = '流行 · R&B';
  String _drink = '微醺';
  String _party = '朋友组局';
  String? _avatarPath;
  String? _avatarUploadId;
  String? _coverUploadId;
  bool _avatarChanged = false;
  String? _relationship;
  String? _birthDate;
  String? _locatedCity;
  String? _requestId;
  bool _dirty = false;
  bool _saving = false;
  EditProfileMockSaveOutcome _saveOutcome = EditProfileMockSaveOutcome.success;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname;
    _signature = widget.signature;
    _coverAsset = widget.coverAsset;
    if (widget.repository != null) {
      widget.repository!
          .image(widget.realProfile?['avatar'] as Map?)
          .then((file) {
            if (mounted && !_avatarChanged) {
              setState(() => _avatarPath = file?.path);
            }
          })
          .catchError((_) {});
      final d = widget.realProfile?['details'] as Map? ?? {};
      final prefs = widget.realProfile?['preferences'] as Map? ?? {};
      _city = '${widget.realProfile?['locationCity'] ?? '点击授权定位'}';
      _relationship = d['relationship'] as String?;
      _occupation = '${d['occupation'] ?? ''}';
      _height = d['heightCm'] == null ? '' : '${d['heightCm']} cm';
      _activeTime = '${d['activeTime'] ?? ''}';
      _music = '${d['music'] ?? (prefs['music'] as List? ?? []).join(' · ')}';
      _drink = '${d['drink'] ?? (prefs['drinks'] as List? ?? []).join(' · ')}';
      _party = '${d['party'] ?? (prefs['events'] as List? ?? []).join(' · ')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final blackGoldTheme = baseTheme.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _gold,
        onPrimary: Color(0xFF20170F),
        secondary: _gold,
        onSecondary: Color(0xFF20170F),
        surface: Color(0xFF171411),
        onSurface: Color(0xFFF1EAE0),
        error: Color(0xFFD87369),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF171411),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _gold,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: Color(0xFFD9D0C5), height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E0C0A),
        counterStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x66756A5E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _gold, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF20170F),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _gold),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF171411),
        surfaceTintColor: Colors.transparent,
      ),
    );
    return Theme(
      data: blackGoldTheme,
      child: PopScope(
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
                  onTitleLongPress: widget.repository == null
                      ? _showMockScenarios
                      : () {},
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                    children: [
                      if (_statusMessage != null) ...[
                        _StatusBanner(
                          message: _statusMessage!,
                          onDismiss: () =>
                              setState(() => _statusMessage = null),
                        ),
                        const SizedBox(height: 22),
                      ],
                      _buildMediaHeader(),
                      const SizedBox(height: 22),
                      if (widget.realProfile != null) ...[
                        _row(
                          '会员号',
                          '${widget.realProfile!['memberId'] ?? ''}',
                          keyName: 'memberId',
                          readOnly: true,
                        ),
                        _row(
                          '性别',
                          widget.realProfile!['gender'] == 1
                              ? '男'
                              : widget.realProfile!['gender'] == 2
                              ? '女'
                              : '未填写',
                          keyName: 'gender',
                          readOnly: true,
                        ),
                        if (widget.realProfile!['birthSource'] ==
                            'verified_identity')
                          _row(
                            '生日',
                            '${widget.realProfile!['birthDate'] ?? ''}',
                            keyName: 'verifiedBirth',
                            readOnly: true,
                          ),
                      ],
                      _row('昵称', _nickname, keyName: 'nickname'),
                      _row(
                        '个性签名',
                        _signature.isEmpty ? '未填写' : _signature,
                        keyName: 'signature',
                        maxLength: 40,
                      ),
                      _row('所在城市', _city, keyName: 'city', maxLength: 30),
                      if (widget.repository != null &&
                          widget.realProfile?['birthSource'] !=
                              'verified_identity')
                        _row(
                          '生日',
                          _birthDate ??
                              '${widget.realProfile?['birthDate'] ?? '未填写'}',
                          keyName: 'birthDate',
                          maxLength: 10,
                        ),
                      _row(
                        '职业',
                        _occupation,
                        keyName: 'occupation',
                        maxLength: 40,
                      ),
                      if (widget.repository != null)
                        _row(
                          '婚姻状态',
                          _relationship ?? '未填写',
                          keyName: 'relationship',
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaHeader() {
    final scale = MediaQuery.sizeOf(context).width / 750;
    return Column(
      children: [
        SizedBox(height: 30 * scale),
        Semantics(
          label: '修改头像',
          image: true,
          button: true,
          child: GestureDetector(
            onTap: _saving ? null : _pickAvatar,
            child: Container(
              key: const ValueKey('edit-profile-empty-avatar'),
              width: 200 * scale,
              height: 200 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF29241D),
                image: _avatarPath == null
                    ? null
                    : DecorationImage(
                        image: profileImageProvider(_avatarPath!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: _avatarPath == null
                  ? const Icon(
                      Icons.add_a_photo_outlined,
                      color: _gold,
                      size: 30,
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(height: 40 * scale),
        TextButton(
          key: const ValueKey('edit-profile-cover'),
          onPressed: _saving ? null : _showCoverPicker,
          child: const Text(
            '更换主页封面',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    required String keyName,
    int maxLength = 16,
    bool readOnly = false,
  }) {
    return InkWell(
      key: ValueKey('edit-profile-$keyName'),
      onTap: readOnly || _saving
          ? null
          : () => _edit(label, value == '未填写' ? '' : value, keyName, maxLength),
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
                      if (!readOnly)
                        _EditRowArrow(keyName: keyName)
                      else
                        const SizedBox(width: 20),
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
                if (!readOnly)
                  _EditRowArrow(keyName: keyName)
                else
                  const SizedBox(width: 20),
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
    if (widget.repository != null && keyName == 'relationship') {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('婚姻状态'),
          children: ['不显示', '单身', '未婚', '已婚', '离异', '丧偶']
              .map(
                (v) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, v),
                  child: Text(v),
                ),
              )
              .toList(),
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          _relationship = selected == '不显示' ? null : selected;
          _dirty = true;
          _requestId = null;
        });
      }
      return;
    }
    if (widget.repository != null && keyName == 'city') {
      await _locate();
      return;
    }
    if (widget.repository != null && keyName == 'birthDate') {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(now.year - 18, now.month, now.day),
        firstDate: DateTime(now.year - 120),
        lastDate: DateTime(now.year - 18, now.month, now.day),
      );
      if (picked != null && mounted) {
        setState(() {
          _birthDate =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          _dirty = true;
          _requestId = null;
        });
      }
      return;
    }
    final controller = TextEditingController(text: value);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: ValueKey('edit-profile-dialog-$keyName'),
          title: Text('修改$label'),
          content: TextField(
            key: ValueKey('edit-profile-input-$keyName'),
            controller: controller,
            autofocus: true,
            maxLength: maxLength,
            style: const TextStyle(color: Color(0xFFF1EAE0)),
            decoration: InputDecoration(errorText: error),
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
      _requestId = null;
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

  bool _pickingAvatar = false;
  Future<void> _pickAvatar() async {
    if (_pickingAvatar || _saving) return;
    _pickingAvatar = true;
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                title: const Center(child: Text('取消')),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 1024,
        maxHeight: 1024,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '调整头像',
            toolbarColor: Colors.black,
            toolbarWidgetColor: _gold,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: _gold,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: '调整头像',
            doneButtonTitle: '完成',
            cancelButtonTitle: '取消',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null || !mounted) return;
      setState(() {
        _avatarPath = cropped.path;
        _avatarChanged = true;
        _avatarUploadId = null;
        _requestId = null;
        _dirty = true;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _statusMessage =
              error.code.toLowerCase().contains('access') ||
                  error.code.toLowerCase().contains('permission')
              ? '请在手机设置中允许相机或照片访问后重试'
              : '图片无法打开，请重新选择',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _statusMessage = '头像处理失败，请重新选择');
    } finally {
      _pickingAvatar = false;
    }
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('请先打开手机定位服务');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('未获得定位权限');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final geocoding = Geocoding();
      final places = await geocoding.placemarkFromCoordinates(
        p.latitude,
        p.longitude,
        locale: const Locale('zh', 'CN'),
      );
      if (places.isEmpty) throw StateError('暂时无法识别所在城市');
      final place = places.first;
      final city = [
        place.administrativeArea,
        place.locality,
      ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(' · ');
      if (city.isEmpty) throw StateError('暂时无法识别所在城市');
      if (mounted) {
        setState(() {
          _city = city;
          _locatedCity = city;
          _dirty = true;
          _requestId = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statusMessage = '定位未完成，请检查定位权限和网络后重试');
    }
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
    if (widget.repository != null) {
      try {
        if (_coverAsset != widget.coverAsset) {
          _coverUploadId ??= await widget.repository!.upload(
            'cover',
            _coverAsset,
          );
        }
        if (_avatarChanged && _avatarPath != null) {
          _avatarUploadId ??= await widget.repository!.upload(
            'avatar',
            _avatarPath!,
          );
        }
        await widget.repository!.save(
          widget.realProfile!['version'] as int,
          _requestId ??= const Uuid().v4(),
          {
            if (_coverUploadId != null) 'coverFileId': _coverUploadId,
            if (_avatarUploadId != null) 'avatarFileId': _avatarUploadId,
            'nickname': _nickname.trim(),
            'bio': _signature.trim(),
            if (_birthDate != null) 'birthDate': _birthDate,
            if (_locatedCity != null) 'locationCity': _locatedCity,
            'details': {
              'relationship': _relationship,
              'occupation': _occupation,
              'heightCm': int.tryParse(
                _height.replaceAll(RegExp(r'[^0-9]'), ''),
              ),
              'activeTime': _activeTime,
              'music': _music,
              'drink': _drink,
              'party': _party,
            },
          },
        );
        if (mounted) _finishSaved();
      } catch (_) {
        if (mounted) {
          setState(() {
            _saving = false;
            _statusMessage = '保存失败或资料版本已变化，草稿已保留，请重试或重新打开';
          });
        }
      }
      return;
    }
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
      coverAsset: _coverAsset,
    );
    if (widget.onSaved != null) {
      widget.onSaved!(result);
    } else {
      Navigator.pop(context, result);
    }
  }

  Future<void> _showCoverPicker() async {
    String? selected;
    try {
      selected = widget.pickCoverImage != null
          ? await widget.pickCoverImage!()
          : (await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 92,
              requestFullMetadata: false,
            ))?.path;
    } on PlatformException {
      if (!mounted) return;
      setState(() => _statusMessage = '无法读取相册图片，请检查相册权限后重试。');
      return;
    }
    final selectedReference = selected;
    if (selectedReference == null || !mounted) {
      return;
    }
    String? adjustedReference;
    try {
      adjustedReference = widget.adjustCoverImage != null
          ? await widget.adjustCoverImage!(selectedReference)
          : await Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                allowSnapshotting: false,
                builder: (_) => CoverAdjustPage(imagePath: selectedReference),
              ),
            );
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = '封面调整失败，请重新选择图片。');
      return;
    }
    if (adjustedReference == null ||
        adjustedReference == _coverAsset ||
        !mounted) {
      return;
    }
    setState(() {
      _coverAsset = adjustedReference!;
      _dirty = true;
      _statusMessage = '新封面已预览，保存后将显示在我的主页。';
    });
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
        content: const Text('尚未保存的资料将丢失。'),
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
        content: const Text('资料已在其他位置更新，为避免覆盖，请选择如何处理。'),
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
        _statusMessage = '已重新加载最新资料。';
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
        content: const Text('请勿重复提交，可先查询最新资料确认保存结果。'),
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
              size: 22,
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
