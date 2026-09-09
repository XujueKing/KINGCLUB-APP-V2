# 小程序改进对照与 V2 修复批次

## 已确认事实

- 用户于本轮同意继续整改，并要求参考已经完善的小程序。
- 本机 V2 路径为 `D:\WEB3_AI\KINGCLUB-APP-V2`，基线 `main / 84e55bc`。
- 本机参考路径为 `D:\WEB3_AI\KingClub-git`，工作区干净，基线 `master / 9299208`（提交标题 `1.1.38`）。路径中的下划线在 `WEB3_AI` 内，不存在 `D:\WEB3\_AI` 目录。
- 原迁移文档的 `505d222 / 1.1.37` 保留为历史基线。与当前小程序相比有 159 个文件变化，不能继续假定两个版本相同。
- 小程序只读参考；不合并整个仓库，不修改其数据库、配置或已完善的业务代码。
- `1.1.38` 是本次 Git 提交标题，不是对微信线上发布版本的核验；`package.json` 和 `utils/config.js` 的版本字段另有旧值，不用它们推断线上状态。

## 对照记录

| 已检查的小程序证据（相对参考仓库） | 可沿用的业务/工程规则 | V2 处理 |
|---|---|---|
| `docs/audits/my-profile-2026-08-31/IMPLEMENTATION.md`；`pages/detail-order/detail-order.js` | 订单参数保护、明确的加载/错误结果、金额不使用演示值冒充真实订单 | 首批统一 Fake 点单、支付、详情和订单列表的数据源；未知引用失败关闭 |
| 同一实施记录；`pages/myinfo/myinfo.js`、`pages/userInfo/userInfo.js` | 资料空值/损坏媒体容错、关系变更失败回滚、列表分页去重 | 纳入资料和社交后续整改；不认定小程序文档等于 V2 已实现 |
| `utils/work-draft.js`；`utils/chat-background.js` | 草稿/聊天背景按账号和业务对象隔离；只删除 App 自有副本；文件不存在时安全降级 | 纳入封面隔离、退出清理与草稿恢复整改，不删除用户相册原图 |
| `docs/modules/chat/02-design.md` | 消息稳定身份、排序去重、失败/拒收区分，不能假成功 | 纳入共享 Fake 会话与关系约束整改 |
| `docs/modules/login/02-design.md` | 会员状态决定准入、验证码重复提交保护、冻结与注销不落入普通注册 | 作为参考建议，与 V2 已批准守卫矩阵对照；该小程序文档仍标“待产品确认”，不冒充已经上线的完整会话系统 |
| `docs/audits/media-flow-20260905.md`；`docs/audits/player-playback-race-20260905.md` | 幂等重试、结果未知先查询；generation/epoch 隔离过期回调；按作品恢复播放 | 首批下单幂等和清理后过期结果保护；播放器规则留待批准媒体接入阶段 |

## 当前建议与首批实施范围

本批修复工程审计 A01（金额/订单身份错配），以及 A04 的点单共享状态、A10 的订单/支付缺失引用子集。保持现有页面布局和已批准产品规则，不新增功能页。

1. 以 Provider 容器持有进程内 `FakeCommerceRepository`，页面通过注入共享实例，不使用进程全局单例。
2. Fake 下单保存不可变商品明细、优惠、报价调整、金额、订单引用和支付意图映射。同一请求返回同一订单，不同请求生成不同引用。
3. 支付、详情和列表只查询引用。支付成功、取消业务订单修改同一记录；支付取消不取消业务订单。
4. 未知/缺失引用显示安全错误，不回落到 3680 元样例；支付关闭返回本单或订单中心。
5. 已支付或已取消订单不能再次写入付款；清理后的旧请求不能复活订单。
6. 历史 AA/VIP/售后静态样例仍用于对应 UI 场景；本批不宣称 VIP 创建、会话权限和其他审计项已经修复。
7. AA 现有付费出口也注入同一仓库，登记选中的套餐、营业日与抵扣，不再仅凭抵扣位掩码跳到固定 268 元套餐；清理后可以创建新会话的独立订单。AA 零现金确认和预订首页的完整共享状态仍待后续批次。
8. 订单列表刷新只重读共享状态，不再把固定第 3 条订单无条件改成“支付确认中”。支付/取消的迟到失败提示不能覆盖已经确认的共享结果。

此处报价输入仍为明确的离线 Fake 商品数据，仅用于验收。不是服务端权威价格方案，也不允许未来真实支付信任客户端单价、金额或本地状态。

**已知边界**：本批共享数据只驻留进程内，不宣称支持杀进程后的订单恢复。共享展示沿用原扫码 Mock 的整数元模型；AA 输入仍是整数分，适配时显式拒绝非整元样例，禁止截断。正式 Money/报价/幂等 API port 的完整分层与整数分贯通仍是后续任务。当前的清理钩子只保证这份 Commerce Store 清空，不等于会话守卫、个人图片和所有其他领域数据都已隔离。

## 验收条件

- 88 元单品、多商品优惠、显式接受的报价调整在确认→支付→详情→列表保持一致。
- 快速重复提交不重复下单；结果未知只查询原请求；不同下单互不覆盖。
- 支付成功后重新打开仍已支付；支付取消仍待支付；取消业务订单后重新打开不能付款。
- 缺失/伪造引用不能显示可付款样例；清理期间的异步结果不能恢复旧订单。
- 原有相关 Widget 测试和新增真实路由回归通过，静态分析通过；验证结果单独记录。

## 待用户决策

无新增产品选择阻塞本批修复。`UI Flow Approved` 仍需整 App 重新验收及用户明确批准；本轮同意不授予真实 API、WebSocket、支付、推送、数据库迁移或部署权限。

## 首批实现及验证结果（2026-09-09）

**已确认事实**：

- A01 的离线 Mock 金额/订单身份错配已修复；A04 仅完成点单及 AA 付费出口的数据共享；A10 仅完成订单/支付缺失与未知引用的安全失败；A12 已更新工作目录、参考基线和主要文档入口。不得将这些子集标记为整项/整 App 验收完成。
- 新增 `test/fake_commerce_repository_test.dart`（9 项）、`test/commerce_cross_page_flow_test.dart`（14 项），全部通过。覆盖不可变快照、优惠/变价、幂等、取消、同单跳转、重进、清理、迟到失败/取消不能覆盖已成功结果，以及 AA 清理后新建付费订单。
- 相关专项首轮收敛为 83/83 通过；随后增加两项迟到结果回归并完成最终全量复验。
- 最终 `flutter analyze --no-pub`：通过，无问题。
- 最终 `flutter test --no-pub --concurrency=1 --reporter expanded`：**329 项，327 通过、2 失败**。失败仍为 `onboarding_preferences_visual_test.dart` 的两个准入偏好 Golden，每张差异 224 px / 约 0.07%。未覆盖基准图，未设置跳过或放宽阈值。
- 聊天附件 Golden 在一次中间全量运行再次出现 6853 px 差异，最终全量通过；该不稳定性尚未归因，不能宣称 Golden 已全面稳定。
- 新路由测试发现并修复 AA 套餐底部价格栏在 393×852 下的 18 px 溢出；此项为 Widget 布局验证，不是新一轮真机视觉验收。
- `git diff --check` 通过；`pubspec.lock` 未变。仓库内容脚本通过，但其检查对象为原有暂存快照（840 文件），本批新文件未暂存，不能把该结果宣称为包含新增文件的提交验收。
- 小程序仓库未修改；没有执行 SQL、数据库迁移、部署、真实短信/支付或生产接口调用；没有创建 Git 提交或推送。

本机日志：`.dart_tool/alignment-verified-tests.log` 是最终全量结果，`.dart_tool/alignment-focused-tests.log` 是 83 项专项通过记录。其他中间测试日志保留用于诊断，不代替最终结果。

### Android 构建复验

- 默认源 `flutter build apk --debug --flavor preview` 在 Gradle SSL 依赖下载读取处等待，214.6 秒时中止本任务的构建客户端和它新建的 daemon，没有终止其他项目的 Java/Gradle 进程。
- 默认源离线构建报告 Flutter engine JAR 未缓存；检查发现同版本 JAR 已在磁盘，但属于之前使用的缓存来源。仅为本次命令设置 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`，再执行 `gradlew.bat --offline --console=plain --max-workers=2 ... assemblePreviewDebug`，**14 秒构建成功**，138 个任务中 23 个执行、115 个命中缓存。离线验证未下载新的镜像文件，未修改持久环境或仓库配置。
- 产物：`build/app/outputs/flutter-apk/app-preview-debug.apk`（与 `build/app/outputs/apk/preview/debug/app-preview-debug.apk` 同轮生成），245,649,631 字节。
- 原生包 SHA-256：`300E1A7F6BCDAA7C9A3D7658074217113E1F275FCB840F940357559977BC91E5`。
- `aapt dump badging` 确认包名 `com.lingmei.kingclub.v2preview`，版本 `1.0.0-preview`，minSdk 24、targetSdk 36，包含 arm64-v8a / armeabi-v7a / x86_64。
- 日志：`.dart_tool/alignment-cached-source-build.log`。未执行本轮 Android/iOS 真机验收；构建通过不代表 UI 审批通过。

同环境复现（从 `android/` 运行；先设置本机 JAVA_HOME、PUB_CACHE、ANDROID_HOME）：

```powershell
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
.\gradlew.bat --offline --console=plain --max-workers=2 `
  '-Ptarget-platform=android-arm,android-arm64,android-x64' `
  '-Ptarget=lib/main.dart' '-Pbase-application-name=android.app.Application' `
  '-Pdart-defines=RkxVVFRFUl9BUFBfRkxBVk9SPXByZXZpZXc=' `
  '-Pdart-obfuscation=false' '-Ptrack-widget-creation=true' `
  '-Ptree-shake-icons=false' assemblePreviewDebug
```

**当前建议**：下一批优先处理 A02/A03 的统一会话守卫、个人媒体隔离和真实本地文件清理，再迁移资料/准入草稿与好友/聊天状态，接通 VIP 创建出口，最后稳定 Golden 并做 Android/iOS 真机整体验收。本批结束后真实接入仍阻断。
