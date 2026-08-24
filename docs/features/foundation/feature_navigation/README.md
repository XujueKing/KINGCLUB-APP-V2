# 路由与导航

- 文档状态：`In Review`
- 优先级：P0
- 当前建议：`go_router + go_router_builder` 类型化路由

## 目标

统一处理公开、登录流程、受保护业务、深链、返回栈和会话失效。页面只能表达导航意图，不拼接 URI、不直接读取会话存储。

## 路由分区

| 分区 | 示例 | 规则 |
|---|---|---|
| bootstrap | `/auth/bootstrap` | 唯一冷启动入口，不可被深链直接打开 |
| public | 帮助、公开协议 | 无会话可访问，仍受域名/参数白名单 |
| auth flow | `/auth/mobile|code|consent` | 敏感上下文只用内存 flowId，禁止系统恢复和外部深链 |
| protected | 首页、订单、消息、个人中心 | 必须经过已复核 SessionState 守卫 |
| restricted | 申诉、退出、状态说明 | 成员受限时按明确 allowlist 开放 |

## 当前建议

- 使用生成的 RouteData，公开 path/query 参数必须是非敏感、可验证值。
- 手机号、challenge、验证码、协议快照、Token 和任意用户对象不得进入 URI；只传不可猜测、进程内有效的 flowId。
- `returnTo` 解析为内部 RouteIntent 并经过 allowlist；不接受任意 URL 或序列化页面栈。
- redirect 只读取已解析的粗粒度 SessionState，不在 redirect 回调里发网络请求或执行注销副作用。
- 会话撤销、过期或账号受限由统一导航协调器执行 replace/reset；各页面不得各写一套跳转。
- 未知路由、非法参数和被拒深链进入安全兜底页，不回显原始敏感参数。

## 返回与生命周期

- 登录流程使用受控 replace 栈，成功后不能返回验证码或协议确认页。
- Android predictive back 使用当前 Flutter/Router 支持方式统一测试；重要退出动作由页面意图确认，不依赖已弃用 API。
- 进程恢复只恢复公开或已批准的非敏感业务位置；auth flow 永不恢复。
- 推送/深链冷启动先完成 bootstrap 和会话复核，再消费一次 RouteIntent。

## 配套文档

- [验收标准](acceptance.md)
- [Foundation 索引](../README.md)
