# App Shell/底部导航容器

- Scope ID：`KC-P-010`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[App Shell 与全局信息架构](../../README.md)
- 旧版来源：`pages/index/index` 的外层 Swiper 与动态 `tabData`
- 路由语义：`AppShellRoute`；自身不是可外部打开的内容页
- 设计版本：`Legacy Shell Replica v1`
- 批准日期：2026-08-26

## 页面目标

承载五个稳定主目的地、旧版悬浮胶囊视觉、安全区域、分支内容、全局网络提示和消息徽标。业务页面决定自己的内容，Shell 不展示服务端动态菜单。

## 入口与出口

- 成功入口：bootstrap 复核 authenticated + membership approved 后 reset 到首页分支。
- 普通出口：子页面、扫码页、系统后台/退出。
- 安全出口：会话清理完成后 reset 手机号登录；会员状态变化后 reset KC-P-009。
- 不允许通过 App Link、推送或字符串 URI 直接构造 Shell。

## 线框说明

```text
┌─────────────────────────────┐
│ 系统安全区                  │
│ [离线提示：仅需要时显示]    │
├─────────────────────────────┤
│                             │
│ 当前分支页面内容            │
│ 独立处理加载/空/错等状态    │
│                             │
├─────────────────────────────┤
│ 首页  消息   [内容]  储物  我的 │
└─────────────────────────────┘
```

- 五个目的地使用旧版真实图标、顺序、圆形选中底和悬浮胶囊；无视觉文字时必须提供完整无障碍标签。
- 中央内容 Tab 使用旧版爱心图标和较大选中态，但不得遮挡内容、Home Indicator 或系统手势区域。
- 导航栏背景与内容有明确边界；视频流可在其下方延伸，但文字/触控保持可读。
- Shell 不拥有 AppBar；各分支根页按页面文档决定顶部栏。

## 组成

| 区域 | 责任 |
|---|---|
| Content Host | 展示当前分支栈最上层页面 |
| Connectivity Banner | 稳定离线/恢复提示，不展示技术异常原文 |
| Primary Navigation | 首页、消息、内容、私人储物柜、我的 |
| Safe Scan Entry | 不在底栏；由首页三联入口打开 KC-P-012 |
| Badge | 消息聚合未读，0 隐藏、最大 `99+` |
| Safe Area | 适配状态栏、刘海、圆角与 Home Indicator |

## 页面状态

详见 [states.md](states.md)。Shell 自身只有 ready、offlineOverlay、sessionTransition、membershipTransition；业务加载/空/错态不能提升成 Shell 状态。

## 交互与返回

详见 [interactions.md](interactions.md)。五分支进程内保活、重按 Tab 回根/滚动到顶；扫码关闭后恢复首页来源状态。

## Mock 与验收

- 使用 [SHELL-M01～M12](../../mock_scenarios.md)。
- 页面验收见 [acceptance.md](acceptance.md)。
- 设计依赖 KC-F-003 Design System v1。

## 开发门禁

本页与全局文档门禁均已达到准入，可以实现 UI/Fake；项目达到 `UI Flow Approved` 前不得连接真实服务。
