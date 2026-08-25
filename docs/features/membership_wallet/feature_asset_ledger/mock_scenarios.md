# 钱包与资产流水 Mock 场景

| ID | 场景 | 预期 |
|---|---|---|
| ASSET-M01 | 三类资产均启用 | 分卡展示，不合计 |
| ASSET-M02 | 只启用余额/金币 | 隐藏钻石，不显示假 0 |
| ASSET-M03 | 全部为零 | 正常零资产状态 |
| ASSET-M04 | 摘要加载失败 | 不显示旧值为最新，可重试 |
| ASSET-M05 | 余额流水正常 | 分单位和方向显示 |
| ASSET-M06 | 金币流水正常 | 整数枚数 |
| ASSET-M07 | 钻石流水正常 | 整数枚数 |
| ASSET-M08 | 当前筛选无流水 | 独立空状态 |
| ASSET-M09 | 月份切换 | 重置 cursor 并加载 |
| ASSET-M10 | 下拉刷新 | 摘要/首屏原子更新 |
| ASSET-M11 | 下一页正常 | 稳定追加去重 |
| ASSET-M12 | 下一页重复/失败 | 不重复且可重试 |
| ASSET-M13 | pending 记录 | 明确处理中 |
| ASSET-M14 | reversed 记录 | 原记录与冲正都保留 |
| ASSET-M15 | 冻结资产 | available 与 frozen 分开 |
| ASSET-M16 | 关联订单 | 解析 OrderRef 后进详情 |
| ASSET-M17 | 普通流水展开 | 当前页展示摘要，不新建页面 |
| ASSET-M18 | 离线缓存 | 标记 asOf，只读 |
| ASSET-M19 | 未知资产/状态 | 安全通用状态 |
| ASSET-M20 | 会话失效/切换账号 | 清缓存并登录 reset |

所有场景只用 Fake AssetLedgerPort，不连接真实钱包或订单服务。
