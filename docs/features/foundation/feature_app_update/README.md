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
