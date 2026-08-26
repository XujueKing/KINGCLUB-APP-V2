# 协议确认页

- Scope ID：`KC-P-004`
- M0 范围：`In Release Scope`

## 文档状态

`Approved for Development`。用户已于 2026-08-24 批准页面九项规则；全局文档门禁已于 2026-08-26 满足，可进入 UI/Mock 实现。

## 页面目标

展示 K107 返回的当前用户协议与隐私政策正文，并在登录期间协议版本变化时重新取得明确同意。它不是默认每次启动展示的注册页，也不独立向服务端写同意记录。

## 入口、出口与路由

- **当前建议**：路由 `/auth/consent`，只接受类型化的内存模式 `readOnly|loginRecovery`；不得进入 URL、深链或系统恢复状态。
- `readOnly`：从手机号页的协议链接进入，可指定初始 `terms|privacy` 标签；返回后保留手机号页的内存输入与勾选状态，不在本页形成同意。
- `loginRecovery`：仅携带不透明 `loginFlowId`；原手机号、challenge、旧协议快照和 `returnTo` 仍由登录流程协调器保存。
- 恢复模式同意后更新内存 `ConsentSnapshot` 并返回验证码页重新输入；拒绝或确认退出则销毁整个登录流程并回手机号页。
- 上下文缺失、challenge 已过期或协议目录不可用时失败关闭，不得使用客户端硬编码版本继续。

## 信息架构与线框

```text
[关闭]                     协议与隐私
[用户协议 vX] [隐私政策 vY]
发布日期：YYYY-MM-DD
┌────────────────────────┐
│ 当前标签的 Markdown 正文 │
│ 可滚动、可选择文字       │
└────────────────────────┘
[ ] 我已阅读并同意《用户协议》《隐私政策》
[同意并返回验证码页]
[暂不同意]
```

`readOnly` 模式隐藏复选框与提交按钮，只显示关闭。`loginRecovery` 模式显示两份协议标签、版本、K107 的 `publishedAt` 和完整正文；K107 当前没有生效日或变更摘要字段，页面不得伪造。不得默认勾选、倒计时自动同意、强制滚动到底或弱化拒绝按钮。

## 状态与规则

- `loading_catalog`：通过 K107 读取当前发布目录，不接受路由注入正文或版本。
- `ready_read_only`：正文完整，可切换标签和返回，不显示同意控件。
- `ready_recovery`：challenge 有效、两份正文完整，等待明确勾选。
- `refreshing_catalog`：缓存到期或 App 恢复后重新读取；提交暂时禁用。
- `version_changed`：清除旧勾选并展示新版本提示，两份协议作为一个新快照重新确认。
- `offline/error`：恢复模式不可继续登录；允许重试或暂不同意退出。
- `accepted_locally`：只更新内存 `ConsentSnapshot` 并返回验证码页；不声称服务端已经记录。

V1 默认要求 `terms` 与 `privacy` 两项均明确同意。未来营销授权、定位或通讯录授权必须拆分，不能捆绑到基础登录协议中。

## API 与同意写入边界

- 页面只调用 `K260824000107 auth.agreements.current`，校验 `catalogVersion/expiresAt`、两份协议字段、Markdown 大小和 SHA-256 摘要。
- `ConsentSnapshot` 保存 `catalogVersion` 及两份 `agreementCode + version + contentDigest`；仅存在登录流程内存中。
- 点击“同意并返回验证码页”不会调用独立写接口。后续 K102 只提交两份 `agreementCode + version`，服务端重新读取权威摘要并在登录事务中追加 `consentRecord`。
- 如果 K102 再次返回 `AUTH_CONSENT_VERSION_INVALID`，重复刷新流程；不得把客户端本地勾选视为服务端同意事实。
- 已登录用户因协议升级需要重新同意的独立接口尚未建设，不属于本页 V1；不得复用本页绕过服务端记录。

## 数据、埋点与可访问性

- 页面输入输出仅包含公开协议目录、只读模式或不透明 `loginFlowId`；手机号、账号、验证码、challenge 和会话密钥不属于页面模型。
- 埋点：`consent_view/document_open/accept/decline/error`，记录协议代码与公开版本，不记录正文选择、用户身份或敏感数据。
- 受控 Markdown 禁用原始 HTML/脚本和危险 URI；不支持的内容结构失败关闭，不静默删改法务正文后继续同意。
- 支持动态字体、读屏标题层级、每个标签的内存滚动位置和清晰焦点；复选框、标签和正文链接分别可操作。

## 不做事项

本页不承担实名认证、个性化推荐授权、系统权限申请或广告授权；每种额外目的需独立功能文档和撤回机制。

## 配套文档

- [状态与错误映射](states.md)
- [交互与生命周期](interactions.md)
- [验收标准](acceptance.md)
- [评审记录](review_record.md)
- [所属功能](../../README.md)
