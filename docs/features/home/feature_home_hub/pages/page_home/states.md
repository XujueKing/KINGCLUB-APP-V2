# 首页状态

| 状态 | UI | 可执行动作 | 退出条件 |
|---|---|---|---|
| `initialLoading` | 保留会员头部、三联入口和底栏位置；Banner/海报等比例骨架 | Shell 导航 | Fake 快照返回 |
| `ready` | 旧版首页完整复刻场景 | 入口、刷新、Banner/海报动作 | 刷新/失效 |
| `emptyPromotion` | 会员头部 + 三联入口，无 Banner/海报受控空态 | 入口、刷新 | Fake 运营内容恢复 |
| `partialImageError` | 单张失败占位，其他卡片保持原位 | 单图重试、其他入口 | 图片恢复 |
| `offlineCached` | 缓存 + 离线/更新时间提示 | 只读入口、重试 | 恢复网络 |
| `fatalError` | Shell 内全页错误 | 重试、切 Tab | 快照成功 |
| `refreshing` | 保留旧内容 + 顶部刷新 | 只允许单次刷新 | 成功/失败 |
| `sessionInvalid` | 不在页面内渲染业务错误 | 无 | 全局 reset |

## 不变量

- “一起玩 / 组局玩 / 扫码”顺序不会因 Fake 或未来服务端结果改变。
- 首页视觉使用旧版复刻结构，不混入 `Home Wireframe v1` 的今晚行程、2×2 入口等模块。
- 局部模块失败不清空其他成功模块。
- 旧 generation 的迟到响应不得覆盖新会话或更新快照。
- cached/stale 必须显式标注，不能冒充刚更新的权威状态。
