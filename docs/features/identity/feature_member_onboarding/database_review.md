# 注册准入数据库审查

- Feature：KC-F-010 / KC-F-011
- 状态：**Model In Review**
- 来源：旧小程序、旧 Java、混合 SQL 的 `s_interface` 酒吧分类与 `k_` 表结构；CCSOP `business/kingclub-v2` 当前源码
- 边界：本文件是迁移和新模型审查，不是可执行 DDL，不授权真实数据导入或生产调用。
- 基线判断：用户确认旧数据库和业务逻辑正确；下文“风险/增强”只描述迁移、安全和可维护性关注点，不代表已发现旧业务故障。

## 0. 已确认的旧事务保障

用户指出旧注册不会因单条写入失败留下半套资产；结构 SQL 复核支持这一点：

- `K_Register_SmsVerify` 在新用户 `k_user + k_wallet` 创建分支使用 `START TRANSACTION`，以 `CONTINUE HANDLER FOR SQLEXCEPTION` 设置错误标志，并在结尾 `ROLLBACK/COMMIT`。
- `K_Register_SaveImage` 对审核图片写入使用同样的异常处理、事务和回滚。
- `K_Register_SetStyles` 将偏好、准入状态、审核图片状态以及金币/经验奖励放在同一事务中，异常时回滚。
- `K_RegisterFirst` 也包含事务、异常处理和回滚；应继续按实际分支核对其边界，不能笼统写成旧系统没有事务。

因此本审查**不认定旧系统存在“注册失败留下半套资产”的已知故障**。新版拆分身份、媒体、评分、会员和资产域时，必须保留旧流程已经具备的原子业务语义；采用短事务、Outbox 和幂等消费者，是在跨服务边界重建等价或更强保障，不是修复一个未经证实的旧事务缺失。

## 1. 旧入口与依赖

| 旧入口 | 分类 | 直接/候选 `k_` 依赖 | 新版处置 |
|---|---|---|---|
| `S231202502210646 / K_RegisterFirst` | 服务器端使用 | `k_user`、`k_wallet`、`k_balance_details` | 旧过程已有事务/回滚；新版若拆分会员建档与钱包开户，必须保持幂等和业务一致性 |
| `S231202502210647 / K_Register_GetStyles` | App | `k_user`、`k_user_examine_type` | 偏好目录移出准入硬前置，可入会后读取 |
| `S231202502210648 / K_Register_SetStyles` | App | `k_user`、`k_user_examine_images`、`k_user_relation`、`k_bill_detail`、`k_exp_detail`、`k_goldcoin_detail`、`k_system_messages` | 旧过程以事务/回滚保护组合写入；新版可拆分职责，但不得降低原子性或产生重复奖励 |
| `S231202502210649 / K_Register_SaveImage` | 服务器端使用 | `k_user`、`k_user_examine_images` | 重建按申请/槽位/版本归属的私有媒体和检测证据 |
| `S231202502210650 / K_Register_SmsVerify` | App | `k_user`、`k_user_relation`、`k_wallet`、`k_balance_details`；公共 `g_sms/id_config` | 旧新用户+钱包创建已有事务/回滚；新版使用 CCSOP K101～K107 登录底座，并保持等价一致性，不迁旧验证码 |
| `S231202502210651 / K_Login` | App | `k_user`；公共 `g_sms` | 使用受控短信挑战、会话快照和当前会员状态 |
| Java `/registrationPhotoUpload`、`/isUnderageApi`、`/imageScoreApi` | 专用 HTTP，未完全由 `s_interface` 表达 | `k_user`、`k_user_examine_images`，腾讯照片实名/人脸属性 | 重建上传、供应商 adapter、评分任务和状态查询；Flutter 不持有腾讯密钥 |

以上依赖来自结构快照的词法递归和源码核查；当前线上部署版本、动态 SQL、触发器执行情况仍需在隔离联调前对齐。

## 2. 表级审查与现代化方向

| 旧表 | 已有业务职责 / 现代化关注点 | CCSOP 目标方向 | 本切片是否迁移 |
|---|---|---|---|
| `k_user` | 41 字段混合账号、实名、会员、颜值、偏好、设备和资料；`userStatus/isAuth/facialAuthenticationStatus` 语义耦合 | 复用现有 `userAccount`、`kingclubMember`、登录身份投影；新增独立申请/核验状态，状态不可互相代替 | 仅批准字段映射后迁必要身份与会员事实 |
| `k_user_examine_images` | 图片 URL、类型、Beauty/Age/Gender、腾讯 requestId 混在一表；缺申请版本与证据用途 | 拆为私有媒体引用、申请照片槽位、供应商检测证据；原图与最小审计证据采用不同保留期 | 迁移仍有效审核证据；原件范围待隐私决策 |
| `k_user_examine_type` | 偏好/审核类型目录，与准入流程耦合 | 作为版本化偏好目录或配置迁移，不能控制实名是否通过 | 不阻断首个真实准入闭环 |
| `k_user_relation` | 邀请与代理关系，同时被注册奖励使用 | 独立邀请/代理域，以幂等事件在入会后处理 | 不在实名/评分事务内写入 |
| `k_wallet`、`k_balance_details` | 旧注册过程在事务中创建/检查钱包；SQL 异常会回滚 | 新版若改为独立资产域，开户命令使用唯一业务键并可重试 | 首个准入 adapter 不直接写；后续必须证明不弱于旧事务语义 |
| `k_bill_detail`、`k_exp_detail`、`k_goldcoin_detail` | `K_Register_SetStyles` 在同一事务内执行注册奖励；失败会回滚 | 若改为入会批准事件驱动，必须用 Outbox 和幂等业务键保证最终一致且不重复 | 首版准入不自动发放，规则批准后另审 |
| `k_system_messages` | 注册/奖励通知副作用 | Outbox 后异步生成可审计通知 | 不参与核身事务提交 |

公共 `g_sms` 只作为旧短信依赖证据，不属于 KING CLUB 业务表迁移范围；新系统只保留必要的挑战、审计与指纹，不迁历史验证码。

## 3. CCSOP 已有对象与缺口

### 已有且可复用

- `userAccount`：统一 U 账号、账号状态与 `kycStatus` 投影。
- `kingclubMember`：KingClub 会员投影和 `memberStatus`；现有枚举不足以表达申请待审/补件全过程。
- `identityProvisioningAttempt`：跨身份权威投影的幂等与补偿记录，不保存姓名/证件/手机号原文。
- `smsProvider`、`smsSceneRoute`、`smsVerificationChallenge`、`smsSendAudit`：短信路由、挑战与审计。
- `kingclubLoginIdentityProjection`、`kingclubConsentRecord`、`kingclubDeviceRegistration`：登录身份、协议和设备状态。
- `kingclub_complete_mobile_login` 等 K101～K107 对应登录/会话 Routine 与超级接口目录。

### 尚缺，后续 migration 需评审后创建

- 注册申请：申请编号、账号、当前步骤、申请版本、准入策略版本和并发版本。
- 申请照片：`selfie/portrait/outfit` 槽位、私有媒体引用、摘要、尺寸、用途、过期与消费状态。
- 照片实名尝试：供应商、接口版本、请求幂等键、结果状态、最小证据、RequestId、结果未知查询状态；不保存完整供应商响应。
- 形象评估尝试：每张图质量/评分结果、模型版本及费用去重；实名相似度与 Beauty 分开。
- 会员准入决定：自动通过、人工审核、需重传、拒绝，记录策略版本和所依据的照片版本。
- 人工审核记录：角色、原因码、备注敏感等级、前后状态、审计时间；页面测试开关不得存在于生产入口。

对象名称、字段、索引、保留期和 K 编号尚未批准，不在本文件预先占号。创建时必须用递增 migration，并同步 `databaseCatalogTable`、Routine、`interface/interface_type`、项目数据库/接口文档及测试。

## 4. 事务与状态边界

1. 短信登录只建立可信 Session；不代表实名、评分或会员准入成功。
2. 上传在数据库短事务外完成；照片 token 必须绑定 actor、申请、槽位、版本、摘要、过期和消费状态。
3. 腾讯调用不得放在数据库长事务内。以任务/attempt 幂等键防止刷新、超时重试或双击重复收费。
4. 自拍实名通过后才能提交两张形象照评分；低分、无脸/模糊、实名不符和供应商结果未知分别建模。
5. 每次重传递增照片/申请版本；旧腾讯响应或旧人工审核不得覆盖新版本。
6. 最终准入决定在同一短事务中写入申请决定和会员投影，并发版本冲突必须失败重试。
7. 钱包、奖励、邀请关系和通知由“会员获批”Outbox 事件分别消费；失败不能回滚实名证据，也不能重复发放。
8. App 刷新只读取服务端快照；不触发重新评分，不凭本地缓存改为 approved。

## 5. 迁移、对账与回滚

- 迁移输入只允许已批准的 `k_` 表/字段和显式公共依赖映射；不执行旧 DEFINER、GRANT、事件或触发器。
- `k_user` 按旧账号映射到统一 U 账号，不凭手机号相同静默合并；冲突进入隔离清单。
- `userStatus/isAuth/facialAuthenticationStatus` 必须通过已核对的枚举与证据组合映射，不把任意非零值统一转为 verified/approved。
- `k_user_examine_images` 按账号、图片类型、有效性、时间和可访问对象核对；重复、缺图、无 requestId、未知类型和跨账号对象单列。
- 对账至少包含：账号输入/成功/排除/隔离数量；各状态数量；每账号有效照片槽位；会员状态与可信核验证据引用完整性。
- 演练不得调用腾讯、短信、奖励或通知；所有外部副作用使用禁用 adapter。回滚只撤新库导入批次/投影，不修改旧库历史。

## 6. 当前未完成项

- 取得与当前线上小程序匹配的旧服务提交、最终 SQL 增量和现库只读结构快照。
- 冻结新颜值阈值/聚合、重传次数与冷却、人工审核角色、两图同人校验及证据保留期。
- 完成目标字段级映射、索引/唯一约束、错误码和接口 DTO 评审。
- 模块 UI 获得 `Module UI Accepted`。
- 确认腾讯账号 V2 权限、隔离凭据、受控样片和测试费用后，方可进入 `Approved for Isolated Integration`。

## 2026-09-11 已实施的登录分流增量

根据用户本轮继续开发真实登录分流的要求，只新增 kingclubMember.registrationStatus（migration 024），区分手机号建档与注册审核完成。旧 regist.js 的 userStatus=2 首页、=1 待审、其余实名保持不变。K102/K104 扩展 membership 返回；无新表/Routine/接口，也不改变原登录或钱包事务。测试库无旧会员导入/真实批准证据，现有及新增行默认 identity_required，不按 active/isNewMembership 自动批准。字段、目录、对账、保留与回滚审查见 CCSOP 项目 `04-数据库与数据治理/注册准入状态.md`。该增量不代表照片实名/评分/审批已接通。
