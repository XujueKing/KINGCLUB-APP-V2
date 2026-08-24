# 用户主页状态

| 状态 | 主要 UI/动作 |
|---|---|
| `initialLoading` | 资料骨架，无关系动作 |
| `stranger` | 公开资料 + 发送好友申请 |
| `incomingPending` | 验证消息 + 接受/拒绝 |
| `outgoingPending` | 等待确认，只读 |
| `friend` | 发消息 + 备注/关系权限 |
| `blockedByMe` | 有限资料 + 解除入口 |
| `selfRedirect` | 不渲染他人页，转我的主页 |
| `offlineCached` | 缓存资料，只读 |
| `targetUnavailable` | 通用不可用说明 |
| `actionPending` | 保留资料 + 单动作进度 |
| `resultUnknown` | 查询权威关系状态 |
| `fatalError` | 重试/返回 |
| `sessionInvalid` | 清空资料并 reset |

动作与关系状态必须来自同一版本；关系变化时整组动作原子替换，不能留下旧按钮。
