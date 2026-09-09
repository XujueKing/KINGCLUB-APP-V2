# 注册准入与腾讯接口核查 / 新后台重构方案

- 日期：2026-09-10；对应 KC-F-010、KC-F-011、PR-01～04、PR-34、W01/W10。
- 状态：**用户方向已确认；旧链路核查和 UI/Mock 第一版已完成；等待本模块 UI 验收；真实接入未开始**。
- 本轮只读检查旧小程序、旧 Java、结构 SQL、新 CCSOP 源码和腾讯官方文档；未调用收费 API、读取真实用户数据、修改旧系统或执行数据库迁移。

## 1. 最新用户决定与解释纠正

1. 开始第一个功能：注册/登录 → 拍照上传核身 → 上传两张照片并评分 → 达标进入；未达标显示“颜值分数不够，等待审核”，可按规则重新上传；审核成功后刷新可进入。
2. 用户明确允许“注册登录模块独立验收后接隔离测试环境”。这不是本模块已经验收，也不是整 App `UI Flow Approved`，不授权生产接入。
3. 用户确认：**保留旧版“姓名＋身份证号＋拍照上传→后台调用腾讯照片实名认证”，只是不接新增的 App 活体核身 SDK。**
4. 纠正此前 RQ-22 的过度解读：“首版不做实名核身，还是用旧的方法，照片上传的接口”不能被解释为删除旧后台的权威库照片比对。此次确认覆盖旧文档中“首版不调用权威库”的文字；照片实名、活体、颜值、会员资格仍分别建模。

## 2. 旧链路：代码事实

以下路径均是本机源码证据，不等于已经验证当前线上部署版本。

| 环节 | 小程序 / 自有接口 | 实际后台行为 |
|---|---|---|
| 手机登录 | 旧 `K_Register_SmsVerify`；新端已有 K101～K107 身份底座 | 验证手机号，与照片实名和会员准入分开 |
| 自拍暂存 | `pages/regist2/regist2.js` → `utils/registration-photo.js` → `/kingclub/registrationPhotoUpload?imageType=0` | multipart 字段 `photo`；处理照片并返回暂存 token |
| 照片实名认证 | `utils/api.js:177` 的 `isFaceVerificationApi` 实际调用 `/kingclub/isUnderageApi` | `KingClubService.java:173`：校验姓名、证件、成年条件；`FaceidClient.ImageRecognition` 输入 `Name/IdCard/ImageBase64`，不是单纯估龄 |
| 自拍评分 | 同一 Java 方法在实名返回 `Success` 后调用 `imageScore(imageType=0)` | 腾讯 IAI `DetectFaceAttributes`，请求 `Age,Beauty,Gender`，保存自拍评分 |
| 两张形象照 | `pages/regist3/regist3.js` 分别暂存 type=1 正面照、type=2 着装照，再调用 `/kingclub/imageScoreApi` | `imageScoreByTokens`（Java:554）分别检测/评分、校验正面人脸尺寸、生成头像、保存图片 |
| 会员准入 | 结构 SQL `K_Register_SetStyles`（约 64197 行） | 保存偏好时计算分数并写 `k_user.userStatus`，还调用注册金币/经验奖励逻辑 |

因此旧注册是 **1 张核身自拍 + 2 张形象资料照，共 3 个照片槽位**。自拍不作为公开头像；原生 App 继续区分这些用途。

旧服务文件基准：`D:\2026-ZHUZHOU\SERVICES\wuyexin-service\wuyexin\service-business-service\src\main\java\com\western\nuggets\service\wyx\kingclub\KingClubService.java`。

### 旧颜值规则是快照证据，不是已冻结的新规则

结构文件 `D:\2026-ZHUZHOU\物业信数据库\nuggets-仅结构.sql:64243`：

- 聚合 `k_user_examine_images` 中该账号的 `SUM(beauty)/COUNT(*)`，没有在该查询中限定当前申请、照片类型或 `deleted=0`。
- 结果赋给 `INT` 局部变量；不能假设新的两图小数均分与它完全等价。
- `k_user.gender=1` 使用 ≥80、`gender=2` 使用 ≥85；同文件注册过程映射为男/女。
- 达标写 `userStatus=2`，否则写 `userStatus=1`；分数判断与偏好保存、奖励存在耦合。

新版本阈值、性别差异是否保留、自拍是否参与均分、舍入方式及重传限制必须明确确认并版本化。腾讯实名相似度 `Sim` 的 70 分不是会员颜值阈值。用户已确认颜值用于准入及低分等待审核文案，但尚未明确是否展示具体数字。

## 3. 腾讯当前接口核查

- **旧 `ImageRecognition` 已停止接受新接入**，腾讯指引新客户使用 `ImageRecognitionV2`；这不等于已宣布所有老客户调用立即失效。本项目旧账号是否仍有权限、是否支持 V2，未登录控制台核验。[腾讯照片人脸核身](https://cloud.tencent.com/document/product/1007/31820)
- **`ImageRecognitionV2` 仍是照片＋身份信息与权威库照片比对**，不是 App 活体 SDK。返回业务结果、相似度和 RequestId；V2 文档说明固定相似度阈值 70。相似度不能当颜值。[腾讯照片人脸核身 V2](https://cloud.tencent.com/document/api/1007/102203)
- **颜值继续使用 `DetectFaceAttributes` / `Beauty`**；接口同时支持人脸位置、属性与质量检测，分数范围 0～100，不能证明身份或真实年龄。[接口说明](https://cloud.tencent.cn/document/product/867/71629)、[返回数据结构](https://cloud.tencent.com/document/api/867/45020)
- 图片约束按各接口分别验证：照片实名 Base64 后不超过 3M、jpg/png；属性接口的大小/像素约束单独执行。不能只检查压缩前文件，也不能用美颜改善准入输入。[实名参数](https://cloud.tencent.com/document/api/1007/102203)、[属性参数](https://cloud.tencent.com/document/api/867/71629)

建议先为 V2 建适配器并验证企业账号权限；仅在已确认老账号权限且有迁移需要时显式保留旧版 adapter。**不在失败/超时后自动降级到旧实名接口**，避免重复收费和身份判定语义变化。企业资质、具体 API 权限、用途及测试费用需在测试接入前确认；不假设腾讯存在免费的照片核身沙箱。

## 4. 新服务器现状

`D:\2026-ZHUZHOU\SERVICES\ccsop-service`：

- `src/adapters/identity/identity-adapter.interface.ts` 只有通用 `verifyFace` / OCR port，返回 `Record<string, unknown>`。
- `src/adapters/identity/mock/mock-identity-adapter.ts` 的 `verifyFace` 固定返回 `verified: true`；`register-default-adapters.ts` 默认注册该 Mock。不能把这种返回用于真实准入。
- 已检查 `src/` 与 `package.json`，未发现腾讯照片实名或颜值的正式实现；应新增正式 adapter，而不是声明服务迁移已经完成。
- `property-identity-authority-client.ts` 是与物业统一身份权威服务通信的加密内部客户端，不是腾讯实名认证接口；不得因名字含 identity 就当作腾讯能力复用。

## 5. 是否重写：当前建议

**重写我们自己的第三方适配层和注册用例；继续调用腾讯官方能力，不重写腾讯算法，也不让 Flutter 直接调用腾讯。** 沿用 CCSOP、既有安全传输和统一身份方向，不另造一个服务器框架。

| 边界 | 职责 | 不应承担 |
|---|---|---|
| Flutter 原生拍摄/上传 | 用户触发相机、说明用途、无美颜采集、合理压缩、分槽位上传、展示状态/重试 | 腾讯密钥、客户端自报实名成功或自报准入分数 |
| RegistrationPhoto 服务 | 私有对象、格式/像素/大小验证、token 绑定账号/申请/槽位/版本/过期与消费状态 | 公开核身原图；接受任意 URL 或仅凭手机号指定所有者 |
| TencentPhotoIdentityAdapter | 官方服务端 SDK 调用、V1/V2 独立映射、检查业务结果及匹配语义、最小证据 | 会员审批、奖励、UI 页面跳转 |
| TencentAppearanceAdapter | 人脸数量/质量和 Beauty 结果规范化、provider/modelVersion/RequestId | 实名证明、法定年龄证明、会员最终放行 |
| RegistrationApplicationService | 校验前置、申请与图片版本、付费调用任务去重、失败恢复、提交审核 | 数据库长事务内等待腾讯 HTTP |
| MembershipAdmissionPolicy | 版本化阈值/聚合规则、自动通过/人工审核/需重传、授权复核 | 把低分、无脸、身份不符、超时都视为同一拒绝 |
| Review/Session 查询 | 同一申请状态、可执行动作；审核通过刷新后同步资格 | 本地按钮变为成功、缓存 approval 绕过服务端授权 |

新业务接口继续通过 CCSOP 已批准入口和目录治理登记；这里只命名语义，不预占 K 编号或声称已实现。上传可使用受控专用通道，不把 Base64 塞进通用业务日志。

### 需要改掉的旧实现问题

1. 旧实名方法仅凭 `Result == Success` 推进，没有读取 `Sim`。旧官方契约还给出相似度判定建议，应按实际 V1/V2 契约测试低相似度与缺字段；不能仅看 HTTP 200 或调用成功。这是静态风险，不声称已复现线上冒名注册。
2. `detectFace` 读取第一张脸；属性接口默认只检测最大人脸，不能据此证明照片只有本人一张脸。需要明确单人照片检测规则；两图与自拍是否还须额外同人比对属于待确认规则/费用，不偷偷增加调用。
3. `RegistrationPhotoProcessor.resolve(token,type)` 不接收 actor/application，且没有在读取时核验 TTL；24 小时清理在后续上传时触发，不等于使用时有效期校验。新服务须做归属、用途、过期、消费与申请版本校验。
4. 旧流程把姓名/身份证参数和供应商完整响应写日志，核身照片走通用图片 URL 保存；新版本禁止复制这些日志/公开 URL 习惯，正式存储访问性另行测试。
5. 两图评分后逐次 promote/save、随后清理 token，未见整条申请级原子提交与请求去重。重传、超时和部分保存须有可恢复任务及补偿；刷新状态不得重新收费。
6. 准入判断与偏好、金币/经验奖励耦合，聚合范围过宽。新服务固定本次申请图片集，偏好可跳过，奖励另设唯一业务键，不能因重新提交或刷新重复发放。

## 6. 第一功能的验收契约

保持现有黑金布局/素材和页面编号，分别完善登录、核身、两图、审核页，不以“99%”宣称未经对照的完成度。偏好两页仍保留且可跳过；准入不能依赖偏好是否填写。是否把偏好从注册导航移到入会后另行确认，不因重构静默删功能。

| 场景 | 必须结果 |
|---|---|
| 新手机号完成短信验证 | 进入未完成的注册步骤；短信成功不等于实名成功 |
| 已合格会员重新登录 | 复核当前资格后进入，不强制重新付费核身/评分 |
| 拍照取消/权限拒绝/上传失败/实名不符 | 留在可恢复状态；不进入两图评分，敏感输入不落普通缓存 |
| 自拍实名通过、两图完整且评分达标 | 根据服务端申请快照进入；客户端不计算最终放行结论 |
| 颜值未达标 | “颜值分数不够，等待审核”；提供刷新与策略允许的重新上传，不使用侮辱性文案 |
| 无脸/模糊/多人/照片不完整 | 指明重传槽位与稳定原因，不误报“颜值分数不够” |
| 腾讯/网络超时，结果未知 | 显示确认中并查询任务；不判为低分、不自动反复计费 |
| 审核 pending → approved | 刷新读取新快照后允许进入；刷新不能自行改 approved |
| 重传提交期间/旧响应晚到 | 旧版本结果不能覆盖新申请；按钮 single-flight，两个槽位状态保留 |
| 退出、换号、失效、冷启动 | 清理前账号敏感状态，复核新账号步骤；旧任务不能恢复权限 |

注：上表“自拍实名”仅指已确认的照片 API 方式，不证明 App 做过活体检测。

## 7. 分阶段交付与未完成项

1. **本轮完成**：核查调用链/SQL规则/新端缺口、纠正文档误解、记录模块独立验收例外和本方案。
2. **UI/Mock 第一版已完成**：页面已使用共享申请快照；核身自拍与两张形象照分槽位，照片选择显示压缩上传状态，评分分流为通过/低分人工审核/补件/结果未知，重传撤销旧通过状态，审核刷新复核后才可进入。路由从两图评分直接进入结果页，偏好页仍保留为可选功能。新增 `registration_admission_flow_test.dart`，并更新端到端和状态测试。
3. **模块 UI 验收**：用户检阅正常/低分/重传/待审刷新/老会员登录等演示。当前状态 `Awaiting Module UI Acceptance`。
4. **隔离服务实现/联调**：遵守 CCSOP AGENTS，正式 DTO/目录/migration、可注入腾讯客户端、合成响应契约测试；确认地址、测试账号、独立凭据/权限、受控照片与费用后接测试环境。没有生产授权。
5. **生产另审**：敏感材料处理、权限/日志、计费防重、规则版本、迁移及回滚测试完成后单独批准，不沿用 Mock 固定成功。

当前验证：Flutter analyze 无问题；注册/身份/整 App smoke 共 52 项聚焦测试通过；浏览器已完成 393×852 主流程、低分/刷新/重传巡检，并以自动化覆盖三种目标尺寸和最高 200% 字体缩放。模块尚待用户在目标设备上检阅，因此不标记 `Module UI Accepted`。证据见[注册准入 UI 巡检记录](../../../audits/2026-09-10-registration-admission-ui-audit.md)。

待定规则：新阈值与聚合范围、是否显示本人数字分、低分可重传次数/冷却、人工审核角色与承接方式、两图同人校验、供应商账号 V2 权限。没有检查腾讯控制台或实测延迟，不承诺免费调用或实际耗时。
