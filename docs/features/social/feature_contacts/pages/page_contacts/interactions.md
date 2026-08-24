# 通讯录页交互

| 触发 | 行为 |
|---|---|
| 输入搜索 | 300ms 防抖后搜索昵称/私有备注；清空恢复完整列表 |
| 下拉刷新 | 保留旧列表并 SingleFlight 刷新 |
| 触底 | 使用 nextCursor 加载，失败不清空首屏 |
| 点击联系人 | `openUserProfile(SocialTargetRef)` |
| 点击新的朋友 | `openFriendRequests`，不在本地清零角标 |
| 点击添加好友 | `openAddFriend` |
| 点击黑名单 | `openBlacklist` |
| 重复点击通讯录入口 | 回顶；已在顶部可轻量刷新 |

页面不直接打开聊天、拼接 URI 或读取系统联系人；返回时按关系版本更新对应行。
