# 通讯录页状态

| 状态 | UI | 恢复动作 |
|---|---|---|
| `initialLoading` | 固定入口 + 列表骨架 | 等待 |
| `ready` | 分组好友、搜索、申请角标 | 刷新/分页 |
| `empty` | 无好友引导 | 添加好友 |
| `searching` | 保留 query + 结果进度 | 取消 |
| `searchEmpty` | 无匹配 | 清除 query |
| `loadingMore` | 保留列表 + 底部进度 | 等待 |
| `partialError` | 保留首屏 + 分页错误 | 重试分页 |
| `offlineCached` | 缓存 + 更新时间 | 重试 |
| `fatalError` | Shell 内错误 | 重试/切换分支 |
| `sessionInvalid` | 不显示列表 | 全局 reset |

不变量：同一 memberRefId 不重复；关系移除后不保留在正常列表；旧 generation 不得覆盖当前结果。
