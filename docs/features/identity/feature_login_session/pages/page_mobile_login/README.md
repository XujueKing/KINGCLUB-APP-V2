# 手机号登录页

- Scope ID：`KC-P-002`
- M0 范围：`In Release Scope`
- 文档状态：`Approved for Development`
- UI 阶段：只允许 Flutter UI/Mock，不接真实短信或登录接口
- 旧版来源：`D:\WEB3_AI\KingClub-git\pages\regist`
- 视觉基准：用户于 2026-08-28 提供的旧版登录截图

## 页面目标

直接复刻旧版 `pages/regist` 登录页：在同一页输入手机号、获取验证码、输入验证码并点击底部 `NEXT` 完成离线 Fake 登录。注册与登录保持同一外观，禁止通过提示泄露号码是否已注册。

## 视觉契约

- 本页以旧版截图和 `pages/regist` WXML/WXSS 为唯一视觉基准，不再沿用 V2 登录卡片布局。
- 顶部使用旧版金色透明 `logo_2.png`，宽 `220rpx`（约视口宽的 `29.33%`），保持原始宽高比。
- 表单宽 `600rpx`（约视口宽的 `80%`）；输入框和按钮高 `90rpx`，圆角 `45rpx`。
- 手机号框使用旧版 `radial-gradient(circle 600rpx at 0% 0%, #B8A289, #7E6951)`：Flutter 必须按约 `300dp` 固定半径绘制，不能按 45dp 输入框高度缩放；旧 WXSS 的 `350rpx + 250rpx` 还会叠加输入框横向 padding，最终截图中的验证码输入区与获取按钮约为 `65% : 35%`，原生页按最终可见比例复刻。
- 底部使用深棕色 `NEXT` 按钮和 `SHANGHAI . ZHUZHOU` 原文。
- 标签使用 `30rpx`（约 `15dp`）和 `#C9B69E`；手机号输入为 `42rpx`，验证码输入为 `40rpx`，验证码占位为 `32rpx`。
- 获取验证码和 `NEXT` 严格使用旧版 `#24180A` 背景与 `#AAC9B69E` 文字，不增加描边或提高棕色明度；禁用态只降低文字强度。
- App 保留系统状态栏与返回导航，不复刻微信右上角宿主胶囊。
- 页面不显示 V2 协议行、账户说明卡、大标题或可见 UI 测试说明。

## 路由与导航

- 路由为 `/auth/mobile`，由旧版欢迎封面页进入。
- 短信请求成功后仍停留本页，内存保留 `challengeId`。
- `NEXT` 验证成功后直接进入实名与成年核验；手机号、challenge 和验证码不放入 URL。
- 顶部返回键回到旧版欢迎封面页。

## 信息架构与线框

```text
[<]
                 [金色 King club Logo]

Mobile Phone:
[手机号_____________________________________]
Code:
[输入验证码____________][获取验证码]


[                         NEXT                         ]
                 SHANGHAI . ZHUZHOU
```

协议已在前一页同意。两个输入框均使用数字键盘，不读取通讯录。键盘弹出时表单可滚动，底部 NEXT 不得被永久遮挡。

## 校验与交互

- 手机号输入时去除空格和连字符；请求验证码前做 11 位大陆手机号格式初筛。
- 请求期间禁用重复点击；成功后开始 60 秒重发倒计时，不跳转新页。
- 手机号为空且未聚焦时显示旧版“请输入电话号码”；获得焦点后立即隐藏，空值失焦后恢复。点击输入框之外的页面空白区域必须统一失焦并收起软键盘。
- 验证码为 6 位数字；未获取 challenge 或验证码不完整时 NEXT 为禁用态。
- 离线 Fake：`888888` 通过，`111111` 错误，`222222` 结果未知，`333333` 过期。
- 限流、离线、错误和过期用页内文本反馈，不改变旧版主布局。

## API 映射

- 获取验证码调用 `K260824000101 auth.sms.request`：`mobile`、`scene=login`、`clientAppCode=kingclub`、`clientType/deviceId`、`idempotencyKey`。
- NEXT 在真实接入阶段调用已批准的验证码登录契约；当前仅调用 `MockRuntime.verifyCode`。
- 响应仅在内存保留 `challengeId/expiresInSeconds/retryAfterSeconds/maskedMobile`；手机号和验证码不进入日志、埋点、URL 或普通本地存储。

## 状态、埋点与可访问性

- 状态：`idle`、`invalid_mobile`、`requesting_code`、`code_ready`、`verifying`、`invalid_code`、`rate_limited`、`offline`、`service_error`。
- 手机号只记录“格式是否有效”，不记录原文或哈希。
- 输入框有可读标签，返回、获取验证码和 NEXT 点击区不小于 44×44。

## 不做事项

本页不要求实名、不展示注册状态，也不实现微信、密码或游客登录。

## 配套文档

- [状态与错误映射](states.md)
- [交互与生命周期](interactions.md)
- [验收标准](acceptance.md)
- [评审记录](review_record.md)
- [所属功能](../../README.md)
