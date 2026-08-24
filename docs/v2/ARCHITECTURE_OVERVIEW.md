# Flutter V2 总体架构

## 1. 架构目标

- 支持 Android 与 iOS 共用主要业务代码。
- 保持业务域边界清晰，避免再次形成超大页面和全局状态耦合。
- 允许旧 API 与 API v2 在迁移期并存，但隔离旧接口模型。
- 支持登录、聊天、支付、推送、媒体等高风险能力独立测试和替换。
- 每个功能可以小步交付、灰度、回滚和独立验收。

## 2. 系统边界

```text
Flutter iOS / Android
        |
        +-- API v2 -------------------- 目标业务接口
        +-- Legacy API Adapter -------- 迁移期旧接口适配层
        +-- WebSocket Gateway --------- 会话与实时消息
        +-- Native Integrations ------- 支付、推送、相机、相册、地图
        +-- Local Store --------------- 会话、缓存、草稿、离线状态
```

- **已确认事实**：旧版业务包含账号、社交、聊天、内容、门店、订单、支付、会员和代理能力。
- **当前建议**：客户端只依赖语义化 Repository，不允许页面直接调用旧 `interfaceId`。
- **当前建议**：旧接口统一封装在反腐层中，API v2 稳定后逐项删除适配。
- **待用户决策**：API v2 首批可用范围、旧 API 维护期限、WebSocket 升级计划。

## 3. Flutter 代码组织

```text
lib/
  app/                         应用启动、路由入口、全局装配
  core/                        网络、存储、日志、安全、错误等基础能力
  shared/                      设计系统、通用组件、跨域基础模型
  features/
    <domain>/
      <feature>/               每个功能一个独立目录
        data/                  DTO、数据源、Repository 实现
        domain/                实体、值对象、Repository 接口
        application/           用例、状态协调、业务编排
        presentation/
          pages/
            <page>/            每个页面一个独立目录
          widgets/             仅属于该功能的组件
        tests/
```

依赖方向：

```text
presentation -> application -> domain
data ------------------------> domain
core/shared 不得反向依赖具体 feature
```

- **当前建议**：业务代码采用 feature-first，功能内部再按层组织。
- **当前建议**：跨功能复用必须经过明确评审；不要因两个页面长得相似就提前抽象。
- **当前建议**：页面不得直接读写 HTTP、数据库、SharedPreferences 或平台通道。

## 4. 核心基础模块

| 模块 | 责任 | 当前状态 |
|---|---|---|
| app_bootstrap | 环境配置、启动顺序、依赖装配 | 当前建议 |
| navigation | 路由、登录守卫、深链 | 已确认 `go_router + go_router_builder` |
| design_system | 颜色、排版、间距、组件、主题 | 待设计输入 |
| networking | HTTP、鉴权、重试、错误映射、requestId | 当前建议 |
| session | 登录态、刷新、退出、设备会话 | 依赖 API v2 |
| persistence | 安全存储、缓存、草稿、迁移 | 当前建议 |
| realtime | WebSocket 生命周期、重连、消息分发 | 依赖服务端方案 |
| observability | 日志、崩溃、性能、业务埋点 | 已确认供应商中立端口；具体平台后定 |
| native_bridge | 支付、推送、媒体、地图、权限 | 待供应商确认 |

## 5. 状态、路由和依赖注入

- **已确认事实**：Riverpod 3 + codegen 是唯一状态管理和依赖装配方案，禁止多套状态框架并存。
- **已确认事实**：采用 `go_router + go_router_builder` 类型化路由，必须支持登录守卫、深链和页面级埋点。
- **当前建议**：依赖在应用装配层注册，页面不得自行创建 Repository。

## 6. 数据与接口策略

- API v2 使用 OpenAPI 作为契约来源。
- DTO、领域模型、页面 ViewModel 分离，避免服务端字段直接渗透 UI。
- 列表统一分页、空态、错误态和刷新规则。
- 所有写操作定义幂等策略；订单和支付结果必须以服务端为准。
- 敏感凭据使用系统安全存储，日志禁止输出令牌、手机号、聊天内容和支付响应全文。
- 旧接口返回值先转换为领域模型，页面不感知 `interfaceId` 和旧字段命名。

## 7. 测试策略

| 层级 | 最低要求 |
|---|---|
| domain/application | 核心规则和状态转换单元测试 |
| data | DTO 解析、错误映射、Repository 契约测试 |
| presentation | 关键状态 Widget 测试和可访问性检查 |
| integration | 登录、聊天、下单、支付等主链路测试 |
| release | Android/iOS 真机冒烟、崩溃与性能门槛 |

## 8. 安全与高风险边界

- 客户端不决定订单金额、会员权益、余额或支付成功状态。
- 用户身份来自服务端会话，不信任页面参数中的账号字段。
- 聊天重连必须保证单连接、单心跳、可观察和幂等处理。
- 支付、退款、提现、删除账号、黑名单等功能必须独立做威胁与异常流程设计。
- 生产、测试环境完全隔离，不把密钥提交到仓库。

## 9. 尚待确认的架构决策

1. ~~Flutter 最低版本及 Android/iOS 最低系统版本。~~ 已由 ADR-0001 确认为 Flutter 3.47.1、Android API 24、iOS 15。
2. 序列化和本地数据库选型；状态管理、路由、网络与安全存储已由 ADR-0001 确认。
3. 设计系统来源、品牌规范以及暗色模式需求。
4. API v2、聊天、推送、支付和地图供应商的现状。
5. 多环境、CI/CD、应用签名和发布渠道。
6. 是否需要离线阅读、弱网队列或多账号能力。

第一批技术选择见已批准的 [ADR-0001](adr/0001_flutter_foundation_baseline.md)；五个 foundation 模块批准前不创建 Flutter 工程。
