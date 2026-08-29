# 会员审核状态页状态

| 状态 | 主动作 |
|---|---|
| `loading` | 无，显示状态骨架 |
| `pendingReview` | 刷新状态、退出登录 |
| `changesRequired` | 补充指定资料 |
| `approved` | 仅进入 KingClub；无刷新、无退出 |
| `rejectedResubmittable` | 到期后重新申请 |
| `rejectedFinal` | 联系客服（若配置）、退出登录 |
| `suspended` | 查看说明、联系客服（若配置）、退出登录 |
| `offlineCached` | 显示上次状态与时间；不凭缓存 approved 进入 Shell |
| `error` | 重试；保留最近非敏感摘要 |
| `sessionLost` | reset 登录 |

状态图标、标题、正文和动作必须由稳定枚举映射，禁止服务端下发任意按钮路由。
