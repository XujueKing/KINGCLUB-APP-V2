# HarmonyOS 原生适配

日期：2026-10-09。用户已批准开始适配；当前已产出真实应用的未签名调试 HAP，尚未签名安装或通过真机功能验收。

## 范围

沿用当前 Flutter 页面、交互、真实接口和账户，不另外开发展示壳。Android/iOS 使用现有 SDK、依赖锁和签名；鸿蒙工具链独立放置，未经验证不覆盖原工程。目标设备为用户连接的 nova 14 Pro，用户报告 HarmonyOS 6.1.0.135；Windows 已识别 HDC Interface，ADB 不识别该手机。

## 已核实的问题

- 当前主工程 Flutter 3.47.1 / Dart 3.13.1，pubspec 约束 `^3.13.1`，没有 ohos 工程。
- 本机已解压出 DevEco 随附 SDK API 26；HDC 3.2.0f、ohpm 26.0.0.630、Hvigor 6.26.8 已运行验证。尚无已配置的鸿蒙签名。
- CPF-Flutter `oh-3.47.0-dev_bak` 提交 `1f36fc0ae74955c780646ac3c0916a2f0e4676a6` 引用的 Windows Dart SDK 返回 `NoSuchKey`，不能作为可用构建基线。
- `oh-3.44.9-dev` 提交 `589ff5319af950a72c45dcf07880fbbf3b5a5aaf` 已下载并成功运行 Flutter 工具，实际 Dart 为 3.12.2，不满足当前 APP 的 3.13.1 下限。它是开发分支，不能称为稳定生产工具链；仍须检查 Dart 约束、Flutter API 和插件兼容性。
- 当前解析依赖中，fluwx、tobias、flutter_image_compress_ohos 已带 ohos 源码，尚未进行鸿蒙编译或支付验证。其余插件不能因为存在 Android/iOS 实现就视为支持鸿蒙。
- 用户确认已有实名认证华为开发者账号，下载中心页面亦显示已认证。用户已下载 DevEco Studio 26.0.0.851，ZIP 3,295,837,057 字节；解压后 EXE 3,295,943,544 字节，Windows Authenticode 校验 Valid，签发主体 Huawei Technologies Co., Ltd.。
- D 盘空间不足，安装器移至 `C:/HuaweiTools/deveco-studio-26.0.0.851.exe`，安装到 `C:/HuaweiTools/DevEcoStudio`。安装进程已退出，ExitCode=0，IDE 主程序存在；独立环境下 Flutter doctor 的 HarmonyOS toolchain 检查通过。
- 重连手机后 HDC 和 Flutter doctor 均识别 nova 14 Pro，设备报告 OpenHarmony-6.1.1.120 / API 24（底层标识，不替代用户设置页的 HarmonyOS 版本号）。SDK target 与最低兼容 API 必须分别配置，不能要求手机达到 API 26。
- 在 `C:/HuaweiTools/kingclub-dependency-probe` 复制 manifest/lock 做隔离解析：原约束明确被 Dart 3.12.2 拒绝；仅在此临时副本降低约束后，又因工具链报告 Flutter `0.0.0-unknown` 被 go_router_builder 拒绝。主工程 manifest/lock 未修改；临时实验不表示依赖已经兼容。

## 实施顺序

### 2026-10-09 第二阶段验证结果

- 独立 SDK 已切到上游发布标签 `3.44.9+ohos-0.0.1-canary1`，提交 `39285df71a97ffe0c23241dcc459d997a9d8b7c6`。版本识别正常，不再是 `0.0.0-unknown`；仍为预览工具链。
- 实验副本将 Dart 下限改为 3.12.2，并去掉仅用于生成和桌面测试的 build_runner、riverpod_generator、go_router_builder、sqflite_common_ffi。主工程不变；业务数据库 sqflite 仍保留。
- 实验副本依赖解析通过。426 个应用 Dart 文件 `dart analyze lib --format machine` 返回 0 个 ERROR；这不覆盖所有第三方包的实际目标平台编译。
- 生成真实 Flutter ohos 宿主、复制原应用 lib/assets，执行 `flutter build hap --debug --no-pub --no-codesign`。当前尚未生成 HAP。
- Hvigor 拒绝 C 盘工程引用 D 盘插件的绝对模块路径。C 盘 junction 缓存也未被接受。将三个 ohos 插件源码保留许可证复制到实验工程、使用本地 path override 后已跨过该错误，ohpm 已拉取微信/支付宝 SDK。
- 当前明确编译阻塞：第三方 `material_ui`、`cupertino_ui` 等库对 TargetPlatform 的穷尽 switch 未包含 `TargetPlatform.ohos`。须使用兼容版本或独立适配副本，不能直接修改共享 pub 缓存，不能把静态分析无错当作 HAP 构建成功。
- 复现入口：在专用终端加载 `scripts/enter-harmony.ps1`，再运行 `scripts/prepare-harmony-probe.ps1 -Destination <全新外部目录>`。它保留源工程，生成宿主、解析依赖并将原生插件放到实验目录；尚不是发布构建脚本。
- 本机 `C:/HuaweiTools/pub-cache` 是指向 `D:/SDK/pub-cache` 的目录映射，供依赖解析复用；原生模块必须使用实验工程内的实体副本。

1. 安装并验证独立工具链、HDC 真机识别与开发者签名。先验证依赖解析，不盲目降低主工程 Dart 约束。
2. 在隔离构建目录验证同一份应用代码及鸿蒙插件版本，固定所有来源和提交。确认后添加 ohos 宿主和可重复构建脚本。
3. 先接通启动、资源、网络、数据库、安全存储和登录；继续扫码、定位、图片、音视频、通知与支付。
4. 真机检验现有页面、相机返回规则、键盘、前后台、权限拒绝和真实服务连接；通过后签名安装。

## 原生适配清单

运行 `pwsh -File scripts/audit-harmony.ps1` 查看本机实际解析依赖和原生通道。该脚本只读，不改 pubspec/lock，也不运行依赖更新。

在专用 PowerShell 中执行 `. ./scripts/enter-harmony.ps1`，再运行 `flutter doctor -v` 或 `hdc list targets`。环境仅在该进程生效，不修改系统 PATH。该脚本不表示 APP 已经支持鸿蒙构建。

| 能力 | 现有实现 | 鸿蒙验收要求 |
|---|---|---|
| 文件、数据库、登录密钥 | path_provider、sqflite、flutter_secure_storage | 持久化、迁移、退出清除、系统安全存储；不使用明文降级 |
| 扫码与媒体 | mobile_scanner、image_picker、image_cropper、压缩与缩略图插件 | 相机授权、真实扫码、原返回路径、资源压缩 |
| 音视频 | video_player、audioplayers、record、flutter_webrtc | 封面连续播放、语音录制、通话及前后台恢复 |
| 定位地图 | geolocator、geocoding、chat-map 通道 | 城市选择、授权拒绝、真实地图 |
| 支付 | fluwx、tobias、wechat-payment 通道 | 官方鸿蒙 SDK 与回调、签名/应用登记；不可假报支付成功 |
| 消息通知 | local-notifications、push-registration、后台连接通道 | 红点、横幅、打开正确页面；遵守聊天内容不交给厂商推送的要求 |
| 通话/局域网/传输 | system-calls、nearby-lan、libkingclub_novorudp.so | 系统接口和原生库按鸿蒙 ABI 编译验证；不能复制 Android .so 当作已适配 |
| 版本更新 | app-version、app-update 通道 | 鸿蒙自己的包和安装流程，不调用 Android APK 安装器 |

## 发布门槛与未完成项

当前仅通过隔离编译，不能对用户承诺可用安装版本。待解决：鸿蒙依赖及关键原生通道、华为开发者签名、真实构建配置及真机功能验证。用户已完成开发者实名认证。证书、私钥、账号密码不提交仓库。

参考：<https://gitcode.com/CPF-Flutter/flutter_flutter>；<https://developer.huawei.com/consumer/cn/download/>。工具链状态以实际下载和构建结果为准。

### 2026-10-09 首次 HAP 编译通过

- 修复第三方 TargetPlatform.ohos 编译分支：在实验工程内复制 cupertino_ui 1.0.1、material_ui 1.1.0，保留许可证，仅补 switch 分支，分别修改 11、37 个文件。沿用 Android 的触摸/Material 分支，不重做页面。脚本为 `scripts/patch-harmony-ui.ps1`，不修改共享 pub 缓存。
- 支付宝的 bytecode HAR 要求 `app.products[].buildOption.strictMode.useNormalizedOHMUrl=true`，已加入宿主生成脚本。官方依据：https://developer.huawei.com/consumer/cn/doc/doccenter-deveco-studio/ide-hmos-hvigor-errorcode-00306 。
- `flutter build hap --debug --no-pub --no-codesign` 成功，产物 `C:/HuaweiTools/kingclub-dependency-probe/build/ohos/hap/entry-default-unsigned.hap`，266,954,700 字节，2026-10-09 18:23。包含真实应用代码和资源，不是展示壳。调试包大小不代表最终发布包大小。
- HDC 再次识别 nova 14 Pro。当前未配置签名，也未安装此次 HAP。仅三个已注册插件通过此次原生编译，不能据此宣布登录、扫码、音视频或支付可用。
- 准备脚本各步骤已在既有实验副本验证；尚未从全新目录完整重跑准备脚本。

### 启动持久化适配审计（进行中）

- 文件目录候选：OpenHarmony-TPC/flutter_packages，br_path_provider-v2.1.5_ohos，远端提交 `8fbc349ae219dbf429d2c6cb1d62628649dc0d72`。
- SQLite 候选：CPF-Flutter/flutter_sqflite，br_v2.4.1_ohos，提交 `38d829a84202bf73f9475352bb01fcbfa00e431b`。sqflite 与 sqflite_ohos 复制到实验工程 native_plugins，正在验证解析和构建；主工程依赖不变。
- 安全存储候选：CPF-Flutter/fluttertpc_flutter_secure_storage，br_v9.2.4_ohos，提交 `67c7b82e85b08a649dfd4f2bb0c455011a9384fa`。源码 `RSACipher18Implementation.ets` 将 RSA 私钥编码存入 preferences，并未用 HUKS/Asset 托管；不用于本项目真实登录密钥，需另接系统安全存储。尚未添加到应用依赖。
- SQLite 接入后第二次未签名 HAP 编译成功（87.3 秒）；生成注册器包含 SqflitePlugin。未在真机读写数据库，事务、迁移与异常行为尚待验证。
- 文件目录最终取自 GitCode 的同名分支，实际提交 `d4e49daa0acbd0bc419d58b1da27d64d44fab54b`（GitHub 镜像提交不同，未采用）。本地只稀疏检出 packages/path_provider；path_provider 2.1.5、path_provider_ohos 2.2.17 以实体本地覆盖接入，解析通过。
- `scripts/stage-harmony-storage.ps1` 固定上述两个仓库的实际提交，复制四个包及许可证至全新实验工程的 native_plugins。当前实验工程的等价逐步操作已执行，脚本已通过语法检查，尚未全新重跑。
- 此轮 HAP 为编译探针，未传 KINGCLUB_API_BASE_URL，现有应用会默认选择 MockAuthRepository。它不是可交给用户登录的真实联网版本，不能将“同一份业务源码编译通过”描述成“真实接口已接通”。后续真机包必须显式传入现有环境的配置并核验实际接口请求。
- 文件目录与 SQLite 同时接入后第三次未签名 HAP 编译成功（114.4 秒），注册器已包含 PathProviderPlugin、SqflitePlugin 和原三个插件。仍未完成真机持久化验证。

### 安全存储实现方案（2026-10-09）

继续沿用 FlutterSecureStorage 11.1.0 接口，独立鸿蒙插件使用 Asset Store Kit 保管随机 AES-256 密钥（首次解锁后可读、禁止同步、卸载不保留）；大于 1 KB 的登录会话使用系统 AES-GCM 加密后保存到独立 preferences 文件。每次写入生成 12 字节随机 nonce，16 字节认证标签，并将业务 key 绑定到 AAD，拒绝篡改和跨 key 替换。不保存明文密钥或登录数据，不因读取失败重新生成密钥、清空数据或返回伪成功。串行处理同引擎读写，未找到与系统故障区分返回。

依据：已安装 API 26 的 Asset/CryptoArchitectureKit 类型定义；https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V14/asset-scenario1-V14 （Asset 短数据小于 1024 字节，因此不直接存整份 session）。实现放在 harmony/plugins，临时构建复制并注册；Android/iOS 不引入此依赖。编译和真机验收分别记录。

### 安全存储与封面播放器构建结果

- 自有 `kingclub_secure_storage_ohos` 使用系统 Asset/AES-GCM，修正 ArkTS 对 throw 类型的要求后，与原真实应用代码一起编译成功（104.1 秒）。未将先前审计不合格的 RSA preferences 插件接入。
- 播放器沿用应用当前 video_player 2.14.0，仅补 OHOS 默认插件；平台实现来自 CPF-Flutter/flutter_packages 的 br_video_player-v2.11.1_ohos，固定提交 `fadef928861f00e88e5f6b802a2b0145eb54349e`。复制许可证及生成的 Dart/ArkTS 通道，删除副本中仅用于生成的 Pigeon 本地路径依赖。封面视频、随机两首音乐、跨登录页面连续播放的应用逻辑没有重写。
- 原生注册器现在包含 7 个插件，含新增安全存储、文件目录、SQLite、视频播放。实际登录、GCM认证、落盘恢复、播放、扫码及支付仍须分别真机验收。
- 验证模板 `harmony/verification/storage_probe.dart.template` 在实验工程单独 Dart 分析通过，尚未在手机执行。不把静态分析当作持久化测试成功。
- 新增 `scripts/build-harmony-device.ps1`，必须显式指定 HTTPS API，防止默认走 MockAuthRepository；当前依据已有正式包联调记录使用 https://test.wuyexin.cn/kingclub-v2 构建未签名联网实验包，不修改线上服务。宿主图标和名称复用已有 Android KINGCLUB 资源。
- Windows UI 工具启动了 DevEco，但输入连续返回 active request/unknown screenshotId，重置恢复后仍无法可靠操作。当前停在首次语言选择页，已请求用户完成首次启动设置；浏览器开发者登录不等于 IDE 自动签名已完成。

- 显式 API 配置的联网实验 HAP 构建成功（114.8 秒），产物 263,971,618 字节，2026-10-09 18:55。尚未签名/安装，不能据此认为已请求过真实服务器或通过任何手机验收。

### 2026-10-10 相册适配计划与源码审计

沿用当前 image_picker 1.2.3 的 Dart API，仅在隔离工程注册 OHOS 实现。候选源为 OpenHarmony-TPC/flutter_packages 的 br_image_picker-v1.2.1_ohos，固定提交 1af98579e1a95d4fca19e422d26f5b6856ac38ba，平台插件 0.8.13+7。系统 PhotoViewPicker 返回的 URI 复制到应用缓存后交给现有上传流程；相机使用系统 CameraPicker。

审计发现取消多选未完成 Future、重复调用仍返回 true、权限拒绝残留 pending 状态、空结果直接访问 uris[0]、多视频仅返回第一项、复制失败重复关闭文件等问题。接入前修复这些边界；补丁固定到版本并随 staging 脚本应用。设备验收需覆盖选择、取消、再次打开、拒绝权限、文件读取及现有压缩上传。头像裁剪和扫码识别是独立插件，不能因相册编译通过而记为完成。

### DevEco 启动与签名状态更新

IDE 已恢复启动，用户已在 IDE 登录，自动签名识别湖南领美网络科技有限公司。旧缓存 .port 为不可访问的 reparse point，同时 JBR 25 默认临时目录无法建立 Unix domain socket。保留旧缓存和设置，通过用户 VM options 将 idea.system.path 指向 C:/HuaweiTools/ide-system，jdk.net.unixdomain.tmpdir 指向 C:/HuaweiTools/socket-temp；Selector 探针通过，真实项目可正常打开。没有重置用户设置。

当前没有鸿蒙真机，自动签名提示缺少设备无法生成 profile，尚未生成已签名包或安装。用户已确认先推进适配，不等待手机。

### 相册适配构建结果（2026-10-10）

- 新增 scripts/stage-harmony-image-picker.ps1，固定上游提交，保留 image_picker 1.2.3，实体复制 OHOS 平台包及许可证后应用 harmony/patches/image-picker-ohos.patch。已在现有隔离工程实际执行并解析成功，未改主工程 pubspec/lock。
- 修改的原生边界包括空结果、取消多选完成回调、重复调用拒绝、相机权限失败后清理状态、多视频返回全部文件、异步处理失败回调及复制失败重复 close。
- 上游 Dart wrapper 的 105 项测试通过；Dart analyze 无错误/警告，4 项提示均为生成 Pigeon 通道常量命名。PowerShell 脚本语法检查通过。
- 显式现有 API 配置的未签名 debug HAP 编译通过（212.8 秒），注册器包含 ImagePickerPlugin，共 8 个原生插件。Dart 单测使用 fake native API，不能证明原生补丁运行正确；原生取消、权限、文件访问、压缩上传及进程恢复仍待设备验收。
- 当前插件的 requestFullMetadata 语义、异常细分和进程被回收后的恢复仍须进一步审查；头像裁剪、扫码、定位、录音等尚未完成。没有手机安装或业务上线动作。

### 2026-10-10 扫码适配方案

保留应用 mobile_scanner 7.4.1 的 Dart 控制器及扫码业务页面，原结果页完成后返回摄像头之前的入口规则不变。OHOS 原生候选取自 CPF-Flutter/fluttertpc_mobile_scanner br_v7.1.4_ohos，固定 f5a4ff52f003e1645db1d4de743a2db0313665a8。只移植原生目录及必要平台/预览分支，不用旧 Dart 控制器覆盖新版的会话归属和方向订阅修复。

审查启动异常、暂停/停止资源释放、迟到回调、扫码去重和图片格式限制；自定义扫描底层仅支持后置摄像头，不将切前摄显示为已支持。沿用系统 ScanKit，测试必须区分 Dart 通道契约、原生编译和真机识别。设备验收包括真实会员码/桌码/收银台登录码、相册识码、授权拒绝后重试、前后台切换及完成后返回入口。尚未执行实际收银登录、入场核销或付款。

### 扫码适配验证结果与平台隔离

- 未签名 HAP 编译通过（110.4 秒），原生注册器加入 MobileScannerPlugin。现有主工程 lib、android、ios、pubspec.yaml、pubspec.lock 相对 f4062766 无差异；所有平台包改动仅应用在 C:/HuaweiTools/kingclub-dependency-probe，主 SDK 未替换。
- 鸿蒙通道契约和原有扫码路由/控件共 27 项测试通过，包含权限拒绝重试、图片识别、桌码返回入口、收银台完成后回入口及再次扫码。测试原生依赖使用 fake/mock，未执行真实交易。
- Dart 分析无错误/警告，唯一多余 import 提示已删除。新增 staging 脚本和两份固定源码补丁，统一 patch LF 防止 Windows 换行导致补丁失效。最初因路径/换行失败，修正后等价分步接入成功；完整脚本仍需全新目录重跑。
- 原生补丁补齐 QR 格式限制、无重复模式、停止后的延迟重扫失效、启动异常传递与资源释放；当前仅后置扫描，实际旋转、相册坐标、后台恢复与快速关闭重进尚待真机验收。高级镜头选择、返回帧图像资源回收仍未验收，不宣称完整插件特性可用。

### 2026-10-10 头像裁剪适配方案

保留 image_cropper 12.2.1 和现有 Dart/platform-interface，复制 CPF-Flutter/fluttertpc_image_cropper br_v12.2.1_ohos 的原生目录，固定 6844f7d86b7dfc34e164fa913d8624fd114f3a32。不更改主工程 lib、Android/iOS 或依赖配置。原生端兼容现有 android.* 配色参数，保持调整头像标题、黑金背景、1:1、1024 上限与 JPEG 90 质量配置。

接入前修复：明确 AbilityAware，阻止覆盖 pending 回调，等待异步路由失败，仅清理插件下载的临时源图，分离时完成取消。当前真实调用仅使用相册/相机缓存本地文件；不新增远程下载业务。编译和通道测试不替代真机裁剪、取消、方向、压缩大小与上传验证。

### 头像裁剪构建结果

- stage-harmony-cropper.ps1 在现有隔离工程实际完整执行成功；Dart API 保持现有版本，注册 ImageCropperPlugin，原生内部 image_crop_ohos 随包编译。
- 2 项通道契约测试通过（参数、取消），Dart analyze 无问题，PowerShell 语法通过。测试使用 mock，不验证原生图片处理或文件删除行为。
- 未签名 debug HAP 编译成功（181.7 秒），没有安装/签名或真实上传。主工程 lib/android/ios/pubspec.yaml/pubspec.lock 相对 f4062766 仍无差异。
- 原生背景映射与裁剪质量待手机视觉及实际文件验证；网络源图并发和进程恢复未验收，当前 App 只传本地相册/相机缓存路径。

## 2026-10-10 前台定位适配节点

在独立鸿蒙 probe 保留 geolocator 14.0.3 和现有城市/聊天定位调用，接入固定版本 OHOS adapter（6fa6307b29fa6bc0e1983b146d2c33de48740862）。先修前台权限语义、模糊/精确权限、零值与模拟定位标志、持续定位间隔和错误回传。只申请前台定位；不申请后台定位。定位坐标插件与地址转城市是两项能力，后者尚待适配，不能仅凭编译宣布城市定位闭环。无真机，权限弹窗、定位质量和设置跳转保留验收项。

验证结果：鸿蒙未签名 debug HAP 构建通过（assembleHap 81.5 秒）；4 项 Dart 通道 mock 测试通过，覆盖零值/模拟标志、前台与模糊权限、超时请求标识、服务关闭与权限异常。Dart analyze 无错误或 warning，有 2 项 info（上游 Color.value 弃用、验证测试引用间接依赖）；补丁可在未修改源副本 apply --check。`git diff f4062766 -- lib android ios pubspec.yaml pubspec.lock` 无输出。未签名、未安装、未真机定位；下个节点为反向地理编码，当前不能宣称城市自动识别可用。

## 2026-10-10 反向地理编码节点

为现有 geocoding 5.0.0 提供独立 OHOS 平台实现，使用已安装 API 26 SDK 的 geoLocationManager 地理编码接口，保持 lib/ 与 Android/iOS 依赖不变。映射省、市、区县及地址字段，支持原有中文 locale；无结果返回空列表，不伪造默认城市；服务不可用和超时向原有页面错误处理传播。坐标读取仍由前台 geolocator 完成，地理编码不额外申请后台位置。以 Dart 通道测试与 HAP 编译验证，真实地理编码可用性和返回城市名称需真机验收。

验证结果：7 项地理编码通道测试通过（包含现有 locateHomeCity 函数→鸿蒙适配器的中文城市链路）；适配器 Dart analyze 无问题。现有首页“迟到定位不覆盖手动城市选择”用例首次在与构建同时运行时测试引擎报 Out of memory，构建完成后单独重跑通过。未修改该用例或 APP 页面来规避失败。HAP assembleHap 207.9 秒通过，未签名；主共享代码与 Android/iOS 工程相对 f4062766 无变化。原生 geocoder 服务、离线表现、地区覆盖、定位权限仍未做真机验收。

## 2026-10-10 聊天音频播放节点

保留 audioplayers 6.8.1 / interface 7.2.0 与现有 ChatVoicePlayback，本轮仅在独立 probe 引入 CPF-Flutter/flutter_audioplayers br_v6.5.1_ohos 原生适配（b853cdafdef1549be31b478a954f6d8b36d314e6）。审计先修全局初始化未回复、异步设置源未等待、错误伪报准备成功、本地文件句柄释放。按现有前台聊天语音使用，不新增后台常驻权限；播完、停止、切换账号/会话依然使用现有业务状态机。录音不是本节点。编译和 mock 测试不能替代实际声音、耳机/音频焦点和生命周期验收。

验证补充：原生设置音源出错时，必须同时返回 MethodChannel 错误和对应播放器 EventChannel 错误，否则 audioplayers 6.8.1 的 Future.wait 仍等待 prepared。通道测试发现该等待问题后已修复。3 项通道契约测试 + 21 项原有 ChatVoicePlayback 回归（共 24 项）全部通过，未改业务代码/原回归测试。首次测试因 C 盘仅余约 5 MB 失败，后以进程级 TEMP/TMP 指向 D:/SDK/harmony-task-temp，并将明确属于本次及前次失败测试的临时目录、上一份未签名 HAP 移到 D 盘保留；未删除用户文件或改全局临时目录配置。补丁在干净源副本 apply --check 通过。

最终未签名 HAP 构建通过（具体耗时见本机 audio-build-verified.log）；中间一次 ArkTS 编译要求焦点回调显式返回类型，修正后通过。当前验证仍是构建+通道/业务回归，不是实际原生播放验收。共享 lib、android、ios、pubspec.yaml、pubspec.lock 对 f4062766 无改动。下一节点可继续录音适配；真实声音、焦点和资源释放等按真机清单验收。

## 2026-10-10 前台语音录制适配

继续保留 record 7.1.1/interface 2.1.0 与现有 VoiceCapture 生命周期。候选来源 CPF-Flutter/fluttertpc_record br_v6.1.2_ohos，固定 c719424e0cd869bf57198e71768d11f995cce849。源码审计发现 start 在原生准备完成前返回成功、权限异常吞掉、取消不等待且不删除文件、所有编码均谎报支持，并默认创建后台录音任务；不可原样接入。仅支持当前业务需要的前台 AAC-LC/M4A，序列化原生操作，等待 prepare/start/stop/release，拒绝不支持的流式录音和编码，不申请后台录音权限。Dart OHOS 适配器覆盖 cancel 的等待行为（现有 interface 默认实现漏 await），不修改 Android/iOS 的公共接口包。采用通道/现有录音回归及原生编译，真机音质和中断待验收。

验证结果：stage-harmony-record.ps1 已实际接入隔离 probe；初次补丁缺少源文件无尾换行标记已修复，并在干净副本 apply --check 通过。3 项真实 NativeVoiceCaptureDevice 的通道 mock 测试和 15 项现有 VoiceCapture 回归共 18 项通过。覆盖 AAC/24kHz/48kbps/单声道配置、原生取消等待、拒绝权限、准备失败、许可弹窗中松手、取消/销毁重叠与短录音丢弃；这些测试不执行原生麦克风。

首次 HAP 编译暴露 ArkTS 构造器属性/泛型 MethodCall/异常类型限制，改为显式字段、类型转换后，最终 unsigned HAP assembleHap 53.3 秒通过（record-build-final.log）。本次明确使用现行 API https://api.wuyexin.cn 构建，修正此前 probe 构建命令使用历史 test 地址的记录；未发起业务写入。主工程 lib/android/ios/pubspec.yaml/pubspec.lock 对 f4062766 无差异。

当前仅提供 AAC-LC 文件录音；PCM 流及其他编码明确拒绝，设备列表不伪造。autoGain/echoCancel/noiseSuppress 不作原生效果保证，音质/系统中断/权限撤回/耳机/实际发送仍需真机验收。应用已有前后台回调结束按住说话，原生 Ability 分离亦排队取消录音；不启动后台录音任务。未签名、未安装。

Dart analyze 无 error/warning，有 2 项 info：OHOS cancel 修复继承当前固定 interface 包的 src 实现类；验证测试导入间接插件依赖。该内部类依赖已固定 interface 2.1.0，升级前必须重审，不将静态分析报告写为零提示。

## 2026-10-10 聊天文件选择适配方案

继续保留 file_picker 12.3.0/interface 3.4.0，新增独立 OHOS 实现，覆盖现有 FilePicker.pickFile() 的单文件任意类型调用。使用系统 DocumentViewPicker，不增加全盘存储权限。选择结果以只读 URI 打开，复制到应用私有缓存，返回真实名称/大小/本地路径，由原 ChatFileDraftStore 校验并复制到按账号会话隔离的草稿。沿用 256 MiB 上限；分块拷贝避免整文件进入内存，失败删除本次缓存、关闭句柄，不改动原始文件。取消返回 null，重复打开拒绝，Ability 分离使迟到结果失效。目录/保存/多选等非当前业务能力不虚报支持。通道测试和 HAP 编译后，云文件下载、系统取消、空间不足与真实发送仍须手机验收。

验证结果：staging 脚本在独立 probe 实际执行完成；4 项文件选择通道测试与 3 项原 ChatFileDraftStore 回归，共 7 项通过。覆盖真实公共 FilePicker 调用、中文原名、本地文件字节/流读取、取消结束加载、错误传播、超限拒绝、草稿账号会话隔离和失去会话时不得发布草稿。测试使用 mock 原生通道，不代表系统选择器或服务器发送已验收。

首次原生编译发现 fs.OpenMode 无 EXCL 常量，改用随机 UUID 私有路径并检查已有路径，碰撞时不清理原有文件；最终 unsigned HAP assembleHap 93.5 秒通过（file-picker-build-final.log）。主机 API 为 https://api.wuyexin.cn，未执行真实文件上传。实际云文件、空间不足、页面离开、原生句柄与系统取消待真机验收。缓存为系统可回收的应用私有中转文件，未实现额外定时清理，不宣称每次发送后已清空缓存。

本轮没有修改 lib/android/ios/pubspec.yaml/pubspec.lock；工作区期间另出现扫码点单的业务修改，保持原样且不纳入本节点提交。构建使用既有隔离 probe 的业务快照，不把它当成已同步其他并行业务改动的新发布版。
静态分析最终无提示。额外核对缓存路径碰撞保护后再次编译，最终结果以 file-picker-build-verified.log 为准。
最终含路径碰撞保护的未签名 HAP 已再次构建成功；未做真机安装及实际发送。

## 2026-10-10 后续补齐顺序（用户批准）

按视频缩略图→版本信息/返回手势→文件导出→地图→通知→支付→音视频通话推进；视频压缩、附近设备/原生直连、签名发布仍保留在总体缺口。每项区分适配、构建和真机验收。第一项保留 get_thumbnail_video 0.7.3 的 video_thumbnail 通道与 CachedVideoPoster 的本地授权缓存，使用系统 AVImageGenerator 提取帧、ImagePacker 输出 JPEG/PNG，现有默认首帧/宽320/JPEG质量80不变。仅处理本地源，不绕过既有鉴权下载；时间毫秒转微秒、等比例缩小、失败传播、句柄/像素/生成器释放须验证。此项不包含视频转码或真实发送。

第二项：版本号读取使用系统自身 BundleInfo 的 versionName/versionCode，保持 InstalledAppVersion 的显示接口，不写死版本。鸿蒙主题加入已有 KingSlidePageTransitionsBuilder，适配仅写到 probe，主 lib 不增加主 SDK 无法识别的 TargetPlatform.ohos。该节点不宣称 AppGallery 更新、发布签名或支付回调已完成。

本批验证完成：缩略图通道、版本读取、设置与会员码页进出动画共6项，另新增鸿蒙左边缘右滑返回测试1项，全部通过。原生未签名 HAP assembleHap 99.2秒通过（platform-thumbnail-build.log），API地址https://api.wuyexin.cn。测试为Flutter/mock验证，不代表真机图像生成或系统手势验收。缩略图先取原尺寸帧再等比缩小，高分辨率内存表现仍需手机测试；仅实现当前data接口，不虚报file接口。未修改主lib/android/ios或业务后端。后续按文件导出/打开→地图→通知→支付→音视频通话继续，视频转码、签名发布等仍未完成。

## 2026-10-10 聊天文件导出与打开方案

复用 ChatFileExporter 的 choose→二次鉴权→copy→openSaved/cancel，不改变业务鉴权与会话/消息删除监听。独立鸿蒙插件使用 DocumentViewPicker.save 创建用户选择的文档，只接受本次操作返回的 URI；来源严格限定 cacheDir/kingclub-chat-download-*/content.bin，拒绝符号链接。256 MiB 上限，分块 SHA-256 与字节数核对后才写入，写入时再次验证；取消与 Ability 分离使在途操作失效。仅清理本次选择且确认空的新文档，不删除已成功导出的文件；拒绝非空目标，避免静默覆盖。打开只允许已保存操作的 URI，通过系统只读打开。仅在 probe 启用现有文件详情按钮的 OHOS 分支，Android/iOS主业务保持不变。系统选择器、第三方查看器、云文件、空间不足及真实取消需真机验收。

验证结果：原有 ChatFileExporter 6项回归通过，包含选择/复制阶段删除取消、再次鉴权被拒和页面释放，未修改原业务测试。首编译仅因 ArkTS 不允许直接 rethrow 任意异常类型失败，改为明确 Error 后，最终未签名 HAP assembleHap 54.8秒通过（file-export-build-final.log）；同时包含UTD文件类型识别。使用当前 https://api.wuyexin.cn 构建，未执行真实文件上传或服务器写入。实际系统保存、分块写入、SHA-256原生行为与查看器仍待真机验收，mock通过不能替代此项。来源两遍读取采用lseek归零与顺序读取，避免各接口offset含义差异。本节点主lib/android/ios无改动。

下个地图节点已检查：已有定位与地理编码平台适配可复用；聊天原生地图视图、静态预览的平台门槛及kingclub/chat-map打开通道仍需分别补齐，不能以定位插件已注册宣称地图完成。

## 2026-10-10 鸿蒙地图第一节点：系统查看与路线

聊天已有定位/地理编码适配，但 kingclub/chat-map 通道没有原生处理。本节点接入本机 Harmony SDK petalMaps.openMapPoiDetail/openMapRoutePlan，保留既有页面、选择后明确发送与会话有效性校验，不更换业务地图UI。仅在明确点击打开时传递经纬度和地点名称，不传地址、会员或聊天内容。WGS84/GCJ02使用SDK明确coordinateType，不做二次坐标转换；该参数自API21起支持，低于21对WGS84明确失败而不冒险显示错位。API18–20仅支持已为GCJ02的输入。异步调用去重、失去Ability后结果失效。原生地图未安装或调用失败沿用页面失败提示。

本节点不宣称内嵌拖拽地图和静态预览完成。已检查当前独立宿主未找到agconnect配置；新增华为在线地图服务需核验开发者控制台MapKit开通/应用认证，不以现有定位服务代表具备地图服务资格。接口依据本机API26的@hms.core.map.petalMaps.d.ts，地图坐标参考官方https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V13/map-introduction-V13。

验证完成：2项OHOS平台地图通道测试与9项既有位置页面回归共11项通过。首次模板未在测试结束前恢复debug平台覆盖而失败，修复测试清理后全通过，未修改业务绕过用例。最终默认“导航”走驾车路线、显式view走地点详情的代码已构建，unsigned HAP assembleHap 42.7秒通过（map-build-final.log）。未签名、未真机启动地图/核验落点。主lib/android/ios及后端没有修改；地图节点尚有内嵌视图、静态预览和在线地图服务配置待完成，后续通知/支付/通话未因本次编译而完成。

## 2026-10-10 内嵌地图与快照方案

继续使用原 ChatLocationPickerPage、DeferredChatMap、ChatMapPreviewCache。鸿蒙侧接 Huawei MapComponent 和 staticMap，独立同意状态与说明不能沿用“腾讯地图”授权；默认不调用在线地图，用户在位置页同意后才初始化。接入现有center/status/moving/centerChanged/cancel通道；位置仍需用户明确确认才发送。鸿蒙搜索复用既有系统地理编码，不伪造附近POI；附近仍显示实际中心候选。地图坐标通过 SDK rectifyCoordinate 判断当前地图数据的坐标系，不能按矩形边界盲转。快照只发坐标，不发聊天/姓名/令牌，输出限640×320 JPEG并释放PixelMap。已同意时快照仍受会话缓存失效规则控制。原生认证失败不得标记ready。构建不证明线上地图服务开通。

节点验证：内嵌地图及静态预览源代码已接入隔离probe并构建通过，最终unsigned HAP assembleHap49.9秒（embedded-map-build-final.log）。19项原位置/系统地图回归与3项新快照通道测试通过；新测试覆盖腾讯授权不得代替华为授权、仅发坐标、缓存复用和认证失败后可重试。初次ArkUI编译要求view属性初始值，修正nullable显式初始化后通过。无真机及在线应用认证验收，不宣称地图已线上可用。附近POI列表未实现，系统搜索和实际地图中心候选保留。共享业务工程及安卓/苹果源文件无变化。
