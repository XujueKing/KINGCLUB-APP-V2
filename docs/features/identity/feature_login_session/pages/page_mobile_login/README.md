# 手机号登录页

- Scope ID：`KC-P-002`
- M0 范围：`In Release Scope`

## 文档状态

`Approved for Development`。页面交互、短信发送和未登录协议目录契约均已完成评审；全局文档门禁已于 2026-08-26 满足，可进入 UI/Mock 实现。

## 页面目标

让用户输入中国大陆手机号、阅读协议入口并请求登录验证码。注册与登录保持同一外观，禁止通过提示泄露号码是否已注册。

## 路由与导航

- **当前建议**：路由名 `/auth/mobile`；可选内存参数 `returnTo`，必须经过路由白名单校验。
- 启动鉴权失效、用户主动登录或受保护路由守卫可进入。
- 请求成功后进入 `/auth/code`，只传内存中的 `challengeId`、脱敏手机号、过期/重发秒数和已验证的 `returnTo`；不得把手机号或 challenge 放入 URL。
- 系统返回键：若无已认证页面可退则提示退出应用；不得退回启动鉴权页。

## 信息架构与线框

```text
[返回/关闭]              [帮助]
KingClub
手机号登录
[+86] [请输入手机号____________]
[获取验证码]
[ ] 我已阅读并同意《用户协议》《隐私政策》
号码未注册时将自动创建 KingClub 会员
```

协议链接可独立打开只读页面；返回后保留手机号和勾选状态。输入框支持粘贴、清除和数字键盘，不读取通讯录。

## 校验与交互

- 输入时去除空格和连字符；提交时由客户端做 11 位大陆手机号格式初筛，服务端仍是最终权威。
- 未勾选协议时点击按钮，不请求接口；就地高亮协议区并提供可访问性说明。
- 提交期间禁用重复点击；网络重试复用业务 `idempotencyKey`，每次密文请求生成新 requestId。
- `K260824000101` 成功后立即导航验证码页；无论号码是否存在，页面文案和响应外观一致。
- 限流时按 `retryAfterSeconds` 禁用按钮并显示统一倒计时；服务端错误不得直接显示堆栈或内部码。

## API 映射

调用 `K260824000101 auth.sms.request`：`mobile` 来自规范化输入；`scene=login`；`clientAppCode=kingclub`；`clientType/deviceId` 来自可信应用上下文；`idempotencyKey` 由本次用户动作生成。

响应只保留 `challengeId/expiresInSeconds/retryAfterSeconds/maskedMobile`。手机号原文不进入日志、埋点、URL、剪贴板回显或普通本地存储。

页面显示协议及形成 `consents` 前，必须通过 `K260824000107` 取得 `terms/privacy` 当前发布版本、标题、Markdown 正文和内容摘要，具体见[协议目录读取契约](../../agreement_catalog_contract.md)。目录不可用时协议区失败关闭，不允许发送验证码。

## 页面状态、埋点与可访问性

- 状态：`idle`、`invalid_input`、`consent_required`、`submitting`、`rate_limited`、`offline`、`service_error`。
- 埋点：`mobile_login_view/request/result/agreement_open`，手机号只记录“格式是否有效”，不得记录原文或哈希。
- 错误信息使用文本与图标双重表达；输入标签不依赖 placeholder；键盘弹出时按钮和协议可滚动可见；触控区不小于 44×44。

## 不做事项

本页不校验验证码、不签发会话、不要求实名、不展示注册状态，也不实现微信、密码或游客登录；这些能力必须独立评审。

## 配套文档

- [状态与错误映射](states.md)
- [交互与生命周期](interactions.md)
- [验收标准](acceptance.md)
- [评审记录](review_record.md)
- [所属功能](../../README.md)
