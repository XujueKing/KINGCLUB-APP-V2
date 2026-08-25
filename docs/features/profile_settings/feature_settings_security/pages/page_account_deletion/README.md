# 账号注销页

- Scope ID：`KC-P-045`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[设置与账号安全](../../README.md)
- 旧版来源：`del_user_account`
- 路由：`AccountDeletionRoute`，`/me/settings/delete-account`
- 设计版本：`Settings Wireframe v1 / Deletion`
- 最后更新：2026-08-25

## 线框

```text
[返回]            注销 KingClub
仅注销 KingClub；物业账号与物业数据不受影响
[影响与依法留存摘要]
[资格检查]
✓ 无未结订单
! 余额待处理                         [去钱包]
! 私人储物未取                       [去处理]
[完成短信验证并永久注销]
```

“退出登录”与“永久注销”明确区分。状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
