# App Shell 与全局信息架构

- Scope ID：`KC-F-007`
- 文档状态：`Approved for Development`
- 所属业务域：`foundation`
- M0 范围：`In Release Scope`
- 设计版本：`Shell IA v1`
- 批准日期：2026-08-25

## 目标与用户价值

为登录并通过会员准入的普通会员提供稳定、可预测的 App 一级结构。Shell 只负责主目的地、分支栈、全局扫码、徽标、系统返回和安全状态，不承载任何具体业务数据获取。

## 已确认事实

- 旧版 `pages/index/index` 使用一个超大 Swiper 同时承载首页、聊天/通讯录、内容、储物柜和我的，且 `tabData` 由服务端动态返回。
- 本期消费者 App 已冻结 48 页；员工、代理、财务和运营后台不进入 Shell。
- D1 完整群管理、D2 作品发布、D3 红包/金币转赠本期暂缓；私人储物柜纳入。
- 服务端不能动态下发任意客户端路由或改变 Tab 数量。

## 已确认方案

采用四个稳定主目的地和一个中央动作：

| 位置 | 类型 | 目标 | Scope ID | 说明 |
|---|---|---|---|---|
| 1 | 主目的地 | 首页 | KC-P-011 | AA、VIP、入场等高频到店入口 |
| 2 | 主目的地 | 消息 | KC-P-022 | 会话根页；可在同一分支进入通讯录 |
| 3 | 中央动作 | 扫码 | KC-P-012 | 打开安全扫码页，不建立第五个分支 |
| 4 | 主目的地 | 发现 | KC-P-013 | 本期只读短视频/作品流 |
| 5 | 主目的地 | 我的 | KC-P-040 | 资料、订单、钱包、储物柜和设置入口 |

中央扫码关闭后返回原分支和原滚动位置。私人储物柜不再占用一级 Tab；内容发布按钮不得出现在发现页或中央动作中。

## 用户与准入

- 用户角色：已登录的普通 KingClub 会员。
- `membership=approved`：允许进入 Shell。
- `pending/rejected/suspended`：进入 KC-P-009 会员审核状态页，不构建业务 Shell。
- 会话未知、刷新中或本地恢复中：停留在启动鉴权流程。
- 会话撤销、过期或账号不可用：先由 session/realtime 完成清理，再 reset 到手机号登录页。

## 本期包含

- [KC-P-010 App Shell/底部导航容器](pages/page_app_shell/README.md) — `Approved for Development`
- [信息架构与入口归属](information_architecture.md)
- [分支栈、返回与生命周期](navigation_and_back.md)
- [Mock/Fake 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 由服务端动态创建、隐藏或重排一级导航。
- 群聊、发布、红包、金币转赠和角色后台入口。
- 任意业务数据请求、会话刷新、WebSocket 连接或推送 SDK 初始化。
- 平板专用多栏导航；首发仅要求手机尺寸可靠适配。

## 依赖与边界

- 依赖 KC-F-001 app_bootstrap、KC-F-002 navigation、KC-F-003 design_system 和粗粒度 SessionView。
- Shell 只消费稳定的徽标数量、网络状态和导航意图；不得直接依赖 Dio、WebSocket、数据库或业务 Repository。
- 每个业务分支拥有自己的页面栈和页面状态；Shell 不保存业务 DTO。
- UI Mock 阶段由 FakeShellState/FakeBadgeSource/FakeSessionView 驱动。

## 已确认决策

1. 四个主目的地固定为“首页、消息、发现、我的”。
2. 扫码采用底部中央动作，不作为可保活的 Tab。
3. 私人储物柜从“我的”进入，不保留旧版一级 Tab。
4. 首发默认深色主题，浅色主题暂不进入 M1（详见设计系统）。

## 开发门禁

本功能与 KC-P-010 已达到文档准入；仍须等待本期 48 页全部文档批准后才能创建 Flutter UI，项目达到 `UI Flow Approved` 前不得连接真实服务。
