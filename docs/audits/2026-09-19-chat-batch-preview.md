# 2026-09-19 聊天客户端合并预览包

干净预览工作树 KINGCLUB-VOICE-PREVIEW 从 cfb45a74 前进到 f554ead7；仅包含已提交的聊天修正及验收文档，未包含主工作区未提交的注册改动，也未操作 COMMERCE 工作树。

本批包含表情删除同步提示/按钮名称，以及群通话 ICE 恢复时中继只读凭据的有限重试。沿用 ARM64 Profile、既有 HTTPS 服务地址、固定原生源码 579008d18db917bd2e12610a8d1f93bebbef3f51。原生设备绑定开启；可选 relay/LAN/peer-file/group-file 开关仍关闭。

构建脚本正常退出 0，Gradle 用时 133.6 秒。ZIP CRC、打包原生库 ARM64 ELF 校验通过，原生库 1014832 字节。存在依赖插件 Kotlin 迁移警告，不影响本次构建完成。

- APK：D:/WEB3_AI/KINGCLUB-VOICE-PREVIEW/build/app/outputs/flutter-apk/app-preview-profile.apk
- 文件大小：167260232 字节
- SHA256：b0fb9a80035bf7e7619380e4c2e0dbd007729c58d37dfae5dd0b19be2f145d5f
- 构建日志：预览工作树 build/chat-0919-batch-build.log

安装前确认 A 没有未发送文本，adb install -r 成功，未清除 App 数据。启动后保留登录；进入已有测试群，原持久化消息仍显示。表情面板可打开，UI 自动化可读取新增“添加单个表情”名称。未发消息、未改关系、未操作 B。

本批相关代码检查证据：表情静态检查及 32 项回归、群媒体静态检查及 30 项回归分别通过，未重复执行此前全量聊天套件。手机冒烟只证明安装/会话恢复/面板入口；真实群通话、网络切换及跨设备表情恢复仍未验收。群服务未发布，发布确认仍待用户回答。
