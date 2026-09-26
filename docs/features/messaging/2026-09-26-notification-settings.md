# Android 通知设置

本节点将设置页的预设通知状态替换为 Android 实际应用通知开关；读取失败显示未知，不宣称已允许。点击打开系统设置进入当前包名的通知设置，返回应用重新读取。不依赖 OPPO 注册凭据，不修改系统开关，不反复请求权限。

此状态仅代表应用级开关，不代表各渠道、勿扰模式、厂商推送或离线来电已通过验收。渠道配置、首次权限引导与真实推送仍需后续完成。

验证：桥接与设置流程共 12 项测试通过，4 个 Dart 文件静态检查无问题。Android `:app:compilePreviewProfileKotlin` 日志显示 BUILD SUCCESSFUL（build/notification-settings-native.log）；PowerShell 重定向包装返回 1，Gradle 本身打印退出码 0。尚未安装实机验收通知设置跳转。
