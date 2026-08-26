# Mock Runtime 全局场景与事件目录

## 必跑旅程

| Journey ID | 覆盖范围 | 最低结果 |
|---|---|---|
| J01 | 冷启动→登录→协议→会员准入→Shell | 成功、旧协议、验证码失败、审核中 |
| J02 | 首页→AA/VIP→订单→支付→订单详情 | 成功、库存变化、重复提交、支付未知 |
| J03 | 首页→扫码→点单→购物车→支付 | 无效码、过期码、离线、成功 |
| J04 | 消息→会话→单聊→详情/联系人 | 空、未读、乱序、撤销、会话失效 |
| J05 | 发现→作品流→用户主页→好友关系 | 加载、空、失败、拉黑与权限变化 |
| J06 | 我的→资料/二维码/钱包/设置 | 编辑失败、离线、注销流程 |
| J07 | 我的→私人储物柜→动态取件码 | 过期、后台遮盖、部分取用、重放拒绝 |

每个页面自己的 `*-Mxx` 场景仍是权威细目；Journey 只负责把页面场景串成可验收的端到端路径。

## 通用事件

| 事件 | 语义 |
|---|---|
| `network.online/offline/slow/timeout` | 改变后续请求结果，不篡改已有权威状态 |
| `session.expired/revoked/restricted` | 触发统一清理与导航 reset |
| `app.background/foreground` | 驱动隐私遮盖、恢复和权威重读 |
| `realtime.connected/disconnected/event/duplicate/outOfOrder` | 验证事件只作提示、幂等与 reconcile |
| `permission.denied/permanentlyDenied/granted/restricted` | 驱动页面权限状态 |
| `payment.pending/succeeded/failed/unknown` | 只由 Fake 支付端口改变支付投影 |
| `scanner.valid/invalid/cancelled` | 返回批准的类型化扫描结果 |

## 场景覆盖规则

- 每个 KC-P 页面至少覆盖正常、加载、空/不可用、错误、离线和会话失效中的适用状态。
- 写操作至少覆盖重复点击、迟到结果和结果未知。
- 涉及二维码/验证码/支付/取件码的页面必须使用虚拟时钟覆盖过期边界。
- 涉及 WebSocket 的页面必须覆盖断开、重复、乱序和事件后权威重读。
