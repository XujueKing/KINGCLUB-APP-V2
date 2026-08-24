# 着装与音乐偏好页状态

| 状态 | UI/处理 |
|---|---|
| `loadingCatalog` | 分类骨架，不显示旧硬编码选项 |
| `ready` | enabled 选项、多选、下一步与跳过 |
| `saving` | 锁定提交，保留选择 |
| `emptyCatalog` | 稳定说明和重试；允许按服务端策略跳过 |
| `catalogStale` | 刷新后提示失效项，保留有效选择 |
| `error/offline` | 重试；不把错误当空目录 |
| `sessionLost` | 清空内存选择并 reset 登录 |

未选择任何项是合法业务值，不等同于目录加载失败。
