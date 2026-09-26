# Android 通知设置

本节点将设置页的预设通知状态替换为 Android 实际应用通知开关；读取失败显示未知，不宣称已允许。点击打开系统设置进入当前包名的通知设置，返回应用重新读取。不依赖 OPPO 注册凭据，不修改系统开关，不反复请求权限。

此状态仅代表应用级开关，不代表各渠道、勿扰模式、厂商推送或离线来电已通过验收。渠道配置、首次权限引导与真实推送仍需后续完成。

下一节点：已登录、厂商注册和服务器绑定成功后，前台尝试一次 Android 13 通知授权。复用原通话授权的 asked 标记，拒绝或关闭后不因注册重试重复弹窗；请求失败不破坏绑定和通话。旧系统创建与平台登记一致的 `com_lingmei_kingclub` 渠道；已有渠道保留用户选择。此渠道不替代 OPPO IM 分类审批。

2026-09-27 此节点代码已实现。运行时与桥接共 13 项测试通过（覆盖后台不提示、提示异常不重试绑定），静态检查通过；原生编译日志 notification-permission-native.log 显示 BUILD SUCCESSFUL，Gradle 退出 0（PowerShell 日志重定向包装仍返回 1）。ADB 确认 A/B 在线，但仍安装旧的 `.v2preview` 包，正式包尚未安装，因此未声称手机上的新版授权已验收。

验证：桥接与设置流程共 12 项测试通过，4 个 Dart 文件静态检查无问题。Android `:app:compilePreviewProfileKotlin` 日志显示 BUILD SUCCESSFUL（build/notification-settings-native.log）；PowerShell 重定向包装返回 1，Gradle 本身打印退出码 0。尚未安装实机验收通知设置跳转。
