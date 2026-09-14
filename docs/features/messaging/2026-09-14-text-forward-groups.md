# 文字转发到群聊

现有转发选择器新增好友/群聊切换。群列表来自真实 618，按 nextCursor 继续加载并按名称搜索；保持已有确认流程和页面风格。群消息原文与单聊原文均能进入此选择器。

确认群目标后通过 619 核验活动成员并取得 membershipVersion；以 groupId、成员代次、唯一 clientMessageId 写入既有持久队列，然后打开真实群会话，由 GroupChatController 处理重试。失败重试不生成新编号；账号变化清空选择和群列表、关闭确认，不继续写入。复用群控制器的成员代次校验，不绕过权限发送。

验证：3 个转发 widget 测试通过，覆盖好友存储重试、群目标及成员代次持久化/存储重试、登录变化；页面 analyze 无问题。日志 build/chat-forward-group-tests.log。尚未打包到手机及双机真实转发验收，不能将 widget 测试算作端到端交付。媒体转发另行接入。

## 位置消息转发

原生会话长按位置消息同样进入好友/群聊选择器，确认显示原地点名称、地址；队列保存原 latitudeE6/longitudeE6、coordinateSystem、name/address，使用现有位置消息发送接口，不调用重新定位。沿用群成员代次、账号变化及同编号重试保护。

4 项转发 widget 测试通过，包括坐标及坐标系原样入队；direct/group location queue 和位置模型测试通过，2 页面 analyze 无问题。日志 build/chat-forward-location-tests.log 与 build/chat-forward-location-queue-tests.log。此节点仍待安装和真实接收方验收。
