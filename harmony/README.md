# HarmonyOS adapter sources

These files are used only by the isolated Harmony build. They are not dependencies
of the Android/iOS application. Current acceptance status is recorded in
`docs/features/foundation/harmony/README.md`.

## Secure storage

The local plugin implements the existing FlutterSecureStorage method channel.
`stage-harmony-secure-storage.ps1` copies the pinned 11.1.0 Dart package with its
license, adds the OHOS platform registration and selects the Harmony policy.
Application call sites and Android/iOS packages are unchanged.

- A random AES-256 root key is protected by Asset Store Kit: first unlock,
  no device sync, no retention on uninstall.
- Each preferences value is `v1:` plus base64 of nonce (12 bytes), GCM tag
  (16 bytes), and encrypted JSON string. AAD includes its storage key.
- The plaintext is returned only after GCM authentication succeeds. Empty,
  Unicode and session JSON values over 1024 bytes are supported by the format.
- The preferences file is private to this plugin; deleteAll clears only this file.
  The root key is retained until uninstall. A missing root with existing
  ciphertext fails rather than silently creating a replacement.
- Only Asset NOT_FOUND is treated as absence. Other errors return a sanitized
  PlatformException without recording values, key names or native error messages.
- Calls are serialized per engine. Cross-engine concurrent mutations are not
  validated; Harmony background message engines are not enabled in this build.
- This does not implement biometric prompts or migrate data from the rejected
  preferences-based RSA plugin, which was never installed for KINGCLUB.

## Device verification (not yet executed)

1. Copy `verification/storage_probe.dart.template` to the isolated application's
   `lib/harmony_storage_probe.dart`. Do not copy it into the primary app checkout.
2. With valid developer signing, build/run this target with the real API base
   and `--dart-define=HARMONY_STORAGE_PHASE=write`. Require
   `HARMONY_STORAGE_WRITE_PASS`. It checks empty strings, a large Unicode value,
   ordered writes, and persists a dedicated diagnostic marker. No credentials
   are printed or deleted.
3. Stop the app, rebuild the same bundle with phase `read` without clearing data,
   and launch it. Require `HARMONY_STORAGE_RESTART_PASS`. It checks persistence,
   idempotent deletion and absent-key results, then starts the real app.
4. On a dedicated test install, verify ciphertext tampering / key swapping fails,
   device reboot before and after first unlock, OS storage errors, and missing
   Asset key with ciphertext present. These cases remain unverified.
5. Verify real login, logout and relaunch. Validate the cover video and both music
   tracks, sound toggle, transition to phone login and foreground/background.

The probe has passed Dart analysis; the adapter has passed HAP compilation.
Neither result proves native cryptography, persistence or media playback on device.

## Build

Use the preparation scripts in order: prepare-harmony-probe,
stage-harmony-storage, stage-harmony-secure-storage, stage-harmony-video.
Then run `stage-harmony-image-picker.ps1` to retain image_picker 1.2.3 and add
the pinned OHOS platform adapter. Its reviewed patch is kept in
`patches/image-picker-ohos.patch`; staging refuses a dirty upstream source.
The patch handles empty selection, cancelled multi-selection, overlapping calls,
permission retry, multiple videos, async result failures and duplicate file close.
It is not a replacement for the separate scanner or image-cropping adapter.

Each staging script requires a fresh destination for its packages; it refuses to
overwrite an earlier experiment. Sources and commit pins are in the scripts.
`build-harmony-device.ps1` requires an explicit HTTPS API base, preventing the
default mock auth repository from being used unintentionally. `-Unsigned` makes
a compile-only package. Signing material stays outside the repository.

## Image picker device acceptance (pending)

Avatar crop staging: `scripts/stage-harmony-cropper.ps1` keeps image_cropper
12.2.1 and its original Dart interface. It adds only the pinned OHOS native
implementation and maps existing Android-style options inside that adapter.
The app's square crop, 1024 pixel bounds and JPEG quality 90 remain unchanged.
`verification/cropper_contract_test.dart.template` checks argument forwarding
and cancellation with a mocked channel, not actual image processing.
Device acceptance must check crop/rotate, confirm/cancel/back, black/gold UI,
source preservation on route failure, output dimensions, orientation, file size,
upload and repeated opening. Remote input and process-death recovery are not
accepted features of this integration.

Scanner staging: run `scripts/stage-harmony-scanner.ps1` after image picker.
It retains mobile_scanner 7.4.1 and copies the pinned OHOS native implementation,
applying separate Dart/native patches. The existing scanner page and navigation
remain unchanged. ScanKit currently exposes one rear camera in this adapter.
Copy `verification/scanner_contract_test.dart.template` into the isolated test
directory to check the mocked Harmony channel contract. Real camera orientation,
torch, gallery detection and stop/reopen still require a device.

- Pick and read one photo, several photos and a video through existing app flows.
- Cancel both single and multi-select, then immediately open the picker again.
- Deny camera permission and retry; grant it and capture with both cameras.
- Double tap while a picker is open: the second request fails without losing the first.
- Verify readable cache paths, image dimensions/orientation and existing upload
  compression, including large files and insufficient storage.
- Interrupt with background/foreground and process death; verify recovery separately.
- Verify crop and gallery QR recognition only after their own adapters are ready.

The upstream Dart tests mock native calls; passing them confirms wrapper compatibility,
not these native runtime cases.

### 前台定位（独立构建）

执行 `scripts/stage-harmony-geolocator.ps1 -ProbeRoot <外部 probe>`，然后使用既有 `build-harmony-device.ps1` 构建。源固定到 CPF-Flutter/fluttertpc_geolocator `br_v14.0.2_ohos` / `6fa6307b29fa6bc0e1983b146d2c33de48740862`，保留 hosted geolocator 14.0.3 / platform interface 4.3.0；不替换主仓库依赖或 SDK。

补丁修正前台授权误报 always、模糊权限被当作拒绝、精确权限硬编码、零值坐标污染、模拟定位标志丢失、枚举精度误作米数、流间隔单位和错误吞掉。停止流只取消本实例监听；异步授权返回后检查取消代次。单次定位使用系统超时，Dart 超时不会注销另一个持续定位流；底层单次请求可能持续到其系统超时。已移除该路径输出经纬度的调试日志。

主机只声明前台精确/模糊定位权限，拒绝不阻塞手动城市选择。坐标转城市的 geocoding 尚未适配；签名、原生权限弹窗（含永久拒绝）、系统设置跳转、真实定位精度/时间戳和快速进入退出需真机验收。接口 mock 测试模板为 `harmony/verification/geolocator_contract_test.dart.template`，其通过不代表原生定位验证通过。

### 系统地理编码（独立构建）

执行 `scripts/stage-harmony-geocoding.ps1 -ProbeRoot <外部 probe>`，再使用既有构建脚本。插件源码在 `harmony/plugins/kingclub_geocoding_ohos/`，依照本机 API 26 SDK `@ohos.geoLocationManager.d.ts` 的 `isGeocoderAvailable`、`getAddressesFromLocation` 与 `getAddressesFromLocationName` 实现；保留 geocoding 5.0.0 / platform interface 5.0.0，不使用旧版单例接口或降级主项目。

支持坐标转地址、地址转坐标、地址转 Placemark 和可用性查询。每次请求独立传递 locale；省、市、区县对应字段分别返回，不把无结果替换为固定城市。Dart 通道有 8 秒超时，底层系统查询不可取消，超时只结束调用方等待；不记录坐标/地址调试日志。该插件不额外申请定位权限，坐标仍经已有前台授权流程获取。

主 APP 的 `locateHomeCity` 无修改，仍按 locality / subAdministrativeArea / administrativeArea 的原优先级选名，再与原城市目录匹配。首页现有异常捕获保留手动选择，异步定位不会覆盖已手选城市。验证模板 `harmony/verification/geocoding_contract_test.dart.template` 使用 mock 通道验证真实 APP 调用函数，测试数据不写数据库，不替换产品页面。地理编码依赖手机系统服务及网络，实际城市名称、离线/服务不可用与地区支持仍须真机验收。

### 聊天语音播放（独立构建）

`stage-harmony-audio.ps1` 保留 audioplayers 6.8.1 / interface 7.2.0，只引入固定源 CPF-Flutter/flutter_audioplayers `br_v6.5.1_ohos` / `b853cdafdef1549be31b478a954f6d8b36d314e6` 的 OHOS 原生插件。许可证保留在源代码文件头；补丁见 `patches/audioplayers-ohos.patch`。

本次检查范围是 `NativeChatVoiceOutput` 所用的 DeviceFileSource / 默认 MediaPlayer / 播放、停止、完成、销毁。修复初始化通道不返回、缺省音频上下文缺字段导致错误、源设置与释放缺少 await、原生错误伪装 prepared、本地文件描述符不关闭；补充停止后延迟焦点不得恢复播放以及焦点失败通知。禁用该适配器的后台常驻任务，保持现有聊天页面的前台行为。不改聊天文件授权、下载缓存、账号隔离和删除处理，不上传聊天内容至厂商推送。

此节点不是录音适配，也未验收 SoundPool 低延迟模式、远程音频、所有音频格式、系统中断恢复与扬声器/蓝牙/耳机切换。真机须验证重复切换语音、损坏或丢失缓存、播完清除播放态、停止/退出/切换账号后无残留声音，及文件句柄不随次数增长。Dart mock 通道测试与现有 ChatVoicePlayback 回归不能证明实际听感或原生资源释放有效。

### 前台语音录制

执行 `scripts/stage-harmony-record.ps1 -ProbeRoot <隔离工程>`，使用干净的 CPF-Flutter/fluttertpc_record c719424e0cd869bf57198e71768d11f995cce849 源码（默认 C:/HuaweiTools/harmony-record）。保留 record 7.1.1/interface 2.1.0，仅覆盖鸿蒙默认插件；Dart OHOS 类等待 cancel 完成，不修改其他端接口包。添加前台麦克风使用说明，不增加后台任务权限。验证模板为 harmony/verification/record_contract_test.dart.template，复制到 probe/test 后配合原 voice_capture_test.dart 运行。

原生支持当前聊天 AAC-LC/M4A 文件录音。系统降噪/回声处理未保证，流式录音和其他编码不开放。18 项通道/状态机测试、未签名 HAP 构建通过；实际录音、来电中断、后台切换、短录音删除、重新录制、试听及真实发送须真机验证。该节点未改变安卓/苹果或 shared lib。

### 聊天单文件选择

`scripts/stage-harmony-file-picker.ps1` 在隔离工程保留 file_picker 12.3.0，并注册 `plugins/kingclub_file_picker_ohos`。插件依照本机 API 26 DocumentViewPicker/FileUri/fs 接口编写，只接现有聊天的单文件任意类型选择，不开放目录、另存、多选或媒体压缩。使用系统选择授予的 URI，只读打开原文件，以 64 KiB 分块复制至私有 cacheDir，校验 256 MiB 和拷贝大小；Dart 返回原名和可读取路径，沿用已有账号/会话草稿及发送页面。

取消返回 null；错误回传已有页面提示，重复选择被拒绝，Ability 分离后的结果不进入草稿。成功的中转文件属于系统可回收缓存，未增加永久文件存储或完整临时文件清理接口；原始文件不删除。取消、云端文档、低空间、断开页面、实际预览/发送和缓存回收需真机验收。验证模板 `verification/file_picker_contract_test.dart.template`。
