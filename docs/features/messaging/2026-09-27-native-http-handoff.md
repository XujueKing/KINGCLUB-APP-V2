# 原生加密 UDP 到 HTTP 分块续传联合验证

补足此前受控 FrameLink / HTTP adapter 测试与手机 HTTP 续传之间的一层证据。新增 `novorudp_file_sender_test.dart` 用例 `real UDP prefix survives handoff to real HTTP socket`，使用现有 release 原生 NovoRUDP 库执行双方密钥握手，经真实 RawDatagramSocket 发出加密帧；本机 UDP 转发夹具连接双方 socket，不注入 Dart 接收流。HTTP 使用绑定 loopback 的真实 HttpServer 与 Dio 默认网络适配器。

生成 2,097,155 字节合成文件。发送完整的首个 1 MiB 分块后停止发送，接收器按 2 秒空闲上限结束 peer 阶段，再走现有 ChatFileDownloader 回退逻辑。授权元数据与账号均为测试夹具，不访问真实会员接口，不开放公网端口。

实测日志：

- peer 阶段约 5,295ms（包含前缀传输和等待）后以 TimeoutException 结束。
- peer_checkpoint block=0 bytes=1048576。
- HTTP 阶段 block=0 cached=true；服务器实际收到的分块索引仅 `[1, 2]`。
- 最终 verified bytes=2097155 reusedBlocks=1 reusedBytes=1048576；读取最终文件与原始全部字节一致。

该用例通过，修改测试文件 analyze 通过。日志在忽略目录 `build/native-http-handoff-test.log`。没有重复全量原生回归、修改生产协议或安装手机。

范围：证明本机真实加密 UDP socket 收到的完整分块可被 HTTP socket 接力复用，不证明 A/B 移动网络与家庭网络之间打洞成功，也不替代双机 peer→HTTP 切换实测。原来的 8MiB 离线读取及 32MiB HTTP 中断续传手机证据继续独立记录。
