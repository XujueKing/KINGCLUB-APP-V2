# 发送好友申请页状态

| 状态 | UI | 动作 |
|---|---|---|
| `editing` | 目标摘要 + 表单 | 编辑/发送/返回 |
| `validationError` | 字段错误 | 修正 |
| `submitting` | 保留表单 + 进度 | 禁止重复 |
| `sent` | 已发送结果 | 返回申请列表/用户主页 |
| `alreadyPending` | 权威等待状态 | 返回 |
| `alreadyFriends` | 已是好友 | 去发消息/返回 |
| `resultUnknown` | 结果待确认 | 查询状态 |
| `targetUnavailable` | 不可申请说明 | 返回 |
| `error` | 保留草稿 | 重试/返回 |
| `sessionInvalid` | 清除草稿 | 全局 reset |

提交成功只能由权威命令结果或随后查询确认；本地点击不能直接置为 sent。
