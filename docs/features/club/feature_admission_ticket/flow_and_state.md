# 入场凭证状态与进出场流程

## 页面与凭证状态

```text
notYetAvailable -> readyToEnter -> checkedIn -> checkedOut
                          |             |           |
                          -> revoked    -> ended     -> readyToReenter | ended
```

| 状态 | 含义 | 页面动作 |
|---|---|---|
| `notYetAvailable` | 订单已确认但未到展示窗口 | 显示开放时间，不签发码 |
| `readyToEnter` | 可向工作人员出示 | 轮换动态码 |
| `checkedIn` | 已入场 | 停止展示入场码，显示入场时间/离场说明 |
| `checkedOut` | 已离场 | 按 allowedActions 显示可再次入场或已结束 |
| `readyToReenter` | 场馆允许再次入场 | 签发全新动态码 |
| `ended` | 活动时间结束 | 只读记录 |
| `revoked` | 订单取消、退款、资格或安全原因撤销 | 无二维码，进入订单/协助出口 |
| `suspended` | 风控或人工复核 | 无二维码，联系工作人员 |

## 入场

```text
App loadCredential(AdmissionRef)
 -> readyToEnter
 -> issueDisplayToken
 -> 工作人员核验端扫描
 -> verifier API 原子校验 token + staff auth + 状态
 -> checkedIn / alreadyCheckedIn / rejected
 -> App 通过前台刷新或事件提示后重读状态
```

## 离场与再次入场

```text
会员 Safe Scanner 扫场内 admissionContext
 -> AdmissionTicketRoute(AdmissionRef + ScanContextRef)
 -> 服务端验证场所、用途、过期和当前用户
 -> 页面显示“确认离场”
 -> 用户确认 + 幂等提交
 -> checkedOut
 -> 若 allowedActions 含 reenter，则需要时签发全新入场码
```

- 重复验票/离场返回同一稳定结果，不反向切换状态。
- 扫描事件、WebSocket 或推送只触发重读，不作为已入场事实。
- 核验结果未知时工作人员端和会员端均对账，不能重复切换。
- 场次取消/退款后服务端提升 `credentialVersion`，所有旧 token 立即失效。
