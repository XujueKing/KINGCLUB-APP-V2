# App Shell 页面状态

| 状态 | 可见内容 | 允许动作 | 转移 |
|---|---|---|---|
| `ready` | 当前分支 + 底部导航 | 切 Tab、扫码、分支内导航 | offline/session/membership 事件 |
| `offlineOverlay` | 当前内容保持，顶部显示离线提示 | 本地导航、重试由页面处理 | 网络恢复回 ready |
| `sessionTransition` | 阻止新的业务导航，显示短暂安全处理中状态 | 无 | 清理完成 reset 登录 |
| `membershipTransition` | 阻止新的业务导航 | 无 | reset KC-P-009 |

## 不属于 Shell 的状态

- 首页、会话、内容、我的的数据加载、空、错误和刷新。
- 扫码权限拒绝和识别失败。
- 支付中、订单提交中、聊天发送失败。

这些状态由独立页面文档负责，不能用一个全局 loading 遮住整个 App。

## 不变量

- 同一时刻只有一个主目的地为 selected。
- 扫码动作永不显示 selected，也不改变当前分支索引。
- session/membership transition 开始后，迟到的业务导航和异步结果被拒绝。
- offlineOverlay 不销毁任何分支栈。
