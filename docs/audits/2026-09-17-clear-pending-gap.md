# 清空记录与待发送队列的差异

当前已确认：DirectChatDetailsPage 完成服务端 hide 后，页面调用 resetVisibleHistory(hideNearby: true, clearMedia: true)。控制器仅清理 confirmed/history，没有清空 pending 或持久化发件箱。群控制器 clearVisibleHistory 也保留 pending。

隔离复现使用真实 DirectChatController 和内存仓库边界，所有请求在进程内返回，不访问网络或真实会员：制造 NETWORK_ERROR 后消息进入待发送队列，执行与页面相同的完整清空调用，再同步，消息和队列仍各有一条；调用 retryQueued 后再次进入发送调用。复现输出为 pending_after_clear=1、retry_after_clear=true、network_calls=0。临时脚本/日志在忽略目录 build/clear_pending_probe_test.dart 与 clear-pending-probe.log，不把该现有行为作为永久正确性测试。

结论：当前“清空”不能宣称包含待发送消息取消和相应附件清理。已向用户询问清空是否同时取消待发送消息（推荐一起取消）。正式修复须区分显式清空与权限刷新/历史版本刷新，保留其他会话队列；同时处理发送中迟到回执和附件引用，不能只把内存 pending 清空就算完成。未修改真实用户队列或删除草稿。
