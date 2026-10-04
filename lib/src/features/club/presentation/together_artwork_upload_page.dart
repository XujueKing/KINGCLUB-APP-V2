import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../auth/domain/auth_repository.dart';
import '../data/secure_together_publication.dart';
import 'legacy_club_components.dart';

class TogetherArtworkUploadPage extends StatefulWidget {
  const TogetherArtworkUploadPage({super.key, required this.repository});
  final SecureTogetherPublication repository;
  @override
  State<TogetherArtworkUploadPage> createState() =>
      _TogetherArtworkUploadPageState();
}

class _TogetherArtworkUploadPageState extends State<TogetherArtworkUploadPage> {
  final _name = TextEditingController(text: '我的组局海报');
  Uint8List? _bytes;
  String? _request, _submittedName, _error;
  bool _busy = false;
  List<Map<String, String>> _items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.myArtwork();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is AuthFailure ? e.message : '暂时无法读取审核记录');
      }
    }
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      Uint8List? bytes;
      for (final edge in [1600, 1200, 960, 720]) {
        bytes = await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: edge,
          minHeight: edge,
          quality: 85,
          keepExif: false,
        );
        if (bytes != null && bytes.length <= 800000) break;
      }
      if (bytes == null || bytes.isEmpty || bytes.length > 800000) {
        throw const AuthFailure('IMAGE_SIZE', '图片无法压缩，请选择其他图片');
      }
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is AuthFailure ? e.message : '无法读取图片，请重试');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_bytes == null || _busy) return;
    if (_name.text.trim().isEmpty || _name.text.trim().length > 128) {
      setState(() => _error = '请填写128字以内的素材名称');
      return;
    }
    _request ??= const Uuid().v4();
    _submittedName ??= _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await widget.repository.submitArtwork(
        requestRef: _request!,
        name: _submittedName!,
        bytes: _bytes!,
      );
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _request = null;
        _submittedName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? '素材已通过审核，可返回素材库选择' : '图片已提交，可在下方查看审核状态',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is AuthFailure ? e.message : '结果尚未确认，请重试原上传');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: '上传组局素材',
    onBack: () => Navigator.pop(context),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          enabled: !_busy && _request == null,
          style: const TextStyle(color: legacyGold),
          decoration: const InputDecoration(labelText: '素材名称'),
        ),
        const SizedBox(height: 16),
        if (_bytes != null)
          Image.memory(_bytes!, height: 220, fit: BoxFit.contain),
        TextButton(
          onPressed: _busy || _request != null ? null : _pick,
          child: const Text('从相册选择图片'),
        ),
        const Text(
          '上传后由平台审核，通过后可在背景和海报素材库选择。',
          style: TextStyle(color: legacyGold),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: legacyPink)),
        FilledButton(
          onPressed: _busy || _bytes == null ? null : _upload,
          child: Text(
            _busy
                ? '请稍候'
                : _request != null
                ? '重试原上传'
                : '提交审核',
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('我的素材', style: TextStyle(color: legacyGold)),
            ),
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('刷新'),
            ),
          ],
        ),
        for (final item in _items)
          ListTile(
            title: Text(
              item['name']!,
              style: const TextStyle(color: legacyGold),
            ),
            subtitle: Text(switch (item['status']) {
              'approved' => '已通过，可在素材库选择',
              'rejected' => '未通过：${item['reason']}',
              'revoked' => '已撤回',
              _ => '审核中',
            }, style: const TextStyle(color: Colors.white70)),
          ),
      ],
    ),
  );
}
