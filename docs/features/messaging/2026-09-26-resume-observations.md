# 续传分块证据

为继续 8MB 验收后缺失的双机断点复用验证，在 `ChatFileDownloader` 增加非 release 构建的 `FileResume` 日志。生产 release 不输出这些记录；不记录账号、消息标识、文件名、下载地址、凭据或内容。

- `peer_checkpoint`：完成缓存写入并复查访问权限后，记录完整分块序号与大小。
- `http_block`：分块实际写入目标文件后，记录是否从缓存读取。`cached=false` 仅表示该块来自本次网络读取，不表示网络下载数据量只有一个块（重试可能产生额外流量）。
- `verified`：整文件大小、SHA256、最终权限检查及缓存保留成功后，记录本次 HTTP 组装复用的分块数与字节数。不会对中断或校验失败输出成功总结。

不改分块协议、缓存键、下载授权、回退门槛和重试规则。单纯观察日志不能将此前 HTTP 缓存误认成 peer 来源；需要结合同一次操作的 checkpoint 及中断时间。

验证：`flutter analyze lib/src/features/messaging/data/chat_file_downloader.dart` 无问题；`chat_download_resume_test.dart` 8 项全部通过。正常恢复记录 `reusedBlocks=1 reusedBytes=1048576`，损坏缓存恢复记录 `reusedBlocks=0 reusedBytes=0`，最终文件字节校验通过。测试同时断言请求的分块索引，而非仅断言日志。

隔离聊天预览包构建成功并覆盖安装到 A，未清数据；B 未重装。APK SHA256：`72EAD224C6BECDA5E1B015037CE7B90030CBC0DD878CF88D388C4A0A489BFEF0`。基于 e4311df5 加本次下载器日志差异；主工作区注册页面的并行改动未进入包。

实机后续：已生成 32MiB 测试文件并放到 B 的 Download 目录；尚未确认发送。A 安装成功后 USB 短暂 offline，执行 reconnect offline 后变为 unauthorized，已请求解锁并允许调试。不能把这轮准备记作双机断点续传通过。B 重新登录已由用户完成并核实到聊天列表；没有证据确定之前登录失效的原因，因此未改登录协议或凭据有效期。
