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
