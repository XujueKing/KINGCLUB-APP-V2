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

## 2026-09-11 真实登录状态接入

复用本页路由展示 K102/K104 的注册状态。pending_review 显示待审核；photos_required、changes_required、rejected 显示对应进度；未知/受限状态不进首页。刷新使用当前安全会话读取 K104，approved 且账号/会员 active 才进入首页；identity_required 回实名。照片补交与审核接口尚未接通，本批不提供模拟提交；返回登录不宣称已撤销服务器会话。
