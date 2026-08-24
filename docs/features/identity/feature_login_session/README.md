# 登录、鉴权与会话

- 文档状态：Approved for Development
- 所属业务域：identity
- 第一批建议方式：手机号短信验证码
- 最后更新：2026-08-24

## 目标

使用新服务端握手和会话体系完成手机号验证码登录/注册、会话恢复、刷新、注销和风险吊销，使 Flutter 不再依赖本地 `preUserInfo` 判断登录。

## 已确认事实

- 旧登录会在验证码通过时直接查询或创建 `k_user`，返回用户资料但不创建可信会话。
- 旧验证码存储在 `g_sms`，5 分钟内取最新记录，没有在客户端可见流程中体现消费、尝试次数和重放控制。
- 新服务端已有身份表、API Key 会话表，并已在 migration 020 完成 KingClub 登录发证与 Refresh Token 消费闭环。
- `auth/session/touch|revoke|rotate` 公版能力仍保留；KingClub 使用独立登录、刷新、查询、注销和撤销其他会话 Routine。
- 物业服务端分支和 `JNGJ-WX` 已有成熟的握手、登录发证、会话恢复与 WebSocket 接入经验，KingClub 复用协议和工程经验，不复制物业业务代码或小程序平台 API。
- KingClub 同一账号在 KingClub App 内只允许一个活动设备会话。
- KingClub 调用物业统一身份时使用服务端专用凭据和超级接口 `S260824000401`，Flutter 不得直接调用。

## 已批准设计

- 客户端接口当前冻结为 `K260824000101`～`K260824000107`，页面只依赖语义化 Repository。
- 短信验证码有效期 300 秒、重发冷却 60 秒、单挑战最多失败 5 次；手机号每小时最多 5 次、IP 每小时最多 20 次，均允许部署时收紧但不得放宽后无审计。
- API Key/访问会话有效期 2 小时，Refresh Token 有效期 30 天；剩余 10 分钟进入提前刷新窗口，刷新成功后两者轮换并重新计时。
- 正常再次登录先查询 KingClub 本地手机号 HMAC 指纹投影；只有首次登录、投影缺失或版本冲突才调用物业身份权威接口。
- 协议版本由服务端已发布协议目录校验，登录请求只提交用户实际看到并同意的版本；同意记录追加写、不覆盖。正式协议文本及首个发布版本是上线门槛，不阻塞服务端骨架开发。
- 新设备不增加可枚举账号状态的登录前确认接口；验证码登录页固定提示“登录后其他 KingClub 设备将退出”，只有新登录事务成功后才撤销旧会话。

## 第一批建议范围

- ECDH 握手
- 请求短信验证码
- 验证短信并登录；首次用户创建平台身份和 KingClub 成员
- 登录成功发放 sessionId、apiKeyId、apiKey、refreshToken
- 会话恢复和失效处理
- 主动注销
- API Key 轮换/会话刷新
- 建立 WebSocket 所需凭据

## 暂不包含

- 密码登录、微信/支付宝登录、人脸登录和多账号切换，除非用户将其列为首期要求。
- 注册后的全部实名、颜值、着装和会员审核页面。

## 页面清单

四个页面均已在本功能的 `pages/` 下建立独立文档目录；文档逐页批准后才允许创建对应 Flutter 代码目录。

## 相关文档

- [登录流程](flow.md)
- [登录鉴权状态机](auth_state_machine.md)
- [数据与接口](data_and_api.md)
- [物业服务端与 JNGJ-WX 复用审计](property_and_jngj_reuse_audit.md)
- [未登录协议目录读取契约（已实现）](agreement_catalog_contract.md)
- [验收标准](acceptance.md)

首批 Flutter 页面评审稿：

- [启动鉴权页（Approved for Development）](pages/page_auth_bootstrap/README.md)
- [手机号登录页（Approved for Development）](pages/page_mobile_login/README.md)
- [验证码页（Approved for Development）](pages/page_sms_verification/README.md)
- [协议确认页（Approved for Development）](pages/page_terms_consent/README.md)

## 开发准入

- [x] 首期登录方式已确认：手机号短信验证码
- [x] 自动注册规则已确认：验证码通过后原子创建平台账号和 KingClub 成员
- [x] 协议与隐私版本规则已确认
- [x] 会话 TTL 和刷新 TTL 已确认
- [x] 多设备策略已确认：KingClub App 内单设备在线，不跨 App 互踢
- [x] 登录接口和数据事务已评审
- [x] 状态更新为 Approved for Development

## 开发批准记录

- **已确认事实**：用户已确认手机号短信登录、KingClub 单设备在线、新接口重建以及物业/JNGJ-WX 只复用成熟经验。
- **已确认事实**：统一身份和物业占位写入方案已经批准并完成本地隔离 A033 联调。
- **当前建议已采纳为 V1 默认值**：验证码、访问会话和刷新参数按“已批准设计”实现；上线前可通过环境配置收紧。
- **待上线配置**：正式用户协议、隐私政策文本及首个发布版本由运营/法务提供，不在代码中硬编码。

## 实现进度

- **已确认事实**：服务端 `business/kingclub-v2` 已完成 migration `019` 基础表、migration `020` 登录/会话执行链及 migration `021` 短信独立幂等契约。
- **已确认事实**：migration 019 建立短信供应商/路由、一次性验证码挑战、发送审计、本地手机号指纹投影、协议发布目录、同意证据和设备登记八张表，全部登记数据库目录。
- **已确认事实**：`authSession` 已分离访问与 Refresh Token 到期时间，增加轮换/重用检测字段和 KingClub 单活动会话唯一键。
- **已确认事实**：短信 Router、五个登录/会话 Routine、`K260824000101`～`K260824000107`、K 命名空间过滤、运行时紧凑契约校验和 WebSocket 撤销后关闭连接均已实现。
- **已确认事实**：服务端提交 `2638d14` 全量验证通过 35 个测试文件、128 项测试、类型检查、构建、migration dry-run 和部署静态检查；空白 MySQL 8.4 已从 migration 001 完整执行到 021。
- **已确认事实**：Routine 实际验证覆盖首次登录、刷新轮换、第二设备顶号和旧 Refresh Token 重用撤销；本地 `kingclub_v2` 已增量应用 migration 020。
- **已确认事实**：七个密文超级接口和 KingClub↔物业首次开户/本地投影完整链路已在隔离环境通过，覆盖协议目录、重放、可信字段拒绝、短信幂等、单设备会话、刷新并发、recent auth 和注销。
- **已确认事实**：并发物业首次开户只生成一个统一账号；物业不可达时 KingClub 不本地发号；物业成功而本地提交失败的原幂等键补偿已通过。
- **已确认事实**：验证码错误/过期、手机号/IP 限流、Refresh Token 宽限期外重用、真实 WebSocket 撤销事件与 `4001` 关闭，以及合成 KYC 冲突人工审核均已通过隔离密文联调。
- **已确认事实**：启动鉴权页已完成状态、错误映射、生命周期、线框、安全和验收评审，状态为 `Approved for Development`；其 Flutter 实现仍等待 Stage 1 foundation 文档批准。
- **已确认事实**：用户批准 K107；服务端 `business/kingclub-v2 / d9929ff` 已完成 migration 022、当前协议 Markdown/摘要读取、旧版本拒绝且不消耗短信 challenge 的密文 E2E 和 37 文件/133 项质量门禁。
- **已确认事实**：手机号登录页的号码规范化、协议勾选、短信幂等、限流、防账号枚举、状态和交互已完成评审，状态为 `Approved for Development`。
- **已确认事实**：用户已批准验证码页九项规则，包括 K102 结果未知时失败关闭并重新获取验证码；页面状态为 `Approved for Development`。
- **已确认事实**：用户已批准协议确认页九项规则；当前接口只允许 K107 读取目录、K102 在登录事务中记录同意，不存在独立同意写接口。
- **已确认事实**：启动鉴权、手机号登录、验证码和协议确认四个首批页面均为 `Approved for Development`。
- **当前状态**：进入 Flutter foundation 架构评审，尚未创建 Flutter 工程或任何页面代码。
