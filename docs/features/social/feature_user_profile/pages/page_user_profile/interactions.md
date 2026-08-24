# 用户主页交互

| 触发 | 行为 |
|---|---|
| 发送申请 | `openSendFriendRequest(targetRef)` |
| 接受/拒绝 | 携带 requestVersion 的幂等命令，结果后刷新 |
| 发消息 | `openDirectChat(targetRef)`；单聊页未批准前稳定提示 |
| 好友备注 | `openFriendRemark(targetRef)` |
| 关系权限/解除拉黑 | `openRelationshipPermissions(targetRef)` |
| 下拉刷新 | SingleFlight 重新读 profile/relationship versions |
| 返回 | 回原入口；处理结果只消费一次 |

- 动作前重新校验 allowedActions；竞态结果转为最新关系状态。
- 接受/拒绝提交中禁止重复，超时不盲目重发。
- 头像预览、复制账号、关注和内容列表均不提供。
