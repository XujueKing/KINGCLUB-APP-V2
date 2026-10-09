# HarmonyOS 原生适配

日期：2026-10-09。用户已批准开始适配；当前处于工具链与依赖验证，尚未产出或安装 HAP。

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

目前不能对用户承诺可安装版本。待解决：工具链与 Dart 版本匹配、鸿蒙依赖及所有关键原生通道、华为开发者认证和签名、真机功能验证。证书、私钥、账号密码不提交仓库。

参考：<https://gitcode.com/CPF-Flutter/flutter_flutter>；<https://developer.huawei.com/consumer/cn/download/>。工具链状态以实际下载和构建结果为准。
