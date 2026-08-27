# VIP 组局列表/详情页交互

| 触发 | 行为 |
|---|---|
| 选择营业日 | SingleFlight 加载该日公开组局 |
| 点组局卡 | 读取 PartyRef 权威详情并在卡片原位展开旧版粉色详情区；再次点击收起 |
| 点创建 | `openVipPartyCreate(ServiceDayRef)` |
| 点申请加入/接受邀请 | 展示规则确认后 `createJoinIntent` |
| 需要付款 | `openPayment(PaymentIntentRef)`；未批准时走 PARTY-M22 |
| 0 元加入 | 重读详情，确认 membership=confirmed 后展示成功 |
| 点局长管理 | `openVipPartyManagement(PartyRef)` |
| 关闭详情/返回 | 点击卡片收起并保留列表位置；系统返回直接退出组局页，不生成额外详情路由 |
| 点 host 空席“邀请” | 仅生成单人 Fake 邀请结果，不打开系统任意分享 |
| 点 viewer“申请加入” | 先显示规则确认；成员各付生成 Fake 待支付意图，局长请客更新本地 Fake 席位 |
| 点二维码 | 已确认成员/host 才能进入后续入场凭证意图；viewer 保持不可用 |

- 加入连点、超时和前后台切换保持同一幂等键。
- 分享/邀请不使用系统任意链接；仅局长在管理页生成受控 PartyInviteRef。
- 列表不展示精确成员构成，不按热度制造虚假“即将满员”。
- 埋点只记录匿名 partyRef、入口、viewerRole 和结果类别。
- 长按“VIP组局”标题打开隐藏 Fake 状态面板；不在正式页面增加常驻测试入口。
