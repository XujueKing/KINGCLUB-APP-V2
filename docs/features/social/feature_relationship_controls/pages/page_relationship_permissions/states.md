# 关系权限页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 设置骨架/返回 |
| `readyFriend` | 权限开关、拉黑、删除 |
| `readyBlocked` | 有限说明、解除拉黑 |
| `updating` | 保留设置 + 单项进度 |
| `confirmingBlock` | 影响说明 + 确认/取消 |
| `confirmingDelete` | 影响说明 + 确认/取消 |
| `confirmingUnblock` | 不恢复好友说明 |
| `versionConflict` | 重新读取权威状态 |
| `resultUnknown` | 查询关系版本 |
| `targetUnavailable` | 通用不可用 |
| `error` | 保留安全旧状态、重试 |
| `sessionInvalid` | 清空并 reset |

更新中不允许第二个关系命令并发；破坏性结果后旧开关不可继续操作。
