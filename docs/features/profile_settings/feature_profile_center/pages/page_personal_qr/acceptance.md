# 个人二维码页验收

## 文档准入

- [x] 二维码不含永久账号、手机号、Authorization 或网页 URL
- [x] 10 分钟有效期、刷新替换、过期、撤销和迟到响应规则明确
- [x] 后台隐藏、页面销毁、会话失效和账号切换的清理规则明确
- [x] 保存、分享、复制载荷、永久码、离线码和群二维码已排除
- [x] 扫描可用性、读屏、倒计时播报和截图风险边界明确
- [x] 用户于 2026-08-25 批准 Profile Center Wireframe v1 / QR 与短期码策略

## UI Mock 验收

- [x] PROFILE-M13～M18 可重复演示
- [x] 除 `ready` 外所有状态均不可扫描，刷新失败不恢复旧码
- [x] App 后台显示隐私遮罩，回前台重新生成短期码
- [x] 页面、路由、缓存和错误状态不展示 token 或永久账号
- [x] 不访问真实签发、刷新或撤销接口
- [x] 正常查看与刷新路径不展示 Fake、Mock 或真实接口未接入提示；测试状态仅由长按标题进入

设备证据：[Android 个人二维码页](screenshots/android_personal_qr_v2.png)。自动化证据：`test/personal_qr_flow_test.dart` 9 项；项目全量 172 项通过，`flutter analyze` 无问题。

UI Mock 验收通过；真实二维码接口仍受项目级 `UI Flow Approved` 门禁约束。
