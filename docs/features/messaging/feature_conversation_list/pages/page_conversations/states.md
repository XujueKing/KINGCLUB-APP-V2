# 会话列表页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 固定切换/通知入口 + 列表骨架 |
| `ready` | 置顶与最近会话、刷新/分页 |
| `empty` | 系统通知入口 + 去通讯录 |
| `searching` | query 与结果进度 |
| `searchEmpty` | 清除搜索 |
| `loadingMore` | 保留首屏 + 底部进度 |
| `actionPending` | 单行已读/隐藏进度 |
| `partialError` | 保留可用列表 + 局部重试 |
| `offlineCached` | 缓存 + 更新时间，只读 |
| `fatalError` | 重试/切通讯录 |
| `sessionInvalid` | 清空并 reset |

## UI Mock 局部状态

| 状态 | UI/动作 |
|---|---|
| `rowUnread` | 好友行显示 `1～99+` 红色数字标记 |
| `rowRead` | 不显示未读标记，菜单动作变为“标为未读” |
| `rowActionsRevealed` | 行向左偏移并露出已读、置顶、删除操作 |
| `rowPinned` | 行进入置顶折叠区域，菜单动作变为“取消置顶” |
| `confirmDelete` | 显示不可误触的二次确认弹窗 |
| `rowRemoved` | 当前内存列表不再显示该 Fake 会话 |
| `systemUnread` | KING CLUB 行显示系统消息剩余未读数字 |
| `systemAllRead` | KING CLUB 行保留，未读数字消失 |
| `shellBadgeLinked` | 好友未读变化回传 Shell，与系统通知未读去重求和；页面切换不改变值 |
| `legacyEmpty` | 删除唯一好友 Fake 后只保留 KING CLUB 系统入口与纯黑留白 |
| `refreshPartialError` | 下拉刷新失败，原列表保持并显示窄幅离线提示与重试 |
| `refreshRecovered` | Fake 重试成功，离线提示收起，摘要和未读不变 |
| `relationshipEndedReadOnly` | 好友摘要显示关系已结束，未读为 0；点击仅展示只读说明/返回通讯录 |
| `conversationInvalid` | 摘要显示会话已失效，未读为 0；阻止进入聊天并提供本地刷新/返回通讯录 |
| `conversationRecovering` | 失效弹窗关闭，等待 450ms Fake 刷新；重复恢复被 SingleFlight 阻止 |
| `conversationRecovered` | generation 匹配时恢复正常摘要；迟到/不匹配结果静默丢弃 |

`searching/searchEmpty` 仍属于批准契约，但旧版源码已硬关闭聊天搜索入口；`Legacy Conversations Replica v1` 不显示这些状态，后续恢复必须先批准新的可见设计版本。

同一 conversationRef 只出现一次；summaryVersion、serverSequence 和 unread 不得倒退。
