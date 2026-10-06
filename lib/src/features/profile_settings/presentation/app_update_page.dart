import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_update.dart';
import '../../../core/design_system/king_language.dart';

class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({super.key});
  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  final updates = AppUpdates.shared;
  CancelToken? _cancel;
  double? _progress;
  String? _path;
  AppRelease? _downloaded;
  bool _busy = false;
  String? _message;
  String t(List<String> values) =>
      values[kingLanguageIndex(Localizations.localeOf(context))];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) updates.check();
    });
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _act() async {
    final release = updates.release;
    if (_busy || release == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (Platform.isIOS) {
        if (await AppUpdates.native.invokeMethod<bool>('open', {
              'url': release.url,
            }) !=
            true) {
          throw StateError('open');
        }
      } else if (_path == null) {
        setState(() => _progress = 0);
        final token = _cancel = CancelToken();
        final path = await updates.download(release, token, (received, total) {
          if (mounted) {
            setState(() => _progress = (received / total).clamp(0, 1));
          }
        });
        if (mounted) {
          setState(() {
            _path = path;
            _downloaded = release;
          });
        }
      } else {
        final result = await AppUpdates.native.invokeMethod<String>('install', {
          'path': _path,
          'sha256': _downloaded!.sha256,
          'build': _downloaded!.build,
        });
        if (mounted && result == 'permission') {
          _message = t([
            '允许此来源安装后，返回点“安装更新”。',
            'Allow installation from this source, then return and tap Install update.',
            '允許此來源安裝後，返回點「安裝更新」。',
            'อนุญาตให้ติดตั้งจากแหล่งนี้ แล้วกลับมาแตะติดตั้งอัปเดต',
          ]);
        }
      }
    } on PlatformException catch (error) {
      if (mounted) {
        _message = error.code == 'VERIFY'
            ? t([
                '安装包校验未通过，请重新下载。',
                'Package verification failed. Please download again.',
                '安裝包校驗未通過，請重新下載。',
                'ตรวจสอบแพ็กเกจไม่ผ่าน โปรดดาวน์โหลดอีกครั้ง',
              ])
            : t([
                '无法打开更新，请稍后重试。',
                'Unable to open the update. Please try again.',
                '無法開啟更新，請稍後重試。',
                'ไม่สามารถเปิดอัปเดตได้ โปรดลองอีกครั้ง',
              ]);
        if (error.code == 'VERIFY') {
          _path = null;
          _downloaded = null;
        }
      }
    } catch (_) {
      if (mounted) {
        _message = t([
          '更新未完成，请检查网络后重试。',
          'Update incomplete. Check your connection and retry.',
          '更新未完成，請檢查網路後重試。',
          'อัปเดตไม่สำเร็จ โปรดตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง',
        ]);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101010),
    appBar: AppBar(
      title: Text(t(['检查更新', 'Check for updates', '檢查更新', 'ตรวจสอบการอัปเดต'])),
      centerTitle: true,
    ),
    body: AnimatedBuilder(
      animation: updates,
      builder: (context, _) {
        final available = updates.available && !updates.failed;
        final title = updates.checking
            ? t([
                '正在检查更新…',
                'Checking for updates…',
                '正在檢查更新…',
                'กำลังตรวจสอบการอัปเดต…',
              ])
            : updates.failed
            ? t([
                '暂时无法检查更新',
                'Unable to check for updates',
                '暫時無法檢查更新',
                'ไม่สามารถตรวจสอบการอัปเดตได้',
              ])
            : available
            ? t(['发现新版本', 'Update available', '發現新版本', 'มีเวอร์ชันใหม่'])
            : updates.release == null
            ? t([
                '暂无可用的远程更新',
                'No remote update available',
                '暫無可用的遠端更新',
                'ยังไม่มีอัปเดตที่พร้อมใช้งาน',
              ])
            : t([
                '已是最新版本',
                'You’re up to date',
                '已是最新版本',
                'เป็นเวอร์ชันล่าสุดแล้ว',
              ]);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 28),
              const Icon(
                Icons.system_update_outlined,
                size: 56,
                color: Color(0xFFC9B69E),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                updates.installedVersion,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              if (available) ...[
                const SizedBox(height: 32),
                Text(
                  '${updates.release!.version} (${updates.release!.build})',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  updates.release!.notes[kingLanguageIndex(
                    Localizations.localeOf(context),
                  )],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                if (Platform.isAndroid)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${(updates.release!.bytes / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
              ],
              const SizedBox(height: 32),
              if (_progress != null && _path == null) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Text(
                  '${(_progress! * 100).floor()}%',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy || updates.checking
                      ? null
                      : available
                      ? _act
                      : updates.check,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC9B69E),
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _busy
                        ? t(['请稍候…', 'Please wait…', '請稍候…', 'โปรดรอสักครู่…'])
                        : !available
                        ? t(['重新检查', 'Check again', '重新檢查', 'ตรวจสอบอีกครั้ง'])
                        : Platform.isIOS
                        ? t(['前往更新', 'Open update', '前往更新', 'เปิดหน้าอัปเดต'])
                        : _path != null
                        ? t(['安装更新', 'Install update', '安裝更新', 'ติดตั้งอัปเดต'])
                        : t([
                            '下载更新',
                            'Download update',
                            '下載更新',
                            'ดาวน์โหลดอัปเดต',
                          ]),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
