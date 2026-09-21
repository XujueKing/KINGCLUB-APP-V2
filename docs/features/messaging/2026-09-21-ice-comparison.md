# 同网络 ICE 对照

复用实际聊天通话的 WebRTC 连接与既有信令，不增加另一套身份、测试账号或媒体上传入口。profile 构建每五秒读取已选 transport 的 candidate pair，仅输出候选类型、协议、状态和双向字节计数；不输出地址、端口、SDP、凭据或会员标识。release 不启动诊断定时器。结束通话停止采样，诊断失败不影响媒体流程。

只有已选中的 pair 才记录；仅 collected、nominated 或 succeeded 的未选候选不作为连接证据。双方计数增长与候选类型共同判断该次连接走 direct 或 relay。该结果仅代表本次 WebRTC 链路，不能作为 NovoRUDP 已直连证据；ICE 对照尚待安装联调。
