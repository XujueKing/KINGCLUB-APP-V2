# 局长组局管理页交互

| 触发 | 行为 |
|---|---|
| 邀请好友 | `openContactSelector(ShareIntentRef: businessCard)` 单选确认后创建 PartyInviteRef |
| 撤销邀请 | 二次确认后 expectedVersion + 幂等提交 |
| 释放未付款占位 | 展示影响与到期信息后幂等提交 |
| 点已付款成员 | 只读成员公开资料；无踢人按钮 |
| 开关招募 | 二次确认，成功后以服务端新版本替换 |
| 查看订单 | `openOrderDetail(OrderRef)` |
| 追加点单 | `openScanOrdering/Ordering` 候选意图，等待 KC-P-034 |
| 下拉刷新/恢复前台 | 重读权限、版本、成员、邀请和订单摘要 |

- 每个写动作有独立 SingleFlight；版本冲突不做本地回滚猜测，直接重读。
- 成员或邀请状态变化后，不依赖 WebSocket 单独更新权威状态；事件只触发重读。
- 失去 host 权限或切换账号立即清除成员数据和管理幂等上下文。
- 埋点记录动作类型和稳定结果类别，不记录目标昵称、账号或邀请 token。
