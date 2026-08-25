# 商品/购物车页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 桌位与目录骨架 |
| `browsing` | 分类、商品与购物车数量 |
| `cartExpanded` | 行项目编辑、清空 |
| `emptyCatalog/emptyCart` | 对应空状态 |
| `soldOut/limitReached` | 商品原位提示 |
| `catalogRefreshing` | 保留可读内容，禁用受影响提交 |
| `invalidContext/tableUnavailable/venueClosed` | 禁止加购，返回扫码/首页 |
| `offline` | 可看安全缓存但不可报价 |
| `sessionInvalid` | 清草稿敏感引用并登录 reset |

未知商品状态按不可售处理，不根据本地时间自行恢复。
