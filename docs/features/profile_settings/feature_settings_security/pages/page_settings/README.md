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

## 2026-09-12 用户确认调整

按旧截图恢复黑底金字、无分隔线列表和底部实心圆角退出按钮。主菜单：个人信息、账号与支付安全、通知权限、清理缓存、隐私政策、用户协议、关于 KINGBAR。安全入口聚合现有支付安全和账号注销；不新增模拟验证能力。法律入口复用注册正文。保留统一横向页面切换，小屏列表可滚动。

关于页按旧版 about.wxml/about.wxss 还原：径向茶色背景、220rpx 标志、350rpx 字图、600rpx 正文、支持和版权备案信息；名称使用 KINGCLUB，协议复用注册本地正文，版本显示当前 App 版本。

安全中心补齐绑定手机、登录密码、账号关联、支付安全、永久注销账号。密码及关联服务当前无接口，明确显示暂未开放；不模拟成功。手机号仅展示会话中的脱敏号码，历史会话无号码显示已绑定。
