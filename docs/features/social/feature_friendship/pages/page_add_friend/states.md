# 添加好友入口页状态

| 状态 | UI | 动作 |
|---|---|---|
| `ready` | 两个固定动作 | 扫一扫/我的二维码/返回 |
| `navigationPending` | 被点击卡片显示进度 | 禁止重复点击 |
| `destinationUnavailable` | 稳定说明 | 重试/返回 |
| `sessionInvalid` | 不显示业务内容 | 全局 reset |

固定动作不得由服务端增删、重排或替换为 URL；页面不缓存二维码或相机结果。
