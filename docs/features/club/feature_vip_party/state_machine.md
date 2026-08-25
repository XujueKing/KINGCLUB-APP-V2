# VIP 组局状态机

## 组局状态

```text
draft -> quoting -> pendingHostPayment -> recruiting -> full -> locked -> live -> completed
                     |                    |        |
                     -> expired           -> cancelledByHost/venue
```

| 状态 | 允许动作 |
|---|---|
| `draft/quoting` | 创建者编辑草稿、刷新报价 |
| `pendingHostPayment` | 创建者继续支付；尚不可邀请 |
| `recruiting` | 浏览、加入、邀请、关闭招募 |
| `full` | 查看；不再接受加入 |
| `locked` | 临近活动，成员与核心配置冻结 |
| `live` | 查看成员/订单/入场动作，不再改招募 |
| `completed` | 只读历史 |
| `cancelledByHost/venue` | 只读原因与订单后续处理 |
| `expired` | 草稿/付款占位失效，可重新创建 |

## 成员状态

```text
invited -> acceptedPendingPayment -> confirmed -> attended -> completed
invited -> declined | invitationExpired | invitationRevoked
acceptedPendingPayment -> paymentExpired | confirmed
confirmed -> cancellationPending -> cancelled/refundPending
```

- host 始终是 confirmed 且不可通过客户端转让。
- 未接受邀请可撤销，未付款占位可释放；confirmed 成员不提供直接 remove。
- `splitPerMember` 下每个成员的报价和支付意图独立，客户端不得用总价除人数。
- `hostSponsored` 下参与者应付为 0，但仍需服务端确认加入和容量。
- 未知状态只读降级，不能默认展示加入/管理按钮。
