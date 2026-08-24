# 返回栈、生命周期与恢复

- 文档状态：`In Review`
- 范围：Android/iOS 返回行为、进程/前后台变化和导航竞态

## 1. 首批路由栈规则

| 当前页面 | 系统/手势返回 | 成功出口 |
|---|---|---|
| `/auth/bootstrap` | 禁止 pop | reset mobile 或 home 语义 |
| `/auth/mobile` | 二次确认退出 App | replace code |
| `/auth/code` | 销毁 PendingSmsLogin 与验证码，replace mobile | session 原子提交 + K104 后 reset 目标 |
| `/auth/consent` readOnly | pop 回 mobile，保留同 generation 表单 | pop，无服务端同意写入 |
| `/auth/consent` loginRecovery | 返回前确认退出；确认后销毁流程并 replace mobile | replace code，重新输入验证码 |
| `/home` 根页 | 按平台根页规范退出/后台，不回 auth flow | 后续页面文档批准后再定义出口 |

页面只发 `BackIntent`，由 application/navigation 协调器完成流程销毁和栈动作；禁止 Widget 先 pop 再异步清理敏感状态。

## 2. Predictive back 与 iOS 手势

- Android predictive back 预览的目标必须与最终 BackDecision 一致；需要确认或销毁登录流程时，页面在手势提交前拦截并展示批准的确认 UI。
- iOS 交互返回在不可返回的 bootstrap、code、loginRecovery consent 上禁用或转为同一 BackDecision，不能绕过清理。
- 返回手势取消时不销毁流程、不生成新 generation。
- 对话框、键盘和 sheet 的关闭优先级由页面文档定义，不得误当成页面返回。

## 3. 前后台与导航串行化

- `NavigationCoordinator` 同一时刻只执行一个动作；每个动作携带 navigation generation 和 session version。
- App 进入后台后可完成纯状态计算，但暂停实际导航；回前台重新校验 session、flow generation 和目标有效期。
- 页面已销毁、栈已 reset 或 session version 变化后，迟到异步结果不得 push/replace。
- K104 完成和撤销事件同时到达时，安全会话 reset 优先；被撤销后不得进入 home。

## 4. V1 状态恢复决策

- 首个移动端版本不为 `GoRouter/MaterialApp.router` 启用路由树 restoration，冷启动固定从 `/auth/bootstrap` 重建。
- auth flow、`$extra`、FlowStore 和通用 notice 永不持久化。
- 页面内部非敏感 UI 状态如滚动位置，只有对应页面文档批准后才能使用 Flutter 页面级 restoration。
- 未来启用 Router restoration 必须新增 ADR/本模块变更：逐路由 allowlist、脱敏序列化、版本迁移、注销清理和双端恢复测试缺一不可。

## 5. Router 异常

- 路由表编译/创建错误属于 app_bootstrap `routerCreationFailed`，由 BootstrapHost fatal shell 处理。
- 运行时未知 location、缺少 `$extra` 或参数解析失败由统一 exception handler 转为稳定 RouteResolution，不显示 go_router 默认错误页或异常原文。
- anonymous 安全 fallback 为 mobile；authenticated 为 home；restricted/账号不可用当前清除敏感流程后回 mobile 并显示稳定通用说明。
- 同一异常不得循环重定向；超过 redirect 预算停在上述安全根目标。
