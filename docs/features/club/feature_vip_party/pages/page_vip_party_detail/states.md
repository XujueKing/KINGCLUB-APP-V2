# VIP 组局列表/详情页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 日期、列表骨架，禁用操作 |
| `listReady` | 公开组局卡片和创建入口 |
| `listEmpty` | 无公开组局，提供换日/创建 |
| `detailViewer` | 公开摘要和允许的加入动作 |
| `detailInvited` | 显示有效邀请与接受/拒绝 |
| `detailParticipant` | 成员投影、订单/支付状态 |
| `detailHost` | 管理入口，不在本页展示危险管理按钮 |
| `joining` | 单次加入提交，禁用返回重复操作 |
| `joinResultUnknown` | 原幂等键对账 |
| `pendingPayment` | 占位到期提示与支付出口 |
| `full/locked/live/completed` | 按 allowedActions 只读或展示后续入口 |
| `inviteInvalid` | 过期/撤销/目标不匹配，安全退出私有详情 |
| `offlineCached` | 缓存只读，不可加入/创建 |
| `fatalError` | 重试/返回 |
| `sessionInvalid` | 清理 PartyRef/InviteRef/成员数据并 reset |

## 旧版复刻呈现

- `listReady` 使用旧版黑金桌卡、粉色席位格、套餐价格和二维码布局。
- `detailViewer/detailParticipant/detailHost` 均在选中桌卡下方展开洋红成员区，不跳新页面。
- `offlineCached/full/locked/live/completed` 保留桌卡和日期作为只读上下文，操作按钮替换为明确状态。
- `listEmpty` 保留日期、预定新卡座入口、规则和营业时间，不制造空白黑屏。

未知 party/membership 状态安全只读，不默认展示加入或成员名单。
