# KINGCLUB APP V2 目标架构

## 总体结构

```text
                     API Gateway / API v2
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
   微信原生小程序       Flutter iOS/Android    旧接口兼容层
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
      ┌──────────────┬────────┴───────┬──────────────┐
      │              │                │              │
   身份域        同城社交域      KingClub业务域   消息/媒体域
      │              │                │              │
 identity DB     social DB         club DB       message DB
```

## 客户端策略

### 微信小程序

- 保留原生微信小程序技术栈。
- `1.1.37` 作为稳定基线。
- 逐模块迁移到 API v2。
- 不强行复用 Flutter UI。
- 只实现微信平台允许和适合的能力。

### Flutter iOS/Android

- 新建 Flutter 工程，不把当前 JS 自动转换成 Dart。
- 复用业务流程、设计资产、接口模型和测试用例。
- 通过 Flutter Plugin/Platform Channel 接入推送、支付、后台任务、媒体、地图等原生能力。
- Android/iOS 使用同一 Flutter 主代码库，少量平台能力由 Kotlin/Swift 实现。
- 第一版只做高频业务闭环，不追求一次性复制所有管理页面。

### 不再采用的方向

- 不继续依赖小程序 multiPlatform 容器作为长期原生 App。
- 不使用 Flutter Web 代替微信小程序。
- 不在前后端和数据库同时做全量重写。

## 服务端策略

第一阶段推荐“模块化单体”，不急于拆成大量微服务：

- 一个或少量部署单元
- 按领域划分代码模块
- 每个领域拥有独立数据访问层
- 禁止模块跨边界直接操作表
- 对外统一 API v2
- 通过领域事件同步必要数据

当某个领域出现独立扩容、团队、合规或可用性需求时，再拆成独立服务。

## 建议领域

### Identity 身份域

- person
- account
- credential/session
- app_membership
- app_profile
- consent
- device

### City Social 同城社交域

- city_profile
- follow_relation
- blacklist
- friend_relation
- feed/works
- social_visibility

只有确实需要跨 App 共享的同城能力才放在这里。

### KingClub 业务域

- club_member
- store/table
- reservation/session
- ticket/admission
- order/order_detail
- goods/stored_wine
- agent/customer
- balance/withdrawal

### Messaging 消息域

- conversation
- participant
- message
- delivery/read state
- push task
- media attachment

### Payment 支付适配域

- payment_order
- payment_attempt
- refund
- provider_callback
- reconciliation

支付适配可以共享，但每个业务订单的金额和状态仍由所属业务域决定。

## API 原则

- 使用 REST/JSON 或明确约定的 RPC，不再让客户端依赖无语义 `S231...` 编号。
- 使用 OpenAPI 作为唯一接口契约。
- 自动生成 TypeScript/Dart DTO 或至少自动校验契约。
- API 版本通过 `/api/v2/...` 明确区分。
- 列表统一分页、排序和游标规则。
- 错误统一 `code/message/details/requestId`。
- 所有写操作考虑幂等键。
- 支付和订单状态只能由服务端及支付回调确认。
- WebSocket 使用登录会话换取短期连接 Ticket。

