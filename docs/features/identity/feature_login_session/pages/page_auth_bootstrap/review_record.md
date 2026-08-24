# 启动鉴权页评审记录

## 2026-08-24 首次正式评审

### 已确认事实

- 登录与会话功能已经是 `Approved for Development`；评审当时六个登录/会话密文接口及异常矩阵已通过，随后 K107 协议目录也完成隔离验收。
- 启动恢复只使用 `K260824000103` 和 `K260824000104`，页面不能直接访问 HTTP、安全存储或平台通道。
- KingClub 采用 App 内单设备在线；撤销、Token 重用和新设备登录必须清理本地状态并停止 WebSocket 重连。
- 无设计稿时允许使用明确线框作为页面开发准入材料；本页线框、组件和可访问性要求已经明确。

### 本次评审结论

- 页面目标、入口、出口、返回行为、状态、异常、接口映射、隐私、埋点、无障碍和可执行验收项完整。
- “本地凭据只表示可能可恢复”“离线不授予业务权限”“刷新后必须调用 me 复核”“导航后丢弃旧异步结果”冻结为页面不变量。
- 页面状态更新为 `Approved for Development`。

### 实现前依赖

以下是 Stage 1 foundation 的文档准入，不反向改变本页面规格；对应文档未批准前仍不得创建页面代码：

1. `app_bootstrap`：初始化顺序与依赖装配。
2. `navigation`：路由守卫、安全深链和 replace 语义。
3. `networking`：握手、密文请求、稳定错误映射与 SingleFlight。
4. `session/persistence`：原子安全存储、凭据版本和清理协议。
5. `observability`：敏感字段禁止清单与启动埋点出口。

### 后续已确认与待决策

- **已确认事实**：ADR-0001 已批准 Riverpod 3 + codegen 与 `go_router + go_router_builder`；页面仍只依赖 application 状态和导航意图，不依赖库内部类型。
- **已确认事实**：app_bootstrap 详细设计把 `/auth/bootstrap` 冻结为正式 App Root 的唯一内部初始位置，并确保 K103/K104 不阻塞 BootstrapHost 首帧。
- **待用户决策**：正式 KingClub Logo、品牌底色和启动动画资产；未提供前只允许设计系统占位 Token，不使用临时图片进入发布包。
