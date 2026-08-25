# 设置与账号安全

- Scope ID：`KC-F-032`
- 文档状态：`Approved for Development`
- 所属业务域：`profile_settings`
- M0 范围：`In Release Scope`
- 设计版本：`Settings & Security v1`
- 最后更新：2026-08-25

## 目标与用户价值

提供固定、可预测的 App 设置入口，安全管理支付凭据、退出 KingClub、注销 KingClub 成员关系，并查看当前版本和权威法律文档。

## 已确认事实

- 旧 `setting` 接受服务端下发的 `superID/codeID/menuMyList.url` 并直接导航，可改变客户端路由和接口行为。
- 旧退出登录主要删除本地 `preUserInfo`，远端会话撤销、单设备 WebSocket 和结果未知处理不完整。
- 旧支付密码从路由读取 userAccount/mobile，提交 `MD5(mobile + password)`，客户端还会记录输入。
- 旧注销只有一次弹窗，未做重新认证、未结订单/资产/申诉/储物柜检查，也未区分 KingClub 与共享物业身份。
- 旧协议和隐私政策硬编码在 JS，已有 K107 权威协议目录可作为未来 adapter 契约。

## 当前建议

- 设置导航使用客户端固定 allowlist，服务端只能返回能力状态与提示，不能下发 URL、RouteIntent 或 interfaceId。
- 退出登录执行远端 KingClub 会话撤销；结果未知时本地仍安全清理并提示远端可能稍后完成。
- 支付安全使用独立 6 位数字 PIN；旧 MD5 凭据不迁移，首次使用需短信复核后重设。App 不存储、记录或埋点 PIN。
- KingClub 注销只注销 KingClub app membership/profile 与会话，不删除共享城市身份、物业账号或物业业务数据。
- 注销前必须权威检查未结订单、退款/申诉、余额与私人储物；通过短信重新认证和最终确认后提交。
- 关于页的版本来自构建元数据；协议、隐私政策等从权威目录按 DocumentRef 读取并显示版本/生效日期。

## 页面与文档

- [KC-P-043 设置页](pages/page_settings/README.md) — `Approved for Development`
- [KC-P-044 支付安全页](pages/page_payment_security/README.md) — `Approved for Development`
- [KC-P-045 账号注销页](pages/page_account_deletion/README.md) — `Approved for Development`
- [KC-P-046 关于与法律文档页](pages/page_about_legal/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [安全与注销规则](security_and_deletion.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 更换登录手机号、第三方账号绑定、生物识别支付、设备管理列表、营销偏好中心、数据导出和中央身份注销。
- 真实短信、支付安全、注销、推送设置、K107 或系统设置 SDK 接入。

## 已确认产品决策

1. 设置菜单完全固定，禁止服务端下发 URL 或超级接口编号。
2. V2 支付 PIN 采用 6 位数字；旧支付密码不迁移，首次使用时短信验证后重设。
3. 注销只影响 KingClub，不删除物业共享身份和物业业务数据。
4. 有未结订单、退款/申诉、可用余额或未取储物时禁止注销并给出处理入口。
5. 法律文档由权威协议目录读取，客户端不再硬编码正文。

## 开发门禁

用户批准后才可标记文档准入；全部 48 页批准前不创建 Flutter UI，全局 `UI Flow Approved` 前不接真实会话撤销、支付 PIN、注销、协议或系统设置能力。
