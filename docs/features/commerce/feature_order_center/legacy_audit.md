# 消费者订单旧版审计

- 文档状态：`Approved for Development`
- 审计基线：`KingClub-app / master / 505d222 / 1.1.37`

| 旧来源 | 发现 | V2 处理 |
|---|---|---|
| `order` / `detail-order` | 多种订单语义和状态分散 | 统一消费者状态族与详情模型 |
| `order-manage` | 局长、邀请、踢人、支付混在订单页 | 局长管理留 KC-P-032；消费者中心不混角色 |
| `shoping3` | 通过 URL 接收订单 JSON | 仅接收 OrderRef 并权威重读 |
| 多个页面 | 账号、金额、tableId 等来自参数 | 会话确定用户，引用确定对象 |
| 客户端判断 | 根据类型码/状态码决定动作 | 服务端返回 allowedActions |

不复用旧状态编号作为 Flutter 页面逻辑；其映射只存在于未来 adapter/服务端。
