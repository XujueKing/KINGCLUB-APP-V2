# VIP 组局列表/详情页交互

| 触发 | 行为 |
|---|---|
| 选择营业日 | SingleFlight 加载该日公开组局 |
| 点组局卡 | 读取 PartyRef 权威详情并打开详情层 |
| 点创建 | `openVipPartyCreate(ServiceDayRef)` |
| 点申请加入/接受邀请 | 展示规则确认后 `createJoinIntent` |
| 需要付款 | `openPayment(PaymentIntentRef)`；未批准时走 PARTY-M22 |
| 0 元加入 | 重读详情，确认 membership=confirmed 后展示成功 |
| 点局长管理 | `openVipPartyManagement(PartyRef)` |
| 关闭详情/返回 | 先关闭详情并保留列表位置，再退出页面 |

- 加入连点、超时和前后台切换保持同一幂等键。
- 分享/邀请不使用系统任意链接；仅局长在管理页生成受控 PartyInviteRef。
- 列表不展示精确成员构成，不按热度制造虚假“即将满员”。
- 埋点只记录匿名 partyRef、入口、viewerRole 和结果类别。
