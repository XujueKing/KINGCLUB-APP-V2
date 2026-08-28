# 支付安全页验收

- [x] 未设置、已设置、锁定和错误状态明确
- [x] 修改、首次设置、忘记 PIN 与短信复核明确
- [x] 6 位规则、输入清理、幂等和结果未知明确
- [x] 不使用路由账号、手机号或旧 MD5 方案
- [x] 用户于 2026-08-25 批准 `Settings Wireframe v1 / Payment PIN`

## UI Mock 验收

- [x] SETTINGS-M07～M12、M22 可重复演示
- [x] 未设置、已设置、锁定、旧 PIN 错误与剩余次数状态明确
- [x] 弱 PIN、二次输入不一致和短信重设均停留在安全步骤
- [x] 提交结果未知时清除输入并禁止重复提交
- [x] 退后台、返回和会话失效均清理敏感输入
- [x] 不发送真实短信、不读取或修改真实支付凭据

设备证据：[Android 支付安全页](screenshots/android_payment_security_v2.png)。自动化证据：`test/payment_security_flow_test.dart` 8 项；项目全量 172 项通过，`flutter analyze` 无问题。
