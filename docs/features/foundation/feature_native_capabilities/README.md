# 原生能力与权限

- Scope ID：`KC-F-009`
- 文档状态：`Approved for Development`
- 所属业务域：`foundation`
- M0 范围：`In Release Scope`
- 设计版本：`Native Capabilities v1`
- 批准日期：2026-08-26

## 目标与用户价值

以统一、最小化、可解释的方式提供相机、相册、扫码、通知、定位、媒体预览和系统设置跳转。业务页面表达能力意图，平台 adapter 负责 iOS/Android 差异；拒绝权限不能阻断不需要该能力的其他流程。

## 已确认事实

- 本期涉及扫码、头像/会员图片选择、媒体浏览、通知提示和可能的门店位置展示。
- 权限拒绝、永久拒绝、系统限制和 App 生命周期变化必须能在 UI Mock 中完整演示。
- 项目达到 `UI Flow Approved` 前不得接入真实插件、系统权限或生产推送 SDK。

## 已确认方案

- 业务层只依赖 `CameraPort`、`MediaPickerPort`、`ScannerPort`、`NotificationPermissionPort`、`LocationPort`、`MediaPreviewPort` 和 `SystemSettingsPort`。
- 权限按动作即时请求，不在启动时批量弹窗；先展示用途说明，再由用户动作触发系统请求。
- 首次拒绝保留功能内重试入口；永久拒绝/系统关闭提供明确说明和“前往系统设置”，返回前台后重新查询。
- 受限设备、家长控制、无硬件、插件异常和用户取消都使用独立结果，不伪装成普通拒绝。
- UI Mock 只使用 Fake 结果；真实插件选型、Info.plist/Manifest 声明和真机行为在真实接入阶段完成。

## 页面与范围

本功能不拥有独立消费者页面。权限说明、拒绝、恢复和降级 UI 由发起能力的 KC-P 页面承担，并复用统一组件和文案规则。

本期不包含后台持续定位、通讯录批量上传、麦克风录音、蓝牙、健康数据、广告跟踪授权或任意“为了以后可能使用”而申请的权限。

## 文档

- [能力与页面矩阵](capability_matrix.md)
- [权限状态与交互流程](permission_flow.md)
- [隐私、测试与真实接入边界](privacy_and_test.md)
- [验收标准](acceptance.md)

## 已确认决策

1. 权限按需请求，启动阶段不批量索取。
2. 页面只依赖自有端口，不直接调用平台插件。
3. 拒绝后保留无权限可用路径；永久拒绝才引导系统设置。
4. 相册/文件选择优先采用系统选择器与最小授权，不要求全库权限。
5. 用户于 2026-08-26批准 `Native Capabilities v1`。

## 开发门禁

本模块达到文档准入。UI 阶段只能实现 Fake 权限与 Fake 能力结果；整 App `UI Flow Approved` 后才允许接入插件、修改平台权限声明并进行双端真机验收。
