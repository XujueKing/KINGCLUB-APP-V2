# 单条为我删除：原生客户端

长按现有消息菜单的“为我删除”接通单聊 663、群聊 664；确认只影响本人记录，群请求绑定当前成员代次。通过历史 canHideMessage 能力字段决定是否启用按钮，旧服务/待发送消息禁用。失败保留消息，成功使本地历史失效并重新同步，同时停止当前语音播放。

hidden 记录参与确认/序号同步和待发送去重，但不渲染为空气泡。已确认的隐藏状态优先于迟到的正文，合并前保护 SQLite 写入，刷新后不会被旧 ACK 恢复。上下文页排除隐藏邻居，隐藏目标显示不可用。

验证：chat_message_hide_test 含真实 SQLite 文件，检查能力缺失、网络失败不删除、群成员代次、成功刷新隐藏、同版本迟到正文不能复活或落盘、上下文隐藏。连同既有 direct/group controller/history/context/store 共 52 项通过；6 文件 analyze 无问题。测试日志 build/chat-hide-client-tests.log。

状态：代码完成，尚未部署配套 chat-092 服务或生成本节点 APK；不能据此认定手机实际删除验收通过。其他未接通的引用、媒体转发等不在本节点交付范围。

## 23:41 部署与安装

配套测试服务已升级 chat-092（代码 78d356e），091/092 迁移和 runtime readiness 检查通过；回退容器保留为 kingclub-v2-api-before-chat-092。原生代码 e149e26 的 arm64 preview profile 包构建成功（76 秒），23:41:12 adb install -r Success，MainActivity 启动成功，现有账号数据保留。APK SHA256：6E35A93634D4F84000E50FC40B3B38AD4A858064832D95C43F9F923780D2CD94。

单条删除现已部署可供操作验收。真实 HTTP/SQLite 自动验证已通过，用户删除后重进会话的真机反馈仍待确认；不要将安装成功替代功能实测。其余矩阵未完成项不变。
