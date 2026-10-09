# HarmonyOS 原生适配

日期：2026-10-09。用户已批准开始适配；当前处于工具链与依赖验证，尚未产出或安装 HAP。

## 范围

沿用当前 Flutter 页面、交互、真实接口和账户，不另外开发展示壳。Android/iOS 使用现有 SDK、依赖锁和签名；鸿蒙工具链独立放置，未经验证不覆盖原工程。目标设备为用户连接的 nova 14 Pro，用户报告 HarmonyOS 6.1.0.135；Windows 已识别 HDC Interface，ADB 不识别该手机。

## 已核实的问题

- 当前主工程 Flutter 3.47.1 / Dart 3.13.1，pubspec 约束 `^3.13.1`，没有 ohos 工程。
- 本机尚无 DevEco/Harmony SDK、HDC 命令与已配置的鸿蒙签名。
- CPF-Flutter `oh-3.47.0-dev_bak` 提交 `1f36fc0ae74955c780646ac3c0916a2f0e4676a6` 引用的 Windows Dart SDK 返回 `NoSuchKey`，不能作为可用构建基线。
- `oh-3.44.9-dev` 提交 `589ff5319af950a72c45dcf07880fbbf3b5a5aaf` 已下载并成功运行 Flutter 工具，实际 Dart 为 3.12.2，不满足当前 APP 的 3.13.1 下限。它是开发分支，不能称为稳定生产工具链；仍须检查 Dart 约束、Flutter API 和插件兼容性。
- 当前解析依赖中，fluwx、tobias、flutter_image_compress_ohos 已带 ohos 源码，尚未进行鸿蒙编译或支付验证。其余插件不能因为存在 Android/iOS 实现就视为支持鸿蒙。
- 用户确认已有实名认证华为开发者账号，下载中心页面亦显示已认证。用户已下载 DevEco Studio 26.0.0.851，ZIP 3,295,837,057 字节；解压后 EXE 3,295,943,544 字节，Windows Authenticode 校验 Valid，签发主体 Huawei Technologies Co., Ltd.。
- D 盘空间不足，安装器移至 `C:/HuaweiTools/deveco-studio-26.0.0.851.exe`，目标 `C:/HuaweiTools/DevEcoStudio`。当前安装进程等待 Windows UAC，尚未确认安装完成，不计为 SDK 或签名已就绪。
- 在 `C:/HuaweiTools/kingclub-dependency-probe` 复制 manifest/lock 做隔离解析：原约束明确被 Dart 3.12.2 拒绝；仅在此临时副本降低约束后，又因工具链报告 Flutter `0.0.0-unknown` 被 go_router_builder 拒绝。主工程 manifest/lock 未修改；临时实验不表示依赖已经兼容。

## 实施顺序

1. 安装并验证独立工具链、HDC 真机识别与开发者签名。先验证依赖解析，不盲目降低主工程 Dart 约束。
2. 在隔离构建目录验证同一份应用代码及鸿蒙插件版本，固定所有来源和提交。确认后添加 ohos 宿主和可重复构建脚本。
3. 先接通启动、资源、网络、数据库、安全存储和登录；继续扫码、定位、图片、音视频、通知与支付。
4. 真机检验现有页面、相机返回规则、键盘、前后台、权限拒绝和真实服务连接；通过后签名安装。

## 原生适配清单

运行 `pwsh -File scripts/audit-harmony.ps1` 查看本机实际解析依赖和原生通道。该脚本只读，不改 pubspec/lock，也不运行依赖更新。

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
