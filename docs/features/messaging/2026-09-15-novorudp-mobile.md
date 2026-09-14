# NovoRUDP 手机端协议适配

当前范围是KINGCLUB与用户SUPERVM主网帧格式互通，不修改主网协议，不切换真实聊天链路。参考SUPERVM提交12c1f3b的crates/novovm-network/src/novorudp.rs：NOVRUDP0 magic、版本1、96字节头、五种帧、little-endian u64及SHA-256域分离校验。手机端u64使用BigInt，避免最大序号被有符号整数或Web浮点截断。UDP帧总长度不超过65507字节，检查长度后才读取内容。

SHA-256只是完整性校验，不是身份认证或加密。此适配不包含会话握手、端到端密钥、重放防护、NAT穿透、ACK/重传状态机、分片重组、拥塞控制及自动切换，不允许把现有会员明文消息直接发往UDP。后续以同一消息ID/内容摘要承接服务端队列及接收确认，确认跨传输幂等后再接入业务。

验证工具scripts/novorudp-frame-fixture直接include本机主网源文件，生成五种Rust encode/decode往返帧；Flutter解码和重新编码必须逐字节一致，覆盖最大u64、最高位与二进制payload。构建时通过NOVORUDP_SOURCE_ROOT提供主网根路径，不在代码固化本机路径。主网工作树只读。


实现与验证：NovoRudpFrame已支持五种帧编解码；Rust工具使用主网源码离线构建成功，五个encode/decode往返样本生成成功。Flutter四项测试通过，覆盖逐字节互通、u64、损坏帧、输入异步篡改、只读载荷及非法范围；analyze无问题。Rust/Dart在开发机验证，未在手机发UDP，不代替实际直连及自动切换验收。


## UDP实际收发

NovoRudpDatagramLink使用Dart RawDatagramSocket固定对端IP/端口及sessionId，支持发送与帧事件流，丢弃非对端、错误会话、损坏/超预算帧；单个datagram预算1200字节，较大对象需上层拆帧，关闭后不再投递或发送。它不是可靠会话，不提供身份认证、防伪造或重放防护，不能把来源IP过滤当作加密安全。尚未连接正式聊天路由。

Rust样本工具增加仅绑定127.0.0.1的udp模式：随机端口接收合成Data，通过主网Frame::decode解析，再使用Frame::new生成Ack回传。Flutter真实socket测试检查内容、u64和序号一致；其余测试覆盖错误来源/会话/损坏帧、发送大小限制和关闭后拒绝。已运行Rust工具并执行全部6项测试（未跳过Rust互通），定向analyze通过。此为开发机loopback实际UDP，不是手机公网、NAT、弱网重传或主网节点入网验收。
