# 设置页验收

- [x] 固定菜单和能力状态层级明确
- [x] 清缓存、通知权限、退出状态明确
- [x] 退出远端未知仍安全清理明确
- [x] 禁止动态路由与敏感埋点
- [x] 用户于 2026-08-25 批准 `Settings Wireframe v1 / Hub`

## UI Mock 验收

- [x] 固定菜单、通知权限、清理缓存、子页面入口和注销确认可离线演示
- [x] 能力加载失败、通知关闭、退出成功、远端退出结果未知和会话失效可重复演示
- [x] 辅助文字统一右对齐，五行箭头使用同一固定列，不随文字长度漂移
- [x] 不读取真实系统权限、不清理真实缓存、不清除真实凭证
- [x] 正常操作路径统一使用正式用户文案，不展示 Fake、Mock 或真实系统未接入提示；测试状态仅由长按标题进入

设备证据：[设置页正式验收](screenshots/android_settings_formal_v2.png)。自动化证据：`test/settings_flow_test.dart` 7 项、`test/profile_row_alignment_test.dart`；项目全量 172 项通过，`flutter analyze` 无问题。
