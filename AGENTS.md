# KINGCLUB APP V2 Agent Instructions

## 2026-09-10 晚间真实短信已部署（最新，覆盖下方历史冲突）

- 接续先读 `docs/migration/SESSION_RECOVERY_2026-09-10.md`。已对照两份导出聊天、App `b35c33e` 与后端 `390632b` 恢复进度。
- 用户已明确授权真实短信登录、新 `kingclubMember` 表及直接部署 IDC 测试服务器，不再额外搭隔离测试环境，也不再要求短信接入重复通过 Module UI Accepted。
- 真实短信登录、安卓安装、旧版短信正文恢复已完成；当前测试入口 `https://test.wuyexin.cn/kingclub-v2`。`api.sh-kingclub.cn` 备案处理中，不重复部署、改短信或办理备案。
- 照片实名、两图评分与审核真实接入仍未完成；真实会话目前仅保存，新会员仍接 Mock 注册流程，应先补真实状态衔接。保留腾讯照片实名认证，不接新增 App 活体 SDK。
- 小改动做必要定向验证，不反复全量测试/打包。后端既有 `.gitignore` 修改须保留。其他模块全局验收、真实数据迁移与生产切换没有因短信部署自动批准。

## 2026-09-10 注册首功能与腾讯照片实名澄清（最新，覆盖下方冲突口径）

- 用户确认首版保留旧版“姓名＋身份证号＋拍照上传→后台调用腾讯照片实名认证”，仅不接新增 App 活体核身 SDK。先前将旧照片方式理解为“不接权威库”的解释已纠正，不再据此删除实名步骤。
- 用户要求先开发注册/登录、核身自拍、两张形象照片评分、达标进入、低分等待审核或重传、通过后刷新进入。见台账 RQ-23～27，累计 27 条；第三方核查见 `docs/features/identity/feature_member_onboarding/2026-09-10-tencent-adapter-review.md`。
- 用户确认每个功能的数据库表都要逐功能审查。接真实接口或建立 migration 前，必须从 `s_interface` 分类/旧调用链追到直接和间接 `k_` 表、公共依赖、副作用、字段语义，再完成 CCSOP 目标模型、事务、迁移、对账和回滚审查；标准见 `FEATURE_DATA_REVIEW_GATE.md`，首功能见 `feature_member_onboarding/database_review.md`。
- 用户纠正：旧注册相关存储过程已有事务、异常处理和回滚，不能声称旧系统会因注册失败留下半套资产。新版重构须保留或增强既有原子业务语义；跨服务拆分用短事务、Outbox、幂等和补偿，不得以牺牲一致性换解耦。
- 用户确认旧数据库与业务逻辑没有问题，是新系统的正确业务基线；允许现代化手工形成的表结构、代码组织和架构，但不得擅改业务结果。继续使用 MySQL 8.4，存储过程不因形式旧而删除；每功能以旧行为对照测试和迁移对账证明等价，原则见 `DATA_MODERNIZATION_PRINCIPLES.md`。
- 用户已批准注册登录模块独立 UI 验收后接隔离测试环境。该例外仅覆盖 KC-F-010/011 及必要直接依赖；当前模块尚未 UI 验收，不是全局 UI Flow Approved，更不是生产批准。唯一状态源仍为 `docs/v2/APP_SCOPE_AND_UI_DELIVERY_GATE.md`。
- 旧后台实际调用 ImageRecognition 和 DetectFaceAttributes；新 CCSOP 当前只有 MockIdentityAdapter。建议重建服务端适配器而非复制旧 Java 大方法，不得拿 Mock 的固定 verified=true 放行真实用户。
- 腾讯旧照片实名 API 已停止新接入；优先评估 ImageRecognitionV2，账号权限/费用未核验，不自动双调用或失败降级。旧 SQL 男 80 / 女 85 且聚合所有审核图是来源证据，不是已批准的新生产阈值。实名相似度、颜值与会员资格分开。
- 注册 UI/Mock 第一版已实现共享申请快照：核身失败可恢复、自拍/两图分槽位、评分分流、低分待审/重传、刷新复核、通过后进入；相关自动化已加入。模块用户 UI 验收、正式 adapter、数据库迁移和真实联调仍未完成，不把 Mock 测试通过记为真实服务完成。

## 2026-09-10 碎片需求与首版照片方案（历史记录）

以下为此前记录；与上方腾讯照片实名澄清冲突的首版“不接权威库”口径已被覆盖。

- 用户要求持续记录/整理碎片需求。先读 `docs/product/2026-09-09-native-product-review/REQUIREMENT_INBOX.md`；本批 22 条，PR 主表扩为 41 项，后续追加保留稳定编号与变更来源。
- 用户最新明确：实名核身第一版不做，沿用旧照片上传接口的方法。以旧 `/kingclub/registrationPhotoUpload` 暂存令牌及后续检测/评分/审核链为原型；CCSOP 迁移方向和安全边界不变。首发不接核身 SDK/权威库，不将供应商开通作为首发依赖，不把照片审核标为 KYC verified。
- 全局媒体压缩、微信式聊天与业务扩展、中央抖音式内容/创作、自研原生美颜、游戏大厅（《夜幕协议》《修仙世界》入口）、储物券/道具、抖音式我的、扫码点单及 App 授权管理员能力均已明确提出。不可再用旧“暂缓/移出 App”将其从完整产品排除。
- 中央已是内容目的地，扫码是独立快捷入口；部分早期“中央扫码”文字是历史，不据此回退 Shell。
- 腾讯核身调研仅后续参考；颜值自建与美颜分别验证，未达标不替换旧付费评分。开源/媒体候选及边界见 `MEDIA_AND_FACE_RESEARCH.md`，不得声称所有文件绝对无损大幅压缩或零总成本。
- 本次为需求文档更新；首版范围方向确认不等于新页面详细规格、UI Flow Approved、真实接口/SDK或生产切换批准。原实名页/状态机的历史 KYC 前置需重审，不照旧文档接服务，不擅自删路由。

## 2026-09-09 产品重整与服务迁移（当前任务）

- 主仓库仍为 `D:\WEB3_AI\KINGCLUB-APP-V2`，不要在 IDE 默认的旧小程序仓库写 App 改动。
- 用户新增参考：旧 Java `D:\2026-ZHUZHOU\SERVICES\wuyexin-service\wuyexin`、新服务 `D:\2026-ZHUZHOU\SERVICES\ccsop-service`、混合 SQL `D:\2026-ZHUZHOU\物业信数据库\nuggets-结构+数据.sql`。本轮旧资料只读；不要把目录名当作当前线上版本证明。
- 用户确认 SQL 是多网站混包，KING CLUB 业务表只按 `k_` / `K_` 前缀认定。以 `s_interface.interfaceType -> s_interface_type.typeId/parentId` 的酒吧分类和接口/Routine 依赖交叉核对。非 k_ 表只登记公共依赖，不默认迁移其他网站数据。
- 用户允许重构旧手工代码和存储过程，旧版用于还原有效业务、历史数据与 UI，不是必须照搬的内部架构模板。UI 99% 类似是待验收目标，不得宣称现已达到。
- 当前先交付产品、架构、迁移和 ROADMAP 文档供用户检阅；本轮新增方案保持 In Review。不得把“完成产品”的长期目标解读为已批准数据库切换、生产部署或真实客户端接入。
- 除下方历史必读文件，开始产品/架构/迁移任务还须读 `docs/product/2026-09-09-native-product-review/README.md` 及其中的 SOURCE_BASELINE、PRODUCT_REQUIREMENTS、ARCHITECTURE、DATA_AND_API_MIGRATION、UI_AND_PERFORMANCE、ROADMAP。
- 原 48 页 UI/Mock 批准继续有效；完整群聊、发布/音乐和真实赠送重新进入需求评审，未自动扩为首发。根交付账本仍是唯一 UI Flow Approved 状态来源。
- 新服务目前为 `business/kingclub-v2 / d9929ff`，有用户 `.gitignore` 改动；任何实际新服务修改前重查 Git 并遵守该仓库 AGENTS 的 migration/对象登记规则。已执行 migration 不回改。
- 旧服务目录与小程序后续文档存在版本不匹配；源码在线版本与最终 SQL 补丁待确认，禁止重置、删除 `._` 文件或擅自部署来试验。

## 2026-09-09 本机工作目录与新增参考基线

- 主工作仓库：`D:\WEB3_AI\KINGCLUB-APP-V2`。不得因 IDE 工作目录指向旧仓库而把改动写入旧仓库。
- 用户指定新增参考：`D:\WEB3_AI\KingClub-git`，本次核实为 `master / 9299208 / 1.1.38`，工作区干净。之后每轮仍须重新检查状态，不得假定一直不变。
- 下文 `505d222 / 1.1.37` 和 Poplar 机器路径是历史迁移基线，不能据此把当前小程序回退。新旧差异见 `docs/audits/2026-09-09-miniprogram-alignment.md`。
- 参考小程序仍只读；本轮用户同意整改不等于批准全局 `UI Flow Approved` 或生产服务接入。

开始任何分析、设计或代码工作前，必须完整阅读：

1. `docs/migration/README.md`
2. `docs/migration/NEXT_SESSION.md`
3. `docs/migration/CURRENT_STATE_AUDIT.md`
4. `docs/migration/TARGET_ARCHITECTURE.md`
5. `docs/migration/DATABASE_MIGRATION.md`
6. `docs/migration/MIGRATION_PLAN.md`
7. `docs/migration/DECISIONS_AND_OPEN_QUESTIONS.md`

进行 Flutter V2 的产品、设计或开发工作前，还必须完整阅读：

1. `docs/v2/README.md`
2. `docs/v2/ARCHITECTURE_OVERVIEW.md`
3. `docs/v2/FEATURE_MAP.md`
4. `docs/v2/ROADMAP.md`
5. `docs/v2/DOCUMENTATION_FIRST_WORKFLOW.md`
6. `docs/v2/BACKEND_FOUNDATION_PHASE.md`
7. `docs/v2/APP_SCOPE_AND_UI_DELIVERY_GATE.md`

任何功能或页面都必须先在 `docs/features/` 下建立独立目录并完成设计文档。未达到文档准入条件时，不得在 `lib/` 下创建对应实现。

Flutter App 必须执行以下全局交付门禁：

1. 先冻结本期 App 功能与页面总清单。
2. 清单内每个功能和页面分别建立目录、完成设计文档并获得批准。
3. 文档批准后只允许开发 UI 和 Mock/Fake 数据流程；不得连接真实超级接口、WebSocket、支付、推送或其他生产 SDK。
4. 使用 Mock/Fake 把本期 App 的全部页面、主流程、异常流程和返回路径完整模拟并完成 UI 验收。
5. 只有全局 UI Mock 流程验收通过后，才允许按批准契约接入真实接口和 SDK。

`Approved for Development` 对 App 页面只表示允许进入 UI/Mock 阶段，不等于允许真实服务接入。除上方 09-10 用户批准的注册模块独立验收后接隔离测试例外，真实接入必须满足项目级 `UI Flow Approved` 门禁。

旧版源码位于 `C:\Users\Poplar\Desktop\KingClub-app`。

旧版稳定基线应为：

- 分支：`master`
- 提交：`505d222`
- 版本：`1.1.37`

在修改旧版前必须先检查 Git 状态。发现与上述基线不同或存在用户改动时，不得 reset、checkout 或删除，必须先向用户说明。

`backup/ai-refactor-20260823` 是未完成的 AI 重构备份，只能作为参考，不得整体覆盖稳定版。

V2 默认方向：

- 微信小程序在稳定版上渐进维护
- iOS/Android 使用 Flutter 新建客户端
- 服务端建设 API v2
- 数据采用共享身份、可选共享同城社交域、各 App 独立业务域
- 先逻辑隔离，后按需要物理分库
- 避免同时全量重写客户端、服务端和数据库

任何架构建议必须明确标记为“已确认事实”“当前建议”或“待用户决策”。
