# App Shell 与全局信息架构

- Scope ID：`KC-F-007`
- 文档状态：`Approved for Development`
- 所属业务域：`foundation`
- M0 范围：`In Release Scope`
- 设计版本：`Legacy Shell Replica v1`
- 批准日期：2026-08-26
- UI 状态：`UI Mock Implemented`（2026-08-28，离线 Mock 已正式验收）

## 目标与用户价值

为登录并通过会员准入的普通会员提供与旧版一致的五个一级目的地和悬浮胶囊视觉。Shell 只负责主目的地、分支栈、徽标、系统返回和安全状态，不承载具体业务数据获取。

## 已确认事实

- 旧版 `pages/index/index` 使用一个超大 Swiper 同时承载首页、聊天/通讯录、内容、储物柜和我的，且 `tabData` 由服务端动态返回。
- 本期消费者 App 已冻结 48 页；员工、代理、财务和运营后台不进入 Shell。
- D1 完整群管理、D2 作品发布、D3 红包/金币转赠本期暂缓；私人储物柜纳入。
- 服务端不能动态下发任意客户端路由或改变 Tab 数量。

## 已确认方案（2026-08-26 修订）

采用五个稳定主目的地，顺序和视觉完整复刻旧版：

| 位置 | 类型 | 目标 | Scope ID | 说明 |
|---|---|---|---|---|
| 1 | 主目的地 | 首页 | KC-P-011 | AA、VIP、入场等高频到店入口 |
| 2 | 主目的地 | 消息 | KC-P-022 | 会话根页；可在同一分支进入通讯录 |
| 3 | 主目的地 | 内容 | KC-P-013 | 中央爱心图标；本期只读短视频/作品流 |
| 4 | 主目的地 | 私人储物柜 | KC-P-047 | 复刻旧版手提箱位置 |
| 5 | 主目的地 | 我的 | KC-P-040 | 资料、订单、钱包和设置入口 |

扫码不占一级导航，只从首页三联入口等批准入口打开，关闭后返回来源分支和原滚动位置。内容发布按钮本期仍不得出现；旧版内容 Tab 二次点击发布不恢复。

## 用户与准入

- 用户角色：已登录的普通 KingClub 会员。
- `membership=approved`：允许进入 Shell。
- `pending/rejected/suspended`：进入 KC-P-009 会员审核状态页，不构建业务 Shell。
- 会话未知、刷新中或本地恢复中：停留在启动鉴权流程。
- 会话撤销、过期或账号不可用：先由 session/realtime 完成清理，再 reset 到手机号登录页。

## 本期包含

- [KC-P-010 App Shell/底部导航容器](pages/page_app_shell/README.md) — `UI Mock Implemented`
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

1. 五个主目的地固定为“首页、消息、内容、私人储物柜、我的”。
2. 中央爱心是内容 Tab，不是扫码动作。
3. 私人储物柜恢复旧版一级 Tab。
4. 首发默认深色主题，浅色主题暂不进入 M1（详见设计系统）。

用户于 2026-08-26 要求完整复刻旧版底栏，以上修订覆盖 2026-08-25 的四分支加中央扫码方案。

## 开发门禁

本功能与 KC-P-010 离线 UI/Mock 已于 2026-08-28 正式验收；项目达到 `UI Flow Approved` 前不得连接真实服务。
