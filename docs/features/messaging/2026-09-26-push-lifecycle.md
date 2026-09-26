# 推送登记生命周期

用户已授权接入 OPPO 官方推送，正式包名 com.lingmei.kingclub。此增量不改变聊天 UI。
启动、登录变化、回前台及实时连接恢复触发后台登记；仅 Android 真实服务且配置客户端 AppKey/AppSecret 时启用。厂商服务端 MasterSecret 不进入 App。
SDK 和接口依次执行，最新会话代数保护迟到结果；切换账号清理旧绑定，当前账号登记覆盖同安装旧令牌。失败前台退避重试，后台暂停重试，回前台恢复。凭据和令牌不打印。
验收覆盖登录切换发生在 SDK/接口等待期间、注销、登记失败重试、销毁与暂停。配置缺失时不伪造成功；真正通知下发、点击恢复和锁屏验收另行接通。

实现：KingClubApp 装配 PushRegistrationRuntime，监听会话变更、前后台和 connection.ready。绑定请求超时也记为待清理，避免已落库但响应丢失后漏注销。失败以 15/30/60/120/240 秒退避，仅前台定时重试；进程销毁释放定时器。

构建通过 scripts/build-chat-preview.ps1 的 PushConfigFile 指定仓库外私有 JSON，仅允许 KINGCLUB_OPPO_APP_KEY 与 KINGCLUB_OPPO_APP_SECRET 两个客户端字段。不要把真实配置入 Git；MasterSecret 仅服务端。无配置保持关闭，不影响原有聊天。

验证：运行时与原生桥接共 9 项测试通过，相关 Dart analyze 无问题，PowerShell 构建脚本语法检查通过。真实凭据尚未配置，本次未打包安装，也未宣称厂商通知已成功下发。客户端接口依赖 CCSOP migration 130，部署后才启用配置。
