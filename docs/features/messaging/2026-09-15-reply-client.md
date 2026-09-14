# 原生引用回复（进行中）

复用已确认的输入引用条与气泡摘要。真实消息长按引用保存原消息编号；取消、提交成功及会话失效清空引用草稿。单聊/群文字队列持久保存 replyToMessageId，重建控制器继续同编号重试；回执必须包含相同引用编号（原消息不可用仍保留编号），避免旧服务静默丢弃引用。历史返回 reply.available=false 显示原消息不可用。

客户端只在历史明确 canReply=true 后允许新建引用；共享后端尚未部署此能力，当前手机仍不启用。尚需服务端能力字段、共享部署、页面交互测试、引用点击定位、摘要缓存失效与双机验收。

28项控制器/转发相关测试通过，覆盖单聊和群聊能力未开放拒绝、落盘及重建后同编号引用发送。7个相关文件静态检查通过。日志 build/chat-reply-client-tests.log、build/chat-reply-client-analyze.log。未构建安装此增量。

## 页面验证

chat_reply_page_test 验证真实页面长按引用、取消、带引用发送、下一条普通消息不夹带旧引用。菜单捕获所属控制器，会话改变后旧操作不执行。页面/队列/续期4项通过，页面和测试静态分析无问题（build/chat-reply-page-tests.log、build/chat-reply-page-analyze.log）。仍未安装，引用定位与正式服务启用待完成。

## 引用定位

摘要点击复用 ChatHistoryContextPage，在当前单聊/群聊内重新读取目标序号及上下文，不移动主会话补收游标。原消息刚被个人隐藏时，即使旧摘要尚在页面也拒绝展示；已撤回时上下文只呈现撤回状态。新增 ChatReply 严格校验 UUID、序号与200字符上限，不可用引用丢弃旧摘要且不提供点击。8项页面/解析/上下文测试通过，4文件静态分析通过（build/chat-reply-locate-tests.log、build/chat-reply-locate-analyze.log）。共享服务现已发布 chat-093；此客户端增量尚未安装。双机与缓存同步验收仍待完成。

## 已安装

2026-09-15 00:32:09，dc4d2d7 preview/profile android-arm64 覆盖安装成功，MainActivity 启动成功，保留数据。构建61.8秒、162.0MB，APK SHA256 11899348B551337C812B229BB8FD422B05086182AAB6D0F9F1FFD3DE894523A8。共享chat-093就绪正常。安装不代表双机验收通过。
