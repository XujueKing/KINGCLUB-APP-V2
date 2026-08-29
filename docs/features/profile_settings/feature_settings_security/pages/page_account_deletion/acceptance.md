# 账号注销页验收

- [x] KingClub 与物业共享身份边界明确
- [x] blocker、影响、留存与处理入口明确
- [x] 短信重新认证、最终确认、幂等与对账明确
- [x] 成功后的会话/本地清理明确
- [x] 用户于 2026-08-25 批准 `Settings Wireframe v1 / Deletion`

## UI Mock 验收

- [x] SETTINGS-M13～M18、M22 可重复演示
- [x] 未结订单、资产/退款和私人储物 blocker 阻止提交并提供受控 Fake 意图
- [x] 短信过期、资格变化、最终短语确认和结果未知状态明确
- [x] 结果未知不声称成功，成功后才触发安全退出回调
- [x] 明确仅注销 KingClub，物业账号、物业数据和共享身份不受影响
- [x] 不注销真实账号、不发送真实短信、不清理真实会话
- [x] 正常注销流程使用正式风险、验证和结果文案，不展示测试验证码、Fake、Mock 或真实账号未变化提示

设备证据：[首屏](screenshots/android_account_deletion_v2.png)、[底部操作区](screenshots/android_account_deletion_bottom_v2.png)。自动化证据：`test/account_deletion_flow_test.dart` 7 项；项目全量 172 项通过，`flutter analyze` 无问题。
