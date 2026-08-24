# 深链、推送与 returnTo 契约

- 文档状态：`Approved for Development`
- 原则：外部输入先解析为受控 RouteIntent，永不直接交给 Router

## 0. 当前范围

当前 UI Mock 阶段没有任何已批准的 App Link 或推送跳转目标，因此不实现 `ExternalIntentParser`、`PendingIntentStore` 或推送导航 adapter。本文件只定义未来启用单个目标前必须满足的安全门禁；不能作为现在创建订单、聊天或其他路由的依据。

## 1. 输入来源

```text
iOS Universal Link / Android App Link
push notification action
应用内受保护入口
  -> ExternalIntentParser
  -> scheme/host/path/query/size allowlist
  -> typed RouteIntent
  -> GuardPolicy
  -> pending / allow / reject
```

未来只为已配置平台关联文件的 HTTPS Universal/App Link 开放具体已批准目标，不默认开放自定义 scheme。正式 host、关联文件、签名证书和推送供应商尚未确认。

## 2. 解析与拒绝规则

- 原始 URI 必须有总长度上限、有效 UTF-8/percent encoding、HTTPS scheme、精确 host 和默认/批准端口。
- path 必须完全匹配 allowlist pattern；query 只接受该 RouteIntent 声明的标量字段，拒绝重复键、未知键、fragment 和 userinfo。
- 不接受嵌套 URL、序列化页面栈、任意 `returnTo` 字符串、手机号、Token、challenge、验证码、账号或完整业务对象。
- path/query 中的资源 ID 只做格式和长度校验；访问权限仍由目标 API 复核。
- raw URI、推送 payload 和解析异常原文不得进入生产日志；只记录来源、稳定结果分类和 route type。

## 3. 登录路由禁止外部直达

以下 location 即使字符串匹配也不能由外部输入构造：

- `/auth/bootstrap`
- `/auth/code`
- `/auth/consent` 的 `loginRecovery`

`/auth/mobile` 可以作为匿名安全 fallback，但外部参数全部丢弃。协议 readOnly 只能由 App 内已批准入口构造，V1 不作为法务网页外链替代品。

## 4. returnTo

当前登录 UI Mock 的 `returnTo` 固定为空，登录成功只进入 home 语义。未来具体目标页面批准后，`returnTo` 在领域层才可以扩展为 `RouteIntent?`，且不能是 URL：

```text
routeType
validatedScalarParams
source                 inApp | appLink | push
issuedAt/expiresAt
dedupeKey
```

- 只能指向 route catalog 中标记为可恢复的 protected 目标。
- 进入登录流程前已经解析并放入内存；MobileLoginRoute 只拿 `AuthEntryContext`，页面看不到 raw URI。
- K101/K102、页面表单和 SessionBundle 均不携带 returnTo。
- 登录完成后重新校验并一次消费；失败进入 home，不把原始目标显示给用户。

## 5. 冷启动、热启动与去重

以下规则只在首个具体外链/推送目标页面完成文档与 UI Mock 并单独批准后启用；当前实现测试不包含这些场景。

| 场景 | 处理 |
|---|---|
| 冷启动收到一个合法链接 | 先缓存 typed intent，固定进入 `/auth/bootstrap`；会话复核后决定消费或登录 |
| 冷启动重复投递同一链接 | 以进程内随机盐对规范化 RouteIntent 计算摘要并 dedupe，同一窗口只保留一次 |
| 未登录期间收到第二个不同目标 | 不覆盖第一个已接受目标；可在登录后由用户再次触发 |
| 已登录前台收到合法链接 | 经守卫和权限预检后串行导航 |
| 导航执行期间重复通知 | 同 dedupeKey 只执行一次；迟到 generation 丢弃 |
| 非法或过期链接 | anonymous 回 mobile，authenticated 回 home；不展示原始 URI |

去重摘要只能在内存短期保存，不作为跨安装用户追踪标识。

## 6. 推送边界

- 推送 payload 即使来自已配置供应商也按不可信输入处理，只允许 `eventType/routeType/resourceId/issuedAt/dedupeKey` 等批准字段。
- payload 不携带会话、手机号、消息正文、支付结果或授权结论。
- 点击推送只产生 RouteIntent；目标 API 必须重新读取权威状态。
- 撤销类安全事件不是普通导航推送，交给 session/realtime 先完成撤销副作用，再由导航协调器 reset。
