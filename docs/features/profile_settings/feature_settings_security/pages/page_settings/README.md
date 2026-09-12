# 设置页

- Scope ID：`KC-P-043`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[设置与账号安全](../../README.md)
- 旧版来源：`setting/setup`
- 路由：`SettingsRoute`，`/me/settings`
- 设计版本：`Mini Program Settings Menu Replica v2`
- 最后更新：2026-09-12

## 2026-09-12 当前视觉真值

用户已要求设置页切换为小程序五行菜单，具体以 [mini_program_menu_replication.md](mini_program_menu_replication.md) 为准。下方 v1 线框保留为历史设计记录，不再代表当前页面外观。

## 历史 v1 线框

```text
[返回]                设置
账号与安全
  支付安全                         >
  账号注销                         >
App 设置
  通知权限                     已关闭 >
  清理媒体缓存                  128 MB
关于
  关于与法律文档                   >
[退出登录]
```

菜单由客户端固定；服务端只返回状态，不提供路径。状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
