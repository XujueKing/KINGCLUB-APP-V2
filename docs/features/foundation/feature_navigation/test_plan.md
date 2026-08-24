# 路由与导航测试计划

- 文档状态：`In Review`
- 目标：证明所有入口最终只产生允许的类型化路由、正确栈和无敏感信息证据

## 1. 测试替身

- `SessionViewSource`
- `LoginFlowStore`
- `RouteCatalog`
- `NavigationExecutor`

测试围绕 RouteIntent、GuardPolicy 和 NavigationDecision，不 mock go_router 内部匹配器。adapter 层另做生成路由与真实 Router 集成测试。

## 2. 单元测试

| 编号 | 场景 | 预期 |
|---|---|---|
| NAV-U01 | 每种 SessionView × 路由分区 | 与守卫矩阵完全一致 |
| NAV-U02 | `/auth/code` 无 `$extra`、未知或旧 generation | 拒绝并 reset mobile，不构建验证码页 |
| NAV-U03 | consent 两种模式参数组合 | 只接受合法 readOnly/loginRecovery 组合 |
| NAV-U04 | 当前 route catalog 以外的 location | 拒绝并进入 mobile/home 安全根目标 |
| NAV-U05 | 登录成功 K104 通过 | reset home，不重复 push |
| NAV-U06 | restricted/revoked/expired | 按状态清理门禁进入 mobile，不建立通用 restricted 页面 |
| NAV-U07 | revoked/expired 清理未完成 | hold，不提前导航 anonymous 或 home |
| NAV-U08 | redirect 返回同 location 或超过两次 | 终止循环并进入安全 fallback |
| NAV-U09 | 导航后旧 generation 返回 | 不改变当前栈 |
| NAV-U10 | notice/诊断序列化 | 无 flowId、账号、手机号、sessionId 或服务端原文 |
| NAV-U11 | 未有页面文档却增加 route/intent | route catalog 审计失败 |

## 3. Widget/Router 集成测试

- BootstrapHost 切换后唯一初始 location 为 `/auth/bootstrap`。
- mobile→code 为 replace；code 返回执行流程销毁后建立新的 mobile 根。
- mobile→consent readOnly 使用 push/pop 并保持表单 generation。
- code→consent loginRecovery→code 使用 replace 且验证码输入清空。
- 登录成功、注销、新设备顶号、Refresh Token 重用和到期均 reset 全栈。
- 未知 location 和缺失 `$extra` 不出现 go_router 默认错误内容。
- Router diagnostics 在 prod 关闭，不打印 location extra。

## 4. 双端集成场景

| 编号 | 场景 |
|---|---|
| NAV-I01 | Android/iOS 冷启动无链接 → bootstrap → mobile/home |
| NAV-I02 | 当前未批准外部路由输入 → 不建立业务目标，安全进入 bootstrap/mobile/home |
| NAV-I03 | Android predictive back 在 mobile/code/consent/home 行为正确 |
| NAV-I04 | iOS 返回手势取消/提交不绕过登录流程清理 |
| NAV-I05 | 后台期间异步完成，回前台 session version 已变化 → 丢弃旧导航 |
| NAV-I06 | 进程被杀后 auth flow 不恢复，重新 bootstrap |

## 5. 通过标准

- NAV-U01～U11、NAV-I01～I06 全部通过。
- 生成路由代码可由 build verification 证明无过期产物；页面代码不存在字符串 location。
- URI、系统恢复数据、日志、埋点和崩溃附件扫描不含敏感流程字段。
- Android/iOS 真机返回和生命周期竞态无重复栈或 redirect loop。
