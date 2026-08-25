# 局长组局管理页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 标题与分区骨架，管理动作禁用 |
| `recruiting` | 邀请、撤销、释放未付款占位、关闭招募 |
| `recruitmentClosed` | 可按 allowedActions 重新开启 |
| `full` | 邀请禁用，成员/订单可查看 |
| `locked` | 核心配置和成员写操作冻结 |
| `live` | 订单/入场/点单后续入口 |
| `completed` | 全部只读 |
| `cancelled` | 原因与订单处理说明只读 |
| `actionSubmitting` | 仅目标行/开关禁用，其他内容保留 |
| `versionConflict` | 重读整份管理投影并说明变化 |
| `permissionLost` | 清除成员敏感投影，返回普通详情 |
| `partialError` | 保留已加载分区并局部重试 |
| `offlineCached` | 只读，不允许管理动作 |
| `sessionInvalid` | 清理 PartyRef、成员与邀请并 reset |

未知 allowedAction 不生成按钮；未知状态只读降级。
