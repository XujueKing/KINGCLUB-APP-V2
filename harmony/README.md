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

### 视频缩略图、安装版本与返回手势

按顺序执行 `scripts/stage-harmony-video-thumbnail.ps1 -ProbeRoot <隔离工程>` 和 `scripts/stage-harmony-platform.ps1 -ProbeRoot <隔离工程>`，再在鸿蒙环境 pub get。前者保留 get_thumbnail_video 0.7.3，仅接现有 thumbnailData 本地视频调用，不支持网络源或 file API；后者增加安装 BundleInfo 通道，并仅在 probe 的主题平台表加入 OHOS，复用已有 KingSlidePageTransitionsBuilder。

验证模板：thumbnail_contract_test.dart.template、platform_gesture_test.dart.template。另复制原 installed_app_version_test.dart；复制原 native_page_transition_test.dart 时仅将 TargetPlatform.android 替换为 TargetPlatform.ohos。共 7 项通过，覆盖缩略图参数与错误、实际安装信息读取契约、缺失信息不伪造、设置/会员码页动画与左边缘右滑返回。未签名 HAP 编译通过（assembleHap 99.2 秒）。当前宿主版本仍取 BundleInfo，不代表安卓/iOS发布版号。尚待真机验收真实解码、损坏视频、高分辨率内存、系统边缘手势；当前先解码原尺寸再按比例缩小，不能宣称低内存转码。

### 聊天文件保存与打开

`scripts/stage-harmony-file-export.ps1 -ProbeRoot <隔离工程>` 注册独立 native 插件，并仅在 probe 的原聊天文件详情页放开 OHOS 保存/打开按钮。保留 ChatFileExporter 的二次鉴权、会话变更和删除取消；复制原 test/chat_file_exporter_test.dart 到 probe/test 后运行回归。系统 DocumentViewPicker.save 返回目标，只处理本操作 URI；非空目标拒绝覆盖，256 MiB、私有下载目录和 SHA-256 校验，64 KiB 分块读取，先核验源再写并再次核验。cancel 使在途操作失效，已成功保存的文档不会因退出页面删除。文件后缀通过系统 UTD 转为 MIME，只读调用系统查看器。没有查看器会报告失败，不伪造打开成功。

真机必须覆盖：中文文件名、空文件、大于一块的文件、云文档、取消选择/复制中取消、删除消息、账号切换、源损坏、目标变更、空间不足、系统查看器不可用。清理目标失败可能留下空或未完成文件；不保证云提供方清理必然成功。未签名包与 mock 测试不是系统导出验收。

### 系统地图查看与路线（地图第一节点）

执行 `scripts/stage-harmony-map.ps1 -ProbeRoot <隔离工程>`，pub get 后注册 kingclub/chat-map。原位置选择页的 mode=view 打开华为地图地点详情，原“导航”入口打开驾车路线，walking打开步行路线。无需修改原业务页面。仅显式点击后传目的坐标与地点名，不传地址、账号或聊天内容。使用本机SDK petalMaps API，坐标类型自API21起可显式指定；API18–20仅接GCJ02，其它明确失败，不能猜测坐标或错误偏移。无地图应用/能力不支持时回传错误，沿用“无法打开地图，可以复制地点信息”。不增加后台定位权限。

验证：复制 map_launch_test.dart.template 到probe/test，配合原chat_location_message_test.dart验证。模板在OHOS平台检查WGS84/GCJ02不被转换、地址不交给地图、重复点击仅一次、原生失败有提示。原生启动、实际落点、路线模式、App返回与系统切换须真机验证。此节点不是内嵌地图：当前仍缺拖拽选点/地图快照适配及在线地图服务认证配置，不能称整个地图已完成。

### 内嵌地图与预览接入

在已完成 `stage-harmony-map.ps1` 的干净 probe 上运行 `python scripts/stage-harmony-embedded-map.py <ProbeRoot>`。脚本检查原页面片段后，只修改隔离probe的3个Dart文件、添加独立Huawei同意说明，并同步本仓库Map插件原生源。不要对已经staged的页面重复执行；代码片段变化须先审阅。主lib/android/ios不修改。

原位置选择页使用OhosView承载MapComponent，复用页面顶部/候选区/确认按钮、拖拽结束350ms去抖。center通过rectifyCoordinate按地图数据修正；搜索走原系统地理编码，当前未接Huawei附近POI接口，候选显示真实中心。程序移动不当成用户选点，账号切换cancel/视图dispose取消迟到结果；地图初始化8秒超时。MapLoad与定位均成功后才显示ready。

快照使用staticMap、640×320、JPEG质量80，保留地图logo，不传名称/地址/会员令牌；PixelMap和打包器释放。Huawei地图同意与Tencent独立，未同意不请求快照；已授权的会话缓存沿用现有24项上限及账号变化清理。服务认证错误返回失败，不伪造地图。

验证：19项位置/系统地图回归、3项快照授权/隐私/缓存/错误测试通过；未签名HAP最终assembleHap49.9秒通过。首次编译的ArkUI属性未初始化已修复。模板为map_preview_test.dart.template，harmony_map_consent.dart.template是隔离业务适配模板。本机未完成在线MapKit应用认证核验，HAP仍未签名，真实地图加载、拖拽、跨坐标区域、地图logo可见性、SDK生命周期和网络重试仍待真机验收。不能把mock与编译当成地图服务已开通。

通知权限：新增 kingclub_notification_ohos 原生桥及 scripts/stage-harmony-notifications.py，只写隔离构建目录。读取真实系统授权状态、用户主动授权和打开系统设置；不启用厂商token注册。鸿蒙设置页不再显示未实现的Android常驻接收开关。8项测试通过（2项鸿蒙设置交互、6项原通道测试），包括拒绝不得显示允许。无鸿蒙真机，系统弹窗和设置跳转尚未实机验收。本地通知发布/点击冷启动恢复、离线推送仍待补齐。

本地消息通知已实现应用级授权/消息槽位检查、会话绑定、前后台竞争校验、发布失败传播、通用文案、到期自动删除和点击进入原鉴权流程。桌面角标接已有总未读数通道，不随每次通知重复累加；初次绑定不抹掉已有角标，退出/切账号清零。通话提醒返回false，未启用华为离线push。冷暖启动通过EntryAbility钩子收集Want，私有Preferences仅存有限路由元数据，无正文/凭证，Dart二次核验账号。应用内横幅与tabbar红点仍沿用既有业务。24项原通知/打开恢复测试通过，另3组直接执行原生源码的逻辑测试通过（信封白名单、持久队列与确认、授权/前后台/会话竞争/角标），这些测试不能证明系统实际展示。
