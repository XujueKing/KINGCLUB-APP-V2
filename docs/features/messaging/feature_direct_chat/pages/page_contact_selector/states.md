# 联系人选择页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 搜索 + 列表骨架 |
| `ready` | 可选好友列表 |
| `empty` | 无可发送好友，去通讯录 |
| `searching` | query + 进度 |
| `searchEmpty` | 清除搜索 |
| `confirming` | 单一目标 + 清洗预览 |
| `sending` | 防重复进度 |
| `sent` | 成功后返回来源 |
| `intentExpired` | 分享内容已失效，返回 |
| `targetUnavailable` | 好友/权限已变化，重新选择 |
| `resultUnknown` | 查询 clientMessageId 结果 |
| `error` | 保留选择、重试/取消 |
| `sessionInvalid` | 清空并 reset |

目标和 ShareIntentRef 必须属于同一 generation；发送中不能更换目标。
