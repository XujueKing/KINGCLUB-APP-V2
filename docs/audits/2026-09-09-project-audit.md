# KINGCLUB-APP-V2 工程审计报告

- 审计日期：2026-09-09，Asia/Shanghai
- 实际仓库：`D:\WEB3_AI\KINGCLUB-APP-V2`
- 分支/提交：`main / 84e55bcfe78f6cfda47801fbdbce379ab72162f4`
- 开始审计时工作区干净。本次新增报告，未修改业务实现、依赖锁文件或 Golden 基准。
- 依据：根目录 AGENTS.md、迁移交接文档、V2 架构/路线图/全局门禁，以及相关页面契约。

> 本报告保留修复前 `84e55bc` 的审计事实。随后用户同意整改并指定参考最新版小程序；首批实现、当前验证结果及未完成范围统一见[小程序对照与整改记录](2026-09-09-miniprogram-alignment.md)。下方行号和临时诊断断言对应旧基线，不应继续作为修复后回归预期。

## 1. 结论

**已确认事实**：项目可以构建 Android 预览包，静态分析通过，但现有 UI Mock 存在跨页金额错误、状态丢失、死入口、会话守卫缺失和本地封面处理缺陷。`48/48 UI Mock Implemented` 不能作为整 App 流程正确的充分证据。

**当前建议**：本提交保持 `M2 Change In Progress / integration Blocked`，先修复本报告中的流程缺口并重新验收，再判断是否具备 `UI Flow Approved` 的技术前置条件。当前不建议直接进入真实 API、WebSocket、支付或推送接入。

共登记 **3 项 P1、8 项 P2、1 项 P3**。P1 表示应优先修复、阻断完整流程或真实接入的缺陷；P2 表示已确认的功能/质量缺陷；P3 表示文档和维护问题。未发现经本轮验证的 P0，不等于已完成生产系统安全认证。

## 2. 范围与方法

检查对象为本 Flutter 仓库：840 个原有跟踪文件，64 个 lib Dart 文件、41 个测试 Dart 文件、571 个 Markdown 文档；lib 共 33,581 行，包含生成代码。

执行了全仓结构、依赖、路由、资源引用、敏感文件和危险模式扫描；逐段审阅启动/登录/准入、订单/支付、好友/聊天、个人资料/本地文件等关键实现；对照功能契约检查 AA、VIP、扫码、凭证、设置与原生配置；重新运行测试和覆盖率，并编写隔离的诊断用例验证疑点。不是对全部历史文档逐行重新验收。

边界：未修改或审计另一个仓库的后端实现、生产 API、运行中数据库或 IDE 打开的物业 SQL。未进行真实支付、真实短信、生产攻击测试或 iOS/macOS 构建。本轮没有重新逐页执行 Android/iOS 真机视觉验收，不能把 Widget 检查等同于真机验收。

## 3. 按优先级排序的问题

### A01 · P1 · 点单金额、商品和订单引用在支付跳转时被替换

**已确认事实，已动态复现。** 在点单确认路由提供一件 88 元商品并提交后，支付页显示 **¥3680.00**，商品描述变成“轩尼诗XO、芝华士12年”。不存在的 PaymentIntentRef 也会被映射为这个可付款样例。

- [确认页](../../lib/src/features/commerce/presentation/scan_order_confirmation_page.dart:682)始终发出 `fake-order-v8-0827`，金额只存在于返回对象。
- [路由装配](../../lib/src/navigation/app_router.dart:697)仅拼接 payment intent 字符串，没有把新订单登记到可查询的 Fake 数据源。
- [支付样例查找](../../lib/src/features/commerce/presentation/payment_result_page.dart:882)只识别特定 AA 引用，所有其他引用无条件回落到 3680 元样例。
- [支付结果出口](../../lib/src/features/commerce/presentation/payment_result_page.dart:512)再次把用户导向固定的另一个订单引用。

影响：正常点单闭环无法保持商品、金额和订单身份一致；无效引用的异常路径被正常样例掩盖。目前没有发生真实扣款。

**当前建议**：以统一 FakeOrderRepository/FakePaymentRepository 保存报价、订单和意图映射，页面只携带不透明引用；未知引用明确失败关闭。验收应覆盖多种商品组合、优惠、支付取消/成功和回看同一订单，不应把客户端传来的金额直接当作未来服务端权威金额。

### A02 · P1 · 受保护路由没有会话与会员状态守卫

**已确认事实，已动态复现。** 全新运行时未完成登录，即可通过路由进入 `/home` 并显示会员主界面。

- [路由构造](../../lib/src/navigation/app_router.dart:46)没有会话 redirect/onEnter/guard，也没有依赖会话状态的刷新机制。
- [MockRuntime](../../lib/src/core/mock/mock_runtime.dart:35)只保存短信/准入 flow ID；bootstrap 固定返回 anonymous，没有 FakeSessionRepository 或会员会话状态。
- 这不符合[已批准的守卫矩阵](../features/foundation/feature_navigation/guard_and_redirect.md:22)。当前代码也无法统一演示已登录恢复、会员被暂停、顶号及全局撤销。

影响：无法验证文档承诺的身份/会员分区；以后直接替换网络层会保留权限导航缺口。这是当前 Mock 架构缺口，并非已经证实可越权访问生产数据。

**当前建议**：先实现进程内 FakeSessionRepository、统一 SessionView 和守卫矩阵；验证 anonymous/onboarding/pending/approved/revoked 的路由行为，以及退出后重新进入受保护路由的结果。

### A03 · P1 · 真实本地封面不按账号隔离，退出与注销不清理

**已确认事实，已动态复现退出路径。** 通过实际 LocalProfileCoverStore 保存图片后，执行设置路由的退出完成处理，路由回到登录页，但文件仍存在并可再次 load。

- [封面存储](../../lib/src/features/profile_settings/data/profile_cover_store.dart:14)使用全局单例及固定 `profile/cover.png`；接口没有账号/generation 参数或清理方法。
- [退出路由](../../lib/src/navigation/app_router.dart:835)和[注销完成路由](../../lib/src/navigation/app_router.dart:862)仅切换登录页面。
- [个人主页初始化](../../lib/src/features/profile_settings/presentation/my_profile_page.dart:58)无条件加载这一共享文件。
- 该路径已接入系统相册，处理的是可由用户选择的真实设备图片。[资料流程要求](../features/profile_settings/feature_profile_center/flow_and_navigation.md:49)会话变化时清理资料缓存、草稿和媒体引用。

影响：换手机号重新走 Mock 登录后仍可能展示前一次使用者选择的封面；未来接入真实账号时会形成直接的跨账号本地数据串用。注销的残留判断来自相同存储/路由代码，未执行生产注销。

**当前建议**：按账号或会话隔离媒体路径，并明确退出、注销、账号切换时的清理策略；提供 clear/delete 能力，处理临时裁剪文件和图像缓存。清理失败应可观察，不能仅靠“已清理”文案表示完成。

### A04 · P2 · 好友关系、聊天和订单缺乏跨页共享的 Fake 状态

**已确认事实，好友与聊天已动态复现。** 拉黑好友后当前资料页显示“解除拉黑”，离开并重新打开同一用户又恢复“发消息”；发送成功的聊天消息在重新打开同一会话后消失。

- [资料页关系状态](../../lib/src/features/contacts/presentation/user_profile_page.dart:54)仅保存于 StatefulWidget，拉黑只改变该页面字段。
- [单聊消息列表](../../lib/src/features/messaging/presentation/direct_chat_page.dart:123)和余额在每个页面实例重新初始化，没有稳定 conversation ID 对应的共享消息存储。
- [订单中心](../../lib/src/features/commerce/presentation/order_center_page.dart:62)从静态列表重建；创建、取消和支付没有统一更新这份订单数据。
- [Mock Runtime 契约](../features/foundation/feature_mock_runtime/README.md:25)要求页面依赖业务 Repository/port，当前大部分页面把业务状态、延时和样例放在 presentation 内。

影响：单页状态演示可以通过，整 App 的关系约束、聊天连续性和订单一致性仍不成立。大型页面文件是这一耦合的表现，单纯拆组件不能解决数据一致性。

**当前建议**：按领域建立可重置、进程内共享的 Fake 数据源和 application 状态；在页面外完成拉黑联动、消息保存、订单状态变化。验证“操作→离开→重新进入”和多个入口查看同一对象的结果。

### A05 · P2 · 编辑资料保存时丢弃七类可编辑字段

**已确认事实，已动态复现。** 城市改为“湖南省 · 株洲市”并成功保存，重新编辑后恢复“河南省 · 安阳市”。

- [页面字段](../../lib/src/features/profile_settings/presentation/edit_profile_page.dart:83)含城市、职业、身高、常去时段、音乐、饮酒和组局偏好。
- [保存结果类型](../../lib/src/features/profile_settings/presentation/edit_profile_page.dart:30)和[保存方法](../../lib/src/features/profile_settings/presentation/edit_profile_page.dart:511)只返回昵称、签名、封面。

**当前建议**：建立完整的可编辑资料模型，成功保存后更新 Fake ProfileRepository，重新进入从同一模型加载；测试全部可编辑字段的保存、版本冲突和放弃修改。

### A06 · P2 · 会员准入前进再返回会丢失已选偏好

**已确认事实，已动态复现。** 着装页选择“高级酒会小礼服”→下一步→返回，选中状态消失。

- [着装/音乐状态](../../lib/src/features/onboarding/presentation/style_music_preferences_page.dart:57)仅为页面内集合，提交只是等待 completeMockStep。
- [路由前进与返回](../../lib/src/navigation/app_router.dart:219)使用 `go` 重建独立页面，只传 flow ID。
- MockRuntime 不保存对应 flow 的步骤草稿或已提交偏好。

**当前建议**：以 flow ID 保存准入草稿和步骤状态，前进/返回共享这一数据；流程失效或主动放弃时显式清理。至少回归四步往返、补资料和会话失效路径。

### A07 · P2 · 连续更换封面后仍显示上一张图片

**已确认事实，已用真实文件复制和图像解码复现。** 第二次保存写入新图片，但同一路径解码仍返回上一张图；显式清除对应图像缓存后才得到新图。

- [存储实现](../../lib/src/features/profile_settings/data/profile_cover_store.dart:32)反复覆盖固定文件名。
- [图像 Provider](../../lib/src/features/profile_settings/presentation/profile_image_ref.dart:9)使用按路径缓存的 FileImage。
- [主页保存](../../lib/src/features/profile_settings/presentation/my_profile_page.dart:692)没有 evict 或图片版本变更。

**当前建议**：保存后更新媒体版本/文件名，或在替换完成后正确失效图像缓存并触发刷新；测试连续更换至少两次、返回主页和重启后的图像内容。

### A08 · P2 · 好友“发消息”入口没有真正进入单聊

**已确认事实，已动态复现。** 用户资料页点击“发消息”后仍停留原页，仅出现“Fake 会话入口”提示。

- [UserProfileRoute](../../lib/src/navigation/app_router.dart:446)没有传入 onOpenChat。
- [页面回退处理](../../lib/src/features/contacts/presentation/user_profile_page.dart:165)只显示 SnackBar。
- [好友申请列表路由](../../lib/src/navigation/app_router.dart:423)同样用 SnackBar 替代聊天跳转。

**当前建议**：统一从用户引用获取/建立 Fake 会话并打开正确联系人单聊，传递稳定会话引用；验证从资料、申请接受结果、通讯录、会话列表进入同一人的一致性。

### A09 · P2 · VIP 组局创建后的付款/管理出口断开

**已确认事实，静态实现与契约对照。** 创建页有待支付/零元成功结果，但均只弹出带“知道了”的对话框。

- [创建结果](../../lib/src/features/club/presentation/vip_party_create_page.dart:581)没有发出 PaymentIntentRef 或 PartyRef。
- [页面构造](../../lib/src/features/club/presentation/vip_party_create_page.dart:15)只接收 onBack 和日期；[路由装配](../../lib/src/navigation/app_router.dart:639)也没有后续业务出口。
- [已批准交互契约](../features/club/feature_vip_party/pages/page_vip_party_create/interactions.md:11)要求 pendingHostPayment 打开支付，confirmed 进入组局管理。

影响：创建→付款→管理不能连续完成；零元结果也没有生成可被管理页读取的同一场局。

**当前建议**：用共享 Fake Party/Order/Payment 数据源产生稳定引用，并接通这两种结果出口，分别做付费和零元端到端 Mock 流程回归。

### A10 · P2 · 路由上下文缺失时显示技术错误且布局溢出

**已确认事实，五个路径动态复现。** `/auth/code`、`/onboarding/identity`、`/social/profile`、`/scan`、`/me/edit` 在未携带 extra 时无法构建业务页，转为包含 Null 类型错误的框架错误页；393×852 视口出现 156～204 px 底部溢出。

- [短信路由](../../lib/src/navigation/app_router.dart:119)、[准入路由](../../lib/src/navigation/app_router.dart:168)等依赖非空 `$extra`。
- [顶层路由配置](../../lib/src/navigation/app_router.dart:52)没有统一上下文校验或应用级错误恢复页。

影响：冷启动路由、缺失上下文的导航或未来深链接入会产生技术错误页面。这里复现的是 Flutter 路由错误页及布局异常，不是已证实 Android 原生进程崩溃；当前也未接通公开业务深链。

**当前建议**：在构建页面前校验上下文有效性，缺失时跳转登录/流程恢复/安全错误页；不把整段类型异常直接展示给用户，并覆盖未知路径和恢复后的安全返回。

### A11 · P2 · 当前测试门禁未通过，关键跨页与原生路径覆盖偏低

**已确认事实。** 全量现有测试 306 项，本次 304 通过、2 失败，失败均为 onboarding Golden（每张图 224 px，约 0.07% 差异）。本次聊天附件 Golden 通过，不能继续沿用上轮“3 项失败”的数字。

- [偏好 Golden 测试](../../test/onboarding_preferences_visual_test.dart:24)两项测试合计四张图失败，差异位于返回图标区域；具体基准/字体加载原因尚未最终归因，不能直接认定为无害后更新基准。
- 实际测试图中文字为默认测试字体的占位形状，不能证明中文排版或真机字体表现已验收。
- 总行覆盖率 82.85%（9833/11869），但 [app_router.dart](../../lib/src/navigation/app_router.dart) 为 24.5%，[cover_adjust_page.dart](../../lib/src/features/profile_settings/presentation/cover_adjust_page.dart) 为 0%，[profile_cover_store.dart](../../lib/src/features/profile_settings/data/profile_cover_store.dart) 为 27.3%。这些是当前测试运行生成的行覆盖统计，包含生成代码，不代表需求覆盖率。
- 原有仓库没有跟踪 `integration_test/` 测试或常见 CI 工作流配置。若外部另有 CI，本轮未验证。

**当前建议**：优先加入真实 appRouter 驱动的跨页 Mock 测试和本地文件 adapter 测试；固定 Golden 的字体/图标/环境并审查差异。在 CI 上执行锁定依赖、分析、测试和预览构建，而不是只检查测试数量。

### A12 · P3 · 入口文档与当前范围、验收状态不同步

**已确认事实。** [功能索引](../features/README.md:6)仍写 32 功能及 26 Approved/4 In Review/2 Draft；当前[唯一交付账本](../v2/APP_SCOPE_AND_UI_DELIVERY_GATE.md)已有 33 功能、48 页。根 README 仍写 6 条测试，部分迁移/Roadmap 文档仍写 28/48。

2026-08-29 的历史验收报告曾写“无剩余 P0/P1/P2”和“好友主页到聊天入口通过”，这不能继续作为当前提交的通过证据。交付账本顶部已经标记新增聊天扩展后待重新验收，应以最新复验结果收口。

**当前建议**：以唯一覆盖账本为当前状态来源，历史报告明确其提交基线；入口文档改为链接该账本与最新验证记录，减少手工复制数量。本次不擅自更改任何用户审批状态。

## 4. 已通过和未发现异常的检查

| 检查 | 结果与边界 |
|---|---|
| `flutter analyze --no-pub` | 本轮通过，No issues found |
| Android preview debug 构建 | 同一提交在本会话前阶段已成功构建并复验；现有 APK 213,651,515 字节。本轮源码未变，未为审计重复打包 |
| 现有测试 | 304 通过 / 2 Golden 失败；详见 A11 |
| 新增临时诊断 | 15/15 断言完成，证明缺陷确实可复现；这是缺陷复现成功，不表示项目验收通过 |
| 静态资源引用 | 123 处可静态解析引用，未发现缺失文件；不涵盖所有动态拼接引用 |
| 仓库内容门禁 | 840 个原有文件，46.51 MiB；没有被忽略却仍跟踪的文件 |
| 凭据检查 | 未发现跟踪的 .env、私钥、keystore，或本轮规则匹配的私钥/GitHub/AWS/OpenAI 凭据；非完整历史密钥取证 |
| Pub 依赖已知漏洞 | 对锁定版本的 131 个 hosted 包执行 OSV 批量查询，返回 131 条查询结果，漏洞命中为 0；不涵盖 Maven、CocoaPods、SDK 和未公开漏洞 |
| 真实网络边界 | 本轮 lib 静态扫描未发现真实业务 HTTP/WebSocket 调用；系统相册和本地封面文件已接入，需按真实设备数据处理 |
| 原生目标配置 | Android minSdk 24、preview 包名 `com.lingmei.kingclub.v2preview`；iOS minimum 15，bundle ID `com.lingmei.kingclub` |

依赖查询方法依据 [OSV API 文档](https://google.github.io/osv.dev/api/)，查询结果来自本轮对公开依赖名称/锁定版本的实测；未发送项目源码或凭据。

Android release 尚未配置正式签名，iOS 签名和真机验收仍待后续发布阶段。本轮没有将这些已知的阶段性未完成项计为新增业务缺陷。

## 5. 建议修复顺序与验收条件

**当前建议**：

1. 先实现共享 Fake 数据和会话边界，修复 A01～A04。让同一订单、关系和会话跨页保持身份与状态一致；本地照片按账号隔离/清理。
2. 接通好友聊天、VIP 支付/管理出口，完善路由上下文失败恢复（A08～A10）。
3. 补齐资料、准入草稿和封面缓存行为（A05～A07）。
4. 修复并稳定现有 Golden，增加上述真实跨页回归，补 native adapter 测试与 CI（A11）。
5. 同步最新报告和账本，在 Android/iOS 目标设备上重新验证关键流程与返回路径，再提交用户 UI 验收（A12）。

进入下一阶段的最低验证样例：任意点单商品/金额在支付和订单详情一致；VIP 付费/零元两条流程可闭合；拉黑后重进仍被限制；消息重进仍在；资料字段保存后全部保留；准入往返不丢草稿；连续换封面即刻刷新；退出/换号不串用个人图片；会话/会员状态守卫矩阵与缺参路由可恢复；全部既有测试通过。

**待用户决策**：本轮没有新增必须阻塞审计的产品选择。修复方案实施和最终 `UI Flow Approved` 是后续任务；本报告没有替代产品验收。

## 6. 本机诊断证据

以下均为忽略目录内的本机诊断产物，没有加入正式测试集：

- `.dart_tool/kingclub-audit-tests.log`：现有全量测试日志。
- `coverage/lcov.info`：现有测试生成的覆盖率数据。
- `.dart_tool/audit_20260909/audit_repro_test.dart`：金额、引用、聊天入口、路由、准入、资料、关系和消息诊断。
- `.dart_tool/audit_20260909/audit_cover_repro_test.dart`：真实本地存储与图像缓存诊断，使用隔离目录及项目自带图片，没有读取用户相册。
- `.dart_tool/audit_20260909/repro-verified.log`：最终 15 项诊断断言结果。
- `.dart_tool/audit_20260909/static_audit.mjs`：静态资源和凭据模式检查。
- `test/failures/onboarding_*`：本轮 Golden 差异图。目录中的旧聊天差异图来自上轮，不是本轮新增失败。

运行诊断命令：

```powershell
flutter test --no-pub --concurrency=1 --reporter expanded `
  .dart_tool/audit_20260909/audit_repro_test.dart `
  .dart_tool/audit_20260909/audit_cover_repro_test.dart
```

诊断用例有意断言当前错误行为，修复后应改写成正常行为的正式回归测试。`.dart_tool` 内材料会被 `flutter clean` 清理，关键复现步骤与证据位置已在本报告保留。期间一次并发诊断编译遇到本机内存不足，改为串行后全部完成，未归类为业务代码缺陷。
