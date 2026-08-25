# 设置页状态

| 状态 | UI/动作 |
|---|---|
| `loadingCapabilities/content/error` | 固定菜单，能力状态加载/失败 |
| `clearingCache` | 只清媒体缓存，禁重复 |
| `logoutConfirming/submitting/resultUnknown` | 二次确认、提交、远端未知 |
| `sessionInvalid` | 直接安全清理并 reset |

未知能力默认关闭对应写入口，不隐藏法律文档与退出入口。
