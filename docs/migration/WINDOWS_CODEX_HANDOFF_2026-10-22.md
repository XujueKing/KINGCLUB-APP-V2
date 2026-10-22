# Windows Codex 接手：macOS 真机与 Xcode Cloud

更新时间：2026-10-22，Asia/Shanghai。先读本文，再读仓库 AGENTS.md；不要把迁移目录中更早的环境/发布状态当成当前事实。

## 接手目标与已确认约束

用户继续在 Windows 开发 Flutter 和 Android，iOS 使用 Apple Xcode Cloud 构建并交付 TestFlight。只在 main 工作，不新建分支/worktree，不覆盖用户未提交修改，不强推。

本次不自动发布 App Store、不订阅额外付费云额度、不撤销既有证书或删除 GitHub Actions。用户已确认可以不在法国发布；应按真实代码核对 Apple 加密问卷，不直接复制旧版声明。不要把“完全没有加密”或“不使用非豁免加密”作为未经核对的默认答案；本次已按实际问卷完成声明，详见下方结果。

## 工程位置与 Git

| 项目 | 位置/状态 |
| --- | --- |
| GitHub | https://github.com/XujueKing/KINGCLUB-APP-V2 ，main |
| Windows 原工作目录 | `D:\WEB3_AI\KINGCLUB-APP-V2` |
| Mac 实际开发副本 | `/Users/rainbowharubo/Projects/KINGCLUB-APP-V2` |
| Mac 挂载的 Windows 工程 | `/Volumes/D/WEB3_AI/KINGCLUB-APP-V2`，本次 NTFS 只读，不能在此运行写缓存的 Flutter 操作 |
| IDE 默认旧目录 | `KingClub-git` 是旧小程序参考仓库，不能把 Flutter 改动写到那里 |

Mac 的 GitHub CLI 已实际登录 XujueKing，HTTPS 推送成功。Windows 应重新 `gh auth status` / `git remote -v` 核实自己的认证，不假设 Mac 的登录已迁移。Windows 原 `.ssh/id_ed25519_new` 实测 GitHub 返回账户 xonovo，虽然公钥注释为 XujueKing；另一把旧 id_ed25519 有口令保护，未确认其远端身份。不要仅凭密钥文件名/注释判断账户，也不要在交接中输出私钥或口令。

恢复 Windows 时先 `git status --short` 检查修改，再 fetch/核对 main 并安全合并远端。工作区干净且可快进时可用 `git pull --ff-only origin main`，禁止用 reset/clean 丢掉原有修改。

## 已完成并验证的结果

- Mac：Flutter 3.47.1 / Dart 3.13.1，SDK `~/develop/flutter`；本机 Xcode 26.5，CocoaPods 1.17.0。Flutter 固定提交 `6655482ec06e547f90abf8ae7590466f4415978d`。
- iPhone 真机配对、开发者模式、自动签名和安装通过。Profile 包可脱离调试器从桌面启动，用户已确认进入正常页面。Debug 包直接从桌面打开出现 Flutter 英文限制提示属于启动方式问题。
- 模拟器窗口黑屏有音乐：切换 CoreSimulator lowPower GPU 策略后用户确认恢复；这不是“独显性能差”的结论。用户现优先真机/云构建。
- 服务入口修正后，真机会员请求返回成功，资料页面的数据请求已核验。不能把旧的错误根入口继续写进构建参数。
- Xcode Cloud 已接入 GitHub；#201 的 post-clone、依赖解析、工程检查、Archive 均真实成功，已上传 Apple，构建处理状态 VALID。
- TestFlight 出口合规阻塞已解除：按代码选标准算法、按用户授权选不在法国分发；Apple 初次返回 READY_FOR_BETA_TESTING，加入内部组后变为 IN_BETA_TESTING。手机实际安装和业务页面验收尚未由用户确认，不能把后台可测试状态当成手机验收。

## 云端资源与参数

| 项目 | 已核实值 |
| --- | --- |
| App Store Connect 显示名 / App ID | KINGBAR / `6745736540` |
| Bundle ID / 签名团队 | `com.lingmei.kingclub` / `239E9W6PEN` |
| App Store Connect issuer | `69a6de80-4c53-47e3-e053-5b8c7c11a4d1` |
| Cloud product | kingclub / `5420A5FE-2D74-4869-BA7D-C1794832C49A` |
| Workflow | iOS TestFlight / `3E1762BB-3FDF-43D0-9365-A935254409C2` |
| 主仓库 ID / main Git reference ID | `9a13571f-4ae0-4886-bb3a-7a24d2139a32` / `aa07d656-e555-46b4-a50f-cda651a765b2` |
| Workspace / Scheme | `ios/Runner.xcworkspace` / Runner |
| 云端环境 | Xcode 26.6 (17F113)，本次 macOS Tahoe 26.5.1 (25F80) |
| Action | Archive iOS / Release，INTERNAL_ONLY |
| Post-action | TestFlight 内部人员组，2 名成员 |
| 缓存 | clean=false，允许恢复缓存 |
| 触发 | main 推送；只匹配 lib、ios、assets、pubspec.yaml、pubspec.lock、裁剪补丁脚本；也支持手动 |
| 普通参数默认值 | KINGCLUB_BUILD_NAME=1.2.0，KINGCLUB_IOS_SYSTEM_CALLS=false，KINGCLUB_IOS_WECHAT_PAYMENT=true |
| Secret | KINGCLUB_TENCENT_MAP_KEY 已作为共享 Secret 关联本工作流，不要再索取或提交明文 |

控制台： https://appstoreconnect.apple.com/teams/69a6de80-4c53-47e3-e053-5b8c7c11a4d1/xcode-cloud/products/5420A5FE-2D74-4869-BA7D-C1794832C49A

Apple Developer Program 包含每月 25 个计算小时，未用完不结转，与 GitHub Actions 额度独立。未核实当前账期精确剩余小时；不要称“还有完整 25 小时”。Android 专属或普通文档改动不应触发 iOS 构建。官方：https://developer.apple.com/xcode-cloud/get-started/

## 已跑过的云端构建

| 构建 | 结果与定位 |
| --- | --- |
| #200 | run `28190bac-f975-475f-9f60-54cf9dab1c6f`；失败于脚本 CI_TEAM_ID 格式比较，未开始实际编译；后续生成插件目录缺失是提前退出的结果 |
| #201 | run `d2f0fa7b-083d-4d2c-be4a-a9f2907eee3c`；由提交 `7b316539` 自动触发，post-clone 约 2 分 18 秒通过，Archive SUCCEEDED |
| Apple 构建 | 1.2.0 (201)，build ID `aaae0126-b812-4649-9076-33642b79a1c3`，processingState=VALID，INTERNAL_ONLY |
| TestFlight 状态 | 问卷保存后 IN_BETA_TESTING，外部测试 NOT_APPLICABLE，usesNonExemptEncryption=false；后续接手重新读取，状态会变化 |

云端后续构建号自动递增，不要重置为 1、200 或复用 201。若和 GitHub Actions 同时构建，要协调所有渠道的构建号。

## 加密问卷：已处理及后续约束

用户最新确认：可以不在法国发布。本轮已在 Apple 实际问卷选择“代替在 Apple 操作系统中使用或访问加密，或与这些操作同时使用的标准加密算法”，下一页“你的 App 是否会在法国分发？”选择“否”并保存。Apple 将本版 usesNonExemptEncryption 记录为 false，internalBuildState 在加入内部组后已变为 IN_BETA_TESTING。这是按本版事实作答后的结果，不是直接沿用旧版。

已核实旧版 166、149、144 等 usesNonExemptEncryption=false，仅为历史记录，不能视为本版自动豁免的充分依据。

代码线索：

- `pubspec.yaml`：cryptography ^2.9.0。
- `lib/src/core/networking/kingclub_secure_client.dart`：标准 AES-GCM 256、HKDF/HMAC SHA-256，用于 API 业务请求与响应。
- `lib/src/core/networking/kingclub_realtime.dart`：同类标准算法保护实时业务消息。
- media_cache、nearby 身份和 RUDP 身份相关文件还使用 SHA-256；不能把所有 cryptography 引用都说成数据加密。
- 仍应核对 iOS 实际打包依赖和第三方 SDK（包括 WebRTC），不应仅检查 HTTPS 就说“没有额外加密”。自定义业务报文格式也不等于自创加密算法。

本轮通过 appAvailabilityV2/territoryAvailabilities 核实 FRA.available=false、contentStatuses=[CANNOT_SELL]，法国原本就不可售，因此未更改实际销售地区。availableInNewTerritories=true 仍为现有设置；未来增加地区/法国或改变加密能力时应重新核对，不把当前声明无限推广。没有编造申报文件或出口编号。

下一位 Codex：先复查内部组关联与 TestFlight 状态，再请用户在手机 TestFlight 安装 1.2.0 (201) 并验收。内部组 ID 为 `6b965ee5-a5d9-4104-b5a1-84fe58a69319`。本轮声明前，云端 TestFlight 后续操作一直显示 RUNNING，不应因此重建整个 iOS 包；先判断后台实际构建状态及群组权限。若以后新包再次提示合规问卷，复核算法及法国范围，按相同已确认条件操作；变化时重新评估。

Info.plist 的 ITSAppUsesNonExemptEncryption 本轮尚未改动。后续可在保持当前加密用途与不在法国分发的条件下，依据本次实际问卷结果持久化声明以免每次手填；不要将该字段解释为“App 没有使用 AES”。

Apple 官方参考：

- https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation
- https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption
- https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations

## 脚本与已修复问题

- `ios/ci_scripts/ci_post_clone.sh`：必须保持可执行、LF 换行；.gitattributes 已固定 *.sh 为 LF，避免 Windows 提交 CRLF。
- `ios/ci_scripts/configure_cloud_build.py`：输出临时权限 600 的 define 文件，不打印地图 key。校验 Cloud product/Bundle ID，不再把 CI_TEAM_ID 强行等同本地 DEVELOPMENT_TEAM。
- Pods 必须在 ios 当前目录执行：`(cd ios && pod install --deployment)`。使用 --project-directory 而不切换目录会影响 Flutter SPM 插件相对路径，导致部署锁文件检查失败。
- `scripts/patch_ios_avatar_cropper.py`：保留既有 iOS 26 裁剪补丁，pub get 后执行。
- 本地旧 Xcode 编辑器保存环境 Secret 报 invalid value；最终使用 App Store Connect 网页创建共享 Secret 并关联工作流，已核实成功。后续优先用网页管理环境变量。
- 五项 Python 配置测试、bash 语法、diff 检查通过；独立本地副本 hook 演练通过；云端 #201 又验证了完整编译和上传。
- 仓库内容检查仍命中基线中两个已跟踪但被忽略的 party-commerce 设计 PNG，不是本轮新增，未删除原设计资料来掩盖检查结果。

## 接口、证书与凭据

构建必须使用：

```text
KINGCLUB_API_BASE_URL=https://api.wuyexin.cn/kingclub-v2
KINGCLUB_COMMERCE_API_BASE_URL=https://api.wuyexin.cn/commerce
```

根 api.wuyexin.cn 的旧误配置会导致 K107 Interface not found / 会员资料异常；commerce 不要拼成 /kingclub-v2/commerce。

Xcode Cloud 使用 Apple 托管签名，无需给它上传旧 .p12。Mac 已有可用开发证书、新旧两个发布证书，可共存；灰色 Not in Keychain 只表示该具体证书的本机签名身份缺失，不代表所有签名不可用。不要因此撤销旧证书影响原 GitHub CI。

供核对的 Windows 原私有文件位置（只记录路径，不复制内容到 Git）：

- `C:\Users\xiaoshafa\.kingclub-private\testflight\distribution.p12` 及同目录口令文件：旧 GitHub CI 发布签名材料。
- `C:\Users\xiaoshafa\.kingclub-private\maps\tencent.json`：已有地图构建配置。
- `D:\WEB3_AI\KingClub-git\AuthKey_75582969MB.p8`：本次实际验证可用的 App Store Connect API key，key ID 75582969MB；issuer 见上表。不要把 .p8 当作 .p12 签名证书。

API 已验证可读取产品、工作流、构建、issue/artifact、TestFlight 状态，可修改触发条件并启动构建。环境 Secret 和首次接入本次走网页/Xcode；不要假定公开 API 支持同样操作。Mac /tmp 下的诊断脚本不在 Git，Windows 需复用自己的 API 工具，JWT 和私钥不要打印到终端或提交仓库。

## 重要提交与交接验收

0c4181f0（Mac CocoaPods）、0e34ff0d（自动签名）、7485e3fe（接口入口）、ef677cee（独立 Profile）、aa71397d（云构建脚本）、d5aec470（接入记录）、7b316539（云端产品校验修复）。不要把本交接文档自身的提交误认为 #201 的构建源码提交。

接手后优先顺序：复查 TestFlight 后台/内部组状态 → 手机实际安装验收 → Windows 安全同步 main → 正常开发 Android/Flutter 并推送触发 iOS。正式 App Store 发布需把 Archive 分发准备改为 App Store Connect 并另行按用户发布要求处理；当前 INTERNAL_ONLY 包不能直接用于商店发布。

最终内部组校验：合规保存后，#201 尚未自动关联到内部人员组；本轮通过官方 betaGroups/relationships/builds 接口追加关联（HTTP 204），随后 buildBetaDetail 返回 IN_BETA_TESTING。没有创建测试员、外部测试或提交商店审核。手机实际安装仍需用户确认。
