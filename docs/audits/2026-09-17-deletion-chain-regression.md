# 删除链路联合回归

主线文件导出删除通知修复后，联合执行以下测试文件，90 项通过：chat_history_store、chat_media_cleanup、chat_sent_file_cache、chat_download_cache、conversation_list_cache、chat_file_exporter、chat_file_details_page、chat_image_view、chat_video_view。

覆盖持久化重开、已删除内容的迟到下载拒绝、账号隔离、共享附件引用保护、列表旧响应拒绝及媒体界面删除状态。该结果不代表未发送队列取消策略或所有真机场景已经交付。

补强 Android 共用文件复制函数：读取返回后、flush 返回后重新检查取消，避免读取阻塞期间取消后继续写入，也避免 flush 期间取消却报告成功。原生 JVM 测试新增这两个边界，连同原有空文件、256 MiB、摘要、长度、取消及 IO 失败测试通过。未模拟真实 Android 文档提供器；最新原生补丁尚未安装手机。
