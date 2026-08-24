# 好友备注页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 表单骨架/返回 |
| `editing` | 表单、脏状态、保存 |
| `validationError` | 字段错误并保留草稿 |
| `saving` | 保存进度、防重复 |
| `versionConflict` | 重新加载并人工确认 |
| `resultUnknown` | 查询 remarkVersion |
| `notFriends` | 关系已结束，不能保存 |
| `error` | 保留草稿、重试/返回 |
| `sessionInvalid` | 清除草稿并 reset |

私有备注、草稿和版本必须属于同一会话世代；离开进程不恢复草稿。
