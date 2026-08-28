# 扫码识别与安全分流页

- Scope ID：`KC-P-012`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[安全扫码分流](../../README.md)
- 旧版来源：`pages/index/index`、`pages/addfriend/addfriend`
- 路由语义：`SafeScannerRoute`，`/scan`，protectedShell overlay，禁止外部直达
- 设计版本：`Safe Scanner Wireframe v1`
- 最后更新：2026-08-28
- UI 状态：`UI Mock Implemented`

## 用户任务

了解相机用途，扫描一个 KingClub 消费者二维码，看到可理解的识别/错误状态，并安全进入对应业务页面或返回原位置。

## 入口、出口与返回

- 入口：Shell 中央扫码或首页“安全扫码”；只接受内存 `OriginBranchRef`。
- 前置：authenticated + membership approved；构建前再次校验 session generation。
- 成功：resolver 返回允许类型后，由 NavigationCoordinator replace overlay 为目标页或关闭后 push 到来源分支的批准路径。
- 取消/失败/权限拒绝：pop 返回原分支、原栈和原滚动位置。
- 非法来源引用：安全关闭到首页根；不从 URI 恢复扫描上下文。

## 线框

```text
[关闭]                 扫一扫                 [补光灯]

┌──────────────────────────────┐
│                              │
│        [相机 / Fake 画面]      │
│          ┌────────┐          │
│          │ 扫码框  │          │
│          └────────┘          │
│                              │
└──────────────────────────────┘
将 KingClub 好友码、桌台码或入场码放入框内

[状态/错误说明]
[重新扫码] [打开系统设置（适用时）]
```

首次未授权时用用途说明与“开始扫码”按钮替代相机画面。UI Mock 只显示合成占位，不渲染真实摄像头内容。

## 组件与规则

- 顶部关闭始终可用；解析临界区返回时使 attempt 失效，不弹业务成功。
- 补光灯只有相机 active 且设备支持时出现；关闭页/进后台自动关闭。
- 扫码框不作为唯一识别反馈；必须有文字、语义播报和触觉可选反馈。
- 识别后暂停相机，显示“正在安全识别”；失败时明确“重新扫码”。
- 不显示或复制原始二维码文本，不提供“在浏览器打开”。

## 隐私与埋点

- 相机用途限定为二维码识别；不保存预览帧、不上传画面，只把捕获的 payload 交给受控 resolver。
- 埋点记录来源类别、权限结果、允许类型/失败类别和耗时桶，不含 payload、图像或业务 ID。
- App 切到后台立即停止预览；任务切换缩略图保护策略在原生能力文档中统一评审。

## 当前实现记录

- 已实现 `/scan` 类型化全屏路由，并由 Shell 中央入口和首页入口共用。
- 已实现用途说明、Fake 权限选择、Fake 取景器、补光灯 UI、识别中、三类 allowlist 成功意图、拒绝/过期/离线异常与重新扫码。
- 允许结果只向 Shell 返回类型化内存意图；目标业务页尚未实现时显示明确提示，不创建真实好友、订单或核销动作。
- Android API 37 模拟器已验证打开、识别、关闭与返回原首页状态；Widget 测试已覆盖好友资料安全意图。
- 已补齐 SingleFlight、解析中关闭后迟到结果失效、会话失效、前后台暂停与补光灯自动关闭。
- 13 组专项测试已覆盖 SCAN-M01～M16，设备截图与审计见 [ui-audit.md](ui-audit.md)。

## 验收

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。页面已达到 `UI Mock Implemented`；仍须等待项目级 `UI Flow Approved`，不声明系统权限或接入真实扫码能力。
