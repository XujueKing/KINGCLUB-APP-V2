# 单聊详情页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 设置骨架/返回 |
| `ready` | 用户入口、开关、搜索、权限、清空 |
| `updatingSetting` | 单项进度，其他写操作禁用 |
| `searchMode` | query、结果、分页、退出搜索 |
| `searchEmpty` | 清除 query |
| `confirmingClear` | 不可恢复与仅对自己影响说明 |
| `clearing` | 全页破坏性进度 |
| `versionConflict` | 重新加载权威设置 |
| `resultUnknown` | 查询 conversationVersion |
| `readOnlyRelationshipEnded` | 设置/搜索可用范围收缩 |
| `error` | 保留安全旧状态、重试 |
| `sessionInvalid` | 清空并 reset |

任何写操作使用同一 conversationVersion 串行执行；clear 成功后旧历史不得被迟到分页重新插回。
