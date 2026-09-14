# NovoRUDP 手机端协议适配

当前范围是KINGCLUB与用户SUPERVM主网帧格式互通，不修改主网协议，不切换真实聊天链路。参考SUPERVM提交12c1f3b的crates/novovm-network/src/novorudp.rs：NOVRUDP0 magic、版本1、96字节头、五种帧、little-endian u64及SHA-256域分离校验。手机端u64使用BigInt，避免最大序号被有符号整数或Web浮点截断。UDP帧总长度不超过65507字节，检查长度后才读取内容。

SHA-256只是完整性校验，不是身份认证或加密。此适配不包含会话握手、端到端密钥、重放防护、NAT穿透、ACK/重传状态机、分片重组、拥塞控制及自动切换，不允许把现有会员明文消息直接发往UDP。后续以同一消息ID/内容摘要承接服务端队列及接收确认，确认跨传输幂等后再接入业务。

验证工具scripts/novorudp-frame-fixture直接include本机主网源文件，生成五种Rust encode/decode往返帧；Flutter解码和重新编码必须逐字节一致，覆盖最大u64、最高位与二进制payload。构建时通过NOVORUDP_SOURCE_ROOT提供主网根路径，不在代码固化本机路径。主网工作树只读。


实现与验证：NovoRudpFrame已支持五种帧编解码；Rust工具使用主网源码离线构建成功，五个encode/decode往返样本生成成功。Flutter四项测试通过，覆盖逐字节互通、u64、损坏帧、输入异步篡改、只读载荷及非法范围；analyze无问题。Rust/Dart在开发机验证，未在手机发UDP，不代替实际直连及自动切换验收。


## UDP实际收发

NovoRudpDatagramLink使用Dart RawDatagramSocket固定对端IP/端口及sessionId，支持发送与帧事件流，丢弃非对端、错误会话、损坏/超预算帧；单个datagram预算1200字节，较大对象需上层拆帧，关闭后不再投递或发送。它不是可靠会话，不提供身份认证、防伪造或重放防护，不能把来源IP过滤当作加密安全。尚未连接正式聊天路由。

Rust样本工具增加仅绑定127.0.0.1的udp模式：随机端口接收合成Data，通过主网Frame::decode解析，再使用Frame::new生成Ack回传。Flutter真实socket测试检查内容、u64和序号一致；其余测试覆盖错误来源/会话/损坏帧、发送大小限制和关闭后拒绝。已运行Rust工具并执行全部6项测试（未跳过Rust互通），定向analyze通过。此为开发机loopback实际UDP，不是手机公网、NAT、弱网重传或主网节点入网验收。


## 主网安全层在Android原生验证

进一步读取主网发现product_overlay.rs已有Ed25519签名握手、secp256k1临时ECDH、HKDF、ChaCha20-Poly1305及128位滑动重放窗口；product_identity.rs有设备授权，product_nat.rs有签名探测/打洞，product_relay.rs有中继。此前裸帧SHA校验不是全部主网安全能力。优先复用这些Rust模块，不在Dart重写密码协议。当前产品安全层采用ChaCha20-Poly1305，不是AES；现有聊天服务链路的AES-GCM与此分开。

直接include原始主网两个源文件的secure_probe.rs已使用NDK28.2/API26交叉构建Android ARM64成功（21.06秒）。在连接的Android12手机实际运行，返回NOVORUDP_NATIVE_HANDSHAKE_ENCRYPT_DECRYPT_TAMPER_REPLAY_PASSED，临时797400字节程序已删除。合成密钥与合成载荷，不涉及真实身份；验证双向解密、握手重放、密文篡改和重放拒绝，且篡改失败不消耗正常包序号。

这证明现有Rust安全层可编译并在该Android执行，不代表App已经E2EE。仍缺FFI/JNI生命周期、设备私钥安全存储、会员到可信peer公钥绑定/撤销/恢复、密钥更新、丢包重传与公网路径验证。尚未安装任何新App包或切换真实聊天传输；SUPERVM工作树保持不变。


## 原生库接口（实施中）

原生库直接编译主网novorudp/product_overlay模块，以不透明整数handle管理身份、待完成握手及已建立通道；不跨FFI传Rust对象指针。种子使用独立32字节入口，不进入JSON命令或错误信息；调用方负责安全存储及输入缓冲清零。命令返回的原生JSON缓冲由配套free释放。单进程最多128个对象，输入长度和帧大小有上限，释放幂等。

respond必须传入已可信绑定的expectedPeer，验证offer身份后才接受握手；start同样显式固定对端。这不能代替会员到设备公钥绑定，正式聊天仍不启用。握手完成消耗一次性handle，seal/open复用主网序号、认证及重放窗口，close释放通道密钥。


原生库接口本批已实现：native/novorudp/lib.rs。开发机真实动态库C ABI两项测试通过，包括完整握手/加解密、错误对端、两类重放与密文篡改拒绝、关闭失效、空种子和超限请求拒绝。Android ARM64共享库构建17.07秒；连接手机实际dlopen、三个C符号调用、身份关闭及输出缓冲释放通过，标记NOVORUDP_ANDROID_SHARED_ABI_LOAD_RELEASE_PASSED，测试程序与库已从/data/local/tmp删除。此批未打包App，下一步仍需Dart封装和账号生命周期。
