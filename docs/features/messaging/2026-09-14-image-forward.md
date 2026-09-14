# 图片转发（待真机验收）

单聊/群聊图片长按转发进入现有好友/群聊选择器。确认后通过源消息 633/635 获取当前查看人原图授权，严格匹配相对路径、禁止 HTTP 重定向，流式下载最多 20MB，并核对声明长度；不把源授权或源资产 ID 写入目标队列。

图片经已有 ChatImageUploader 631 加密上传，得到本人独立资产，再写 messageType=image/imageAssetId 到目标持久队列。存储失败重试复用已准备的资产与 clientMessageId；入队之后才清理上传请求日志。群目标绑定成员代次。登录变化或页面关闭取消下载/上传；原图被撤回、隐藏或越权时服务端拒绝源授权/下载，不能借已有页面缓存绕过。

14 项 helper/uploader/转发测试通过，覆盖单/群授权路径、上传复用、错误外部路径、超限、截断、登录变化、既有上传与好友/群/位置转发回归；4 文件 analyze 无问题。测试以受控 HTTP adapter 验证客户端，不替代真实 HTTP 媒体链路或双手机收到图片的验收。页面已接，但尚未构建安装本节点。

同时修正位置转发的本地 [位置] 预览字样此前编码为问号的问题，坐标和坐标系不受影响；对应测试恢复真实中文断言。日志 build/chat-image-forward-tests.log。

页面到发送控制器回归：修正队列字段应为 imageAssetId（接口入参仍为 assetId），新增 widget 测试实际进入 DirectChatController 并截获图片发送接口参数；确认前不准备图片，存储失败重试同编号且不再次准备，源 ID 不作为发送资产。与图片准备 helper 共 11 项通过，日志 build/chat-image-forward-page-tests.log。测试仍使用受控接口响应，真实双机验收待完成。

安装及服务验证：8bda492 profile/preview arm64 构建成功（62.5 秒），23:59:28 adb install -r Success，MainActivity 启动成功，数据保留。SHA256 D474133DA09BBC9316157FD5BEE893C7264912A8F1CAC7B41A32580671104AEE。

隔离 MySQL + 真实加密 HTTP 覆盖单/群来源到单/群目标四组合：收到他人资产不能直接冒用发送，原图下载后通过631加密上传获得本人独立资产，目标发送重试同消息ID，源消息撤回后旧原图授权403、转发副本仍200且尺寸一致。日志 build-chat-image-forward-http.log，退出0，CHAT_IMAGE_FORWARD_HTTP_COPY_OWNERSHIP_REPLAY_SOURCE_RECALL_INDEPENDENCE_PASSED。该验证没有发送给真实用户，手机端操作和接收方显示仍待验收。
