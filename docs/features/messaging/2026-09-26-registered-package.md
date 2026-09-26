# 与 OPPO 已登记包名一致

用户明确要求当前开发应用包名必须与线上一致：`com.lingmei.kingclub`。已在 OPPO 登录管理中心核实既有 KINGBAR 应用 AppId 33364549、该包名、正式通知栏推送和测试权限已开通。

本次移除聊天 preview flavor 的 `.v2preview` applicationIdSuffix；保留 flavor 名和 profile 构建方式，这不等于正式商店发布。启动脚本改用 `com.lingmei.kingclub`，构建脚本通过 aapt 检查最终 APK 包名，错误即失败。filetest/calltest 是独立诊断工具，未改其包名。

隔离工作树构建成功，日志 build/registered-package-build.log；既有 NovoRUDP ARM64 ELF 检查通过。当前是 profile 测试签名，不代表与历史商店签名一致或可覆盖线上安装。尚未安装新包。

A/B 的 pm list packages 均未列出正式包名，仅有预览或其他隔离包。改包名不会自动迁移 Android 私有目录、加密数据库和安全存储。旧预览版保留，不卸载、不清数据；跨包历史迁移仍待实现和验证，不以重新登录下载服务端历史代替本地媒体迁移。

官方当前快速指南显示 SDK 3.7.1，客户端使用 AppKey/AppSecret 注册获得 regId，服务端密钥另行保护。仅阅读了文档和应用权限，未揭示密钥或发送厂商通知。来源：https://open.oppomobile.com/documentation/page/info?id=11221 。推送链路仍在接入中。
