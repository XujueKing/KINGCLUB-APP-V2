# 新会话接续说明

最新细调：注册输入框共享无竖向padding的文字装饰及居中容器；实名说明12sp/1.3行高，宽度同input。修复登录成功push注册页后_verifying未复位，返回手机号页NEXT永久加载的问题；finally统一复位，不影响服务端验证码核验。

最新：用户要求NEXT不依赖“获取验证码”。已按11位合法手机号+6位数字启用；无challenge时也提交，服务端K102在临时配置匹配后建立内部challenge并正常验证，不发短信。migration025登记可选challengeId；此前要求先获取的说明已废止。

## 2026-09-11 NEXT 状态反馈修复

用户指出NEXT禁用却与启用同色。已统一格式/请求状态判定，禁用改明确灰底灰字；11位正确手机号+6位数字+当前challenge才启用。未获取验证码会提示先获取，固定码不发真实短信的后端行为不变。定向覆盖缺少challenge、完整输入、短码、非法手机号及禁用颜色。

## 2026-09-11 临时测试登录

最新：用户要求延长至两个月，服务器截止时间已改为北京时间2026-11-11 12:24；以下24小时为初次配置记录。号码、固定码及实例/场景范围保持不变。

按用户要求，IDC 后端为指定手机号配置24小时固定测试码，截止北京时间2026-09-12 12:24。号码/验证码不写文档或客户端；服务端只保存配置指纹及到期时间，其他号码/敏感操作原流程。App仍点获取验证码建立challenge，但指定号码不发真实短信。无需重装；不要将临时开关迁入正式实例。后端149项及容器内不发送供应商的challenge核验通过。

## 2026-09-11 登录真机成功与实名旧版 UI

用户复查后修复实名页横向偏左（滚动内容外层须撑满）和渐变回退（Flutter 半径按短边换算）。登录/实名共用 registration_input_style.dart，不再复制径向渐变参数；新增实际字段及按钮中心坐标、300dp渐变半径回归检查。

用户重试后 K102 于本地 01:07:33 成功，新会员档案 createdDate 对应本次登录，registrationStatus=identity_required，尚未完成实名/注册审核。随后按用户要求将身份证页回归当前旧小程序 regist2：无 V2 步骤头/进度线/新增勾选，恢复说明文字、金棕渐变字段、底部人脸核验按钮和城市文案。真实核验服务仍未接通；页面样式变更不改变会员状态。

## 2026-09-11 真实注册分流已部署

随后用户真机发现登录失败：K101 成功但 K102/S260824000401 返回 SERVICE_AUTH_REQUIRED。已查明 IDC 服务凭据名称 kingclub-v2 与权威服务要求 kingclub-service 不一致，后端部署脚本和既有凭据已修复；加密合成请求已通过服务鉴权并在业务校验拒绝，不创建用户。无需重装，已通知用户重新获取验证码点 NEXT；完整真机登录结果仍待核实，勿将之前组件测试/健康检查当成用户登录已通过。

K102/K104 已返回新增 registrationStatus（后端 migration 024）。短信后按旧规则分流：identity_required 实名、pending_review 待审、active+approved 首页；重复登录不会将仅手机号建档当成完成注册。真实会话不创建 Mock 注册快照，审核页支持 K104 加密刷新；首页入口有真实状态校验。

测试服务器迁移对账及运行检查通过，OPPO PCLM50（ADB 已连接）已覆盖安装 preview/profile 并启动；本批 Flutter analyze、9 项真实登录分流测试及原注册流程测试通过，后端 verify 141 项通过。旧会员尚未导入；腾讯实名上传/核验、两图评分、审核写入与冷启动会话恢复仍未完成。下一批从真实实名接口继续，不再重复短信、视频或分流开发。

## 有声视频封面增量

用户提供竖屏 MP4，明确欢迎页“就是要有声音，这个像游戏一样”。已压为 4.68 MB，分辨率/帧率/时长保持，原 AAC 音轨逐字节保留；已接入本地自动循环播放、声音开关与页面/后台暂停。详见[封面验收](../features/identity/feature_login_session/pages/page_legacy_welcome/acceptance.md)。真实短信测试入口继续保留。ADB 无设备，真机试听尚未完成。

## 2026-09-10 晚间接续（优先于下文历史）

先读[会话恢复与开发接续基线](SESSION_RECOVERY_2026-09-10.md)：两份导出聊天已与 Git/源码交叉核对。App `b35c33e`、后端 `390632b`；真实短信登录、新会员表、IDC 部署、旧短信正文恢复已完成。直接使用现有测试服务器，不再要求重复短信 UI 批准或额外隔离部署。

测试入口为 `https://test.wuyexin.cn/kingclub-v2`；品牌域名备案由用户处理中。下一步补真实会话恢复/新会员状态衔接，再推进受控照片上传、腾讯照片实名、两图评分及审核查询。保留照片实名认证，不接新增 App 活体 SDK。下文“仅 Mock”“首版不做实名”“22 条需求”等是较早记录，不再作为当前状态。

## 2026-09-10 最新续接：碎片需求与首版照片方案

先读[需求台账](../product/2026-09-09-native-product-review/REQUIREMENT_INBOX.md)与更新后的产品/架构/ROADMAP。当前 22 条 RQ、41 条 PR、W01～W13；用户最新明确**首版不做实名核身，使用旧照片上传接口的方法**。已定位 `/kingclub/registrationPhotoUpload` 的 multipart/imageType/暂存令牌，后续检测/评分链需 R1 对齐；不接腾讯核身 SDK，不伪造 KYC verified。自建颜值先验证，原生美颜独立。

中央已为内容，不再照历史“中央扫码”；原生创作/游戏大厅（《夜幕协议》《修仙世界》入口）、券/道具储物箱和 App 授权经营管理均已要求，详细规格及首发批次待审。09-10 只改需求/调研文档和历史冲突标注；未安装 SDK、未接真实照片服务、未改业务代码/数据库、未提交推送。旧未提交修复继续保留。

## 2026-09-09 当前续接：完整产品评审待用户检阅

先读[原生产品评审包](../product/2026-09-09-native-product-review/README.md)及其需求、架构、数据迁移、UI/性能、ROADMAP 和来源证据。用户允许重构旧手工代码/存储过程，但当前顺序是文档检阅后再开发。已生成 72 路由、106 接口、94 表/1484 字段附件。只将 k_ 表作为本产品业务来源，不迁移混库其他网站；公共表仅登记依赖。

旧 Java 指定目录与小程序更新记录不匹配，最新部署源码与最终 SQL 待确认。新服务实际 `business/kingclub-v2 / d9929ff`、有既存 `.gitignore` 修改；typecheck 与 133 项测试本轮通过，未执行真实环境 E2E/SQL/部署。小程序70项测试通过且不改代码。原 Flutter 跨页修复保留，完整 UI 尚未获用户批准。本轮只改 V2 文档与盘点脚本，未提交/推送。

## 2026-09-09 当前机器接续补充（优先于下文历史路径）

主仓库为 `D:\WEB3_AI\KINGCLUB-APP-V2`，新增只读参考为 `D:\WEB3_AI\KingClub-git`（本次 `master / 9299208 / 1.1.38`）。用户已同意按审计整改，并要求参考小程序完善。先检查两个仓库的 Git 状态，保留未提交修复，不要重置或覆盖。先读[当前审计](../audits/2026-09-09-project-audit.md)和[改进对照/首批修复记录](../audits/2026-09-09-miniprogram-alignment.md)，再按根 AGENTS.md 完整阅读必读文件。

当前仍是 UI/Mock 整改，不接真实服务，不执行数据库 SQL。下文 Poplar 路径、旧提交和旧验收数量均为历史交接信息，不是本机回退指令。

## 给新会话的首条指令

可以直接复制下面这段：

> 请先完整阅读 `C:\Users\Poplar\Desktop\KINGCLUB-APP-V2\docs\migration\README.md` 以及其中列出的全部迁移文档，再检查 `C:\Users\Poplar\Desktop\KingClub-app` 当前 Git 状态。以 `master / 505d222 / 1.1.37` 为稳定基线，不要恢复 `backup/ai-refactor-20260823` 的未完成首页重构。阅读完成后总结已确认决策、待确认问题和建议的下一步，不要立即大规模改代码。

## 必须阅读的文件

- `README.md`
- `CURRENT_STATE_AUDIT.md`
- `TARGET_ARCHITECTURE.md`
- `DATABASE_MIGRATION.md`
- `MIGRATION_PLAN.md`
- `DECISIONS_AND_OPEN_QUESTIONS.md`

## 开始工作前检查

在旧仓库执行只读检查：

```powershell
git branch --show-current
git rev-parse --short HEAD
git status --short
git log -3 --oneline --decorate
```

预期：

```text
branch: master
HEAD: 505d222
status: clean
```

如果状态不同，不要自行 reset；先说明差异并确认是否为用户的新改动。

## 重要分支

```text
master                         稳定版 1.1.37
backup/ai-refactor-20260823    未完成的 AI 重构备份
```

备份分支只用于参考模块化想法，不代表可运行版本。

服务端当前开发分支：

```text
ccsop-service/business/kingclub-v2             KingClub 独立服务实现
ccsop-property-identity-a033/feature/unified-identity-authority-v1
                                                物业统一身份权威接口功能分支
```

## 当前推荐下一步

资产盘点、统一身份契约、A033 幂等/并发/补偿/KYC 冲突、七个 K 接口密文主链、协议目录完整性、旧协议版本拒绝且不消耗短信 challenge、验证码与限流边界、Refresh Token 重用以及真实 WebSocket 撤销观测均已完成。服务端基线为 `business/kingclub-v2 / d9929ff`，物业身份基线为 `feature/unified-identity-authority-v1 / d8a9c18`；完整质量门禁分别为 37 文件/133 项和 190 文件/656 项测试。

四个 Flutter 登录页面已经归档到 `feature_login_session/pages/`，并全部达到 `Approved for Development`。ADR-0001 已批准，本机已升级到 Flutter `3.47.1 stable / Dart 3.13.1`。app_bootstrap、navigation、App Shell/信息架构和 Design System v1 已批准；业务深链和推送跳转仍须随各自页面单独评审。

用户已确认 Flutter 客户端采用全局门禁：本期全部功能/页面文档批准 → 全部 UI Mock → 整 App UI 流程验收 → 真实超级接口/WebSocket/SDK 接入。下一次继续：

1. 用户已于 2026-08-24 按建议确认 [48 页首发基线](../v2/scope/RELEASE_SCOPE_PROPOSAL.md)：46 页普通会员主体 + D4 私人储物柜 2 页。D1 完整群聊、D2 作品发布、D3 红包/金币转赠暂缓；角色后台移出消费者 App。M0 已冻结。
2. 48 个页面均已建立独立文档目录并达到 `Approved for Development`；32 个功能、九个 Foundation 模块、navigation、Design System v1、“四主目的地 + 中央扫码”和实时传输 port 也已批准。
3. 私人储物柜、networking、session/persistence、observability、Mock Runtime 和原生能力已于 2026-08-26 完成最后文档准入；后三类真实 adapter/SDK 仍保持阻断。
4. 文档全局门禁已满足，`flutter create` 已完成；截至 2026-08-28，28/48 页达到 `UI Mock Implemented`。一起玩 AA 的列表、套餐详情与确认订单已完成 Android 视觉、异常矩阵及 15 项专项自动化验收；继续按冻结清单补齐其余页面，真实接入仍保持阻断。
5. `flutter analyze` 与 6 条 Widget 测试已通过；Android API 37 模拟器、Debug APK 和实机 UI 截图已经验证。Gradle 9.3.1 使用带官方 SHA-256 校验的国内镜像下载。
6. UI Mock 覆盖整 App 并经用户验收达到 `UI Flow Approved` 后，才接真实超级接口、WebSocket、支付、推送等。
7. 发布前确认 applicationId/bundleId、域名、CI、Android 签名、Android licenses 和 macOS/Xcode/TestFlight 环境。

生产短信供应商、正式协议、生产服务凭据和 Flutter 客户端仍未验收。

## 工作纪律

- 旧版先建分支再改动。
- 一次只迁移一个业务模块。
- 支付、订单、聊天必须先补状态机和回归用例。
- 数据迁移必须提供校验和回滚脚本。
- 不把旧客户端传入的金额和用户身份当作可信数据。
- 不在同一阶段同时切换数据库、服务端接口和全部客户端。
