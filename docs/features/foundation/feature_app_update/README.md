# 远程版本更新

2026-10-06：用户批准实施安卓在线更新、iPhone TestFlight；热更新后续另行接入。

## 页面与行为

设置增加“检查更新”，沿用暗色页面、52 高主按钮和四语言。显示真实安装版本、新版版本、说明、下载进度、重试及安装按钮。返回设置。启动只静默读取小型版本清单，失败不打断业务，不弹窗、不自动下载或安装。用户进入更新页可重新检查；离开页取消下载。

## 契约

HTTPS 静态清单 `/kingclub-updates/preview.json`，schema=1，android/ios 各自独立；平台项为空表示尚未发布。平台项含 build（正整数）、version、notes（四语言数组）、url；安卓另含 sha256、bytes。仅同渠道、同包名、同签名、更高版本可更新。下载禁止重定向，校验长度、SHA256、包名、版本及签名后调用系统安装。安装来源权限由用户开启，回来重试；不卸载、不清数据。iOS 仅跳转受限 TestFlight/App Store URL，不下载 IPA。

无新版本/未发布/读取失败分别呈现，不将异常解释为最新版。版本清单原子发布，先上传不可变 APK 再切换清单；撤销发布可令平台项为 null。业务数据库不参与静态软件分发。

## 验证

覆盖清单非法输入、不可信 URL、版本比较、四语言与重试状态。安卓验证编译、签名一致、下载校验和安装覆盖；iOS 发布需要 App Store Connect、分发证书及 App Store profile，不能复用开发 profile 冒充可上传包。

## 实施记录与发布

- 设置及更新逻辑 14 项测试通过；Dart analyze 无问题。Android 147 编译并保留数据安装到 OPPO；静态清单及 APK 上传校验成功，HTTPS Range 返回 206。当前包是沿用现有签名的 preview/profile 测试渠道；正式商店签名及 Play 更新是独立渠道，不把测试分发当作正式上线。
- 发布脚本 `scripts/publish_android_update.py APK --aapt AAPT_PATH --notes NOTES_JSON` 自动提取版本、验证远端 SHA256，再原子替换清单。notes 文件为简中、英、繁中、泰四个字符串的 JSON 数组。只允许当前 preview 包，拒绝回退版本及同版本不同文件。
- Nginx 实际配置位于测试服务器 `/etc/nginx/sites-enabled/ccsop-wuyexin.conf`，新增独立静态目录 `/var/www/kingclub-updates/`；备份 `/etc/nginx/ccsop-enabled-before-kingclub-updates.conf.bak`。只允许读取，不列目录，不改现有业务接口。
- Apple 现有应用为 KINGBAR，App ID 6745736540，Bundle ID 与本项目相同。旧分发证书已过期，已重新准备仅用于本应用的 App Store profile。复用现有 API 凭据，私钥只放本机私有目录及 GitHub ios-signing environment secrets。
- 新工作流 `ios-testflight.yml` 手动触发，显式传 build_number 和 version（首个新包 1.2.0 / 147）。仅上传 TestFlight，不提交 App Store 审核、不公开发布。现有内部测试组自动接收构建；外部组公开链接未开启，所以清单 ios 暂为 null，不能将旧 App Store 页面伪装成新版更新链接。Apple 处理/合规审核及真机远程升级另记结果。

- 148 上传后 Apple buildUploads 返回 FAILED / 90208：WechatOpenSDK 静态 archive 被 SPM 嵌入 Frameworks。149 修正为最终签名前仅移除已确认静态的 WechatOpenSDK.framework；保留链接进主程序的微信功能，动态库绝不删除。

- 149 首次构建检查拦截：Xcode 26 将 SDK 包装为动态框架。改为读取最终 Mach-O minos，使 framework plist MinimumOSVersion 与二进制一致，重新签名；不降低实际系统要求，不删除动态框架。

- 2026-10-06 22:40（上海）：149 / 1.2.0，CI 37479541446 成功，Apple build e56fbbc3-3099-44d2-b93c-6afc5896c748 processingState=VALID；internalBuildState=MISSING_EXPORT_COMPLIANCE。AES-GCM 标准算法已按源码核对；App Store Connect 表单停在法国分发选择，等待账户持有人确认后保存并向已授权邮箱重发邀请。149 有非阻断定位用途字符串警告 90683，后续正式发布前补齐；未宣称邀请或手机安装成功。

- 用户明确确认本次不在法国分发，已在 Apple 表单保存标准加密 / 法国否。149 internalBuildState=READY_FOR_BETA_TESTING，内部组已自动关联。向用户指定现有邮箱重发邀请，Apple API 返回 HTTP 201（invitation 9ca1865f-ed4f-4229-9646-ecc15b86749b）。邀请已提交，不等同邮箱送达或手机安装；外部测试未提交审核，公开链接仍未开启。

- 2026-10-07：用户询问截图中的批准状态及公测配置。实际浏览器核对外部群组`tengxun`已有1.2.0（149），状态为“已批准”，起初0个测试员且尚未创建公开链接。已创建公开邀请链接 [TestFlight 外部测试](https://testflight.apple.com/join/Fbr2qACB)，向所有符合应用设备要求的测试员开放，先设100人上限；页面核对显示0/100。公开落地页正常显示“加入 Beta 版 KINGBAR”及先安装TestFlight再打开链接的说明。未替用户加入测试或宣称他人已安装。
- 同日将HTTPS版本清单的ios项原子发布为build149、version1.2.0、上述公开链接及四语言说明；安卓148项逐字段保留。更新前清单备份为`/var/www/kingclub-updates/preview-before-ios149-20261007.json`。HTTPS读取确认新清单一致，APP已有更高开发版本不会被当作可降级更新。苹果后台名称仍为KINGBAR；当前公开链接仅包含149版，最近开发的166版尚未上传TestFlight。此次为外部测试配置，不是App Store正式上架。

## 2026-10-07 第166版 TestFlight 发布

- 用户明确要求上传166版。按现有App Store分发签名重新构建，版本1.2.0（166），源提交`e98e045c64a24104fbede44dd920057a0bd54c1d`；[CI 37612648537](https://github.com/XujueKing/KINGCLUB-APP-V2/actions/runs/37612648537)成功。19:20（上海）上传日志返回`UPLOAD SUCCEEDED with no errors`，Apple build ID为`792aacef-c523-4c82-ae3b-a297c77f5c89`。开发证书IPA未用于此次上传。
- Apple处理结果为`VALID`。沿用用户已确认的标准加密、法国不分发声明；核对149至166的加密代码与依赖没有变化，批准149的`usesNonExemptEncryption=false`也用于166。已写入简中、英文、繁中、泰语测试说明，覆盖合作者申请与条款、任务和收益、提现、风险处理及消息交互。
- 166已加入现有外部群组`tengxun`。API返回`externalBuildState=BETA_APPROVED`、`betaReviewState=APPROVED`，浏览器群组构建列表实际显示1.2.0（166）“已批准”，同时保留149。内部测试状态为`IN_BETA_TESTING`。现有[公开邀请链接](https://testflight.apple.com/join/Fbr2qACB)继续启用，100人上限不变；可通过TestFlight安装或更新至166，无需新邀请码。未宣称用户手机已安装166。
- HTTPS版本清单的ios项已原子更新至166及上述链接、四语言更新说明；安卓148项逐字段保留。更新前备份`/var/www/kingclub-updates/preview-before-ios166-20261007.json`，HTTPS读回核对ios build166、version1.2.0、四条说明和链接一致。本地批准截图保存在`build/partner-qa/testflight166-public.png`（构建目录不提交）。此次为TestFlight外部测试，不是App Store正式上架。
