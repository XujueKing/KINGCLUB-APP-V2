# 设置页

- Scope ID：`KC-P-043`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[设置与账号安全](../../README.md)
- 旧版来源：`setting/setup`
- 路由：`SettingsRoute`，`/me/settings`
- 设计版本：`Settings Wireframe v1 / Hub`
- 最后更新：2026-08-25

## 线框

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
