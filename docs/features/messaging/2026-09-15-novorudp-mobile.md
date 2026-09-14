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


## Dart安全会话封装

NovoRudpSecureSession使用真实C ABI导入身份、握手及加解密，拥有本会话创建的所有native handles；原生输入/输出缓冲finally释放，种子的原生临时副本清零。调用方原始seed仍归调用方，应在安全存储加载/导入完成后清零，不承诺Dart堆内任意副本都可清除。ffi 2.2.0由现有传递依赖升为直接依赖，无版本升级。

监听SecureSessionStore.changes并绑定MemberQrMemory.generation；会话改变统一关闭身份/握手/通道，异步帧编码或解码后再次检查代次，阻止迟到结果跨账号。对象不能跨封装实例使用；完成握手后清理一次性handle，提供显式握手取消和通道close；dispose幂等。expectedPeer必须由可信会员设备目录提供，封装不把网络输入自动当作可信公钥。

开发机Flutter直接加载Rust DLL三项测试通过（未使用Mock/未skip）：双向阶段中的实际握手及单向加解密、篡改/重放拒绝、错属实例拒绝、关闭后失效、加密期间代次变化拒绝、会话事件清理及反复创建/释放；定向analyze无问题。Android之前仅验证原生库C ABI，本批Dart封装尚未在Android运行或打包，未接正式聊天路由。FFI调用当前同步，正式高频收发前应放入专用worker并测试帧预算。


## 设备身份保存（实施中）

使用flutter_secure_storage独立kingclub_novorudp_identity namespace，Android resetOnError=false；iOS unlocked_this_device且不iCloud同步。以账号与安装设备ID的域分离SHA-256生成存储键，不直接保存原始账号到键名。32字节Random.secure种子只保存在安全存储，经原生导入后清零临时Uint8List。账号校验与会话代次在所有异步边界复核；跨实例串行创建防止同账号并发生成两个身份。损坏记录/平台读写错误不覆盖，不自动更换。Android备份规则仅排除该namespace数据、包装密钥及配置；其余数据策略不改。正式会员公钥注册、撤销/恢复流程仍待接入，密钥丢失须显式重新绑定。


设备身份保存本批已实现NovoRudpDeviceIdentityStore。开发机5项测试通过，真实Rust身份派生+受控存储覆盖并发只写一次/重开peer不变、账号/设备隔离、损坏记录不覆盖、退出时不继续创建、写失败不返回未落盘身份且后续可重试。平台安全存储在这些用例中是替身，因此不宣称Android KeyStore/iOS Keychain真机读写已验收。定向analyze无问题；app:processPreviewProfileResources通过，Android manifest已关联传统备份和Android12 extraction排除规则。未安装新App包，设备目录绑定及正式入口未启用。


## 安全 UDP 数据通道

新增 NovoRudpSecureDatagramLink，将已固定可信对端的原生加密通道连接到已绑定 UDP socket。接管 socket 和 channel 生命周期，固定来源地址/端口；退出登录或代次变化后关闭，异步加密结束再次校验，未验证密文不进入 frames。畸形、篡改、错误来源及重放包被丢弃，不关闭正常链路。UDP send 返回零明确报错，不当作已发送；可靠层仍须负责重试与确认。

KINGCLUB 专用载体 KCNSEC01（不是主网现有 NOVRUDP0 裸帧格式）：8字节 magic、LE u16版本1、16字节session、32字节发送公钥、32字节接收公钥、LE u64序号、12字节nonce、LE u16密文长度、密文。总头112字节；完整包上限1200，扣除主网帧头96及AEAD标签16，单帧应用载荷最大976字节。公钥还原为主网 novovm-ed25519 标识，所有认证字段原样交回主网验证；该载体须双方明确支持，不能直接发给未支持它的主网节点。当前Dart JSON桥仅接受非负有符号64位序号，超出拒绝而不截断，自动换密钥仍待完成。

实际开发机 UDP + Rust 动态库四项测试通过：最大1200字节双向收发及原帧完整比对、错误来源/畸形/超长/篡改/重放均不投递且随后正常包仍到达、加密中退出清理、版本/长度/序号越界拒绝。测试发现Windows突发send可返回零，测试发送器仅重试未被socket接受的包；没有把未发出当作安全拒收。不是Mock加密，也不是公网/手机NAT验收。

仍未启用真实聊天：会员设备可信绑定、握手信令、分片/可靠确认/拥塞处理、worker、NAT/中继和自动切换尚未接齐。未新增App安装或更改现有聊天UI。


## 主网补传计划桥接

原生库增加 sender / repairAck，直接调用 SUPERVM sender_repair_decision_from_ack，不复制规划算法。sender固定协商session、u64 stream/object和1..1000000分片数，归属Dart安全会话，关闭channel同时释放sender。repairAck只接收已由安全通道认证的ACK帧；裸帧SHA256不能证明身份，调用方不能从原始UDP绕过安全链路直接送入。

调用上游前验证帧kind/session/stream/object、ACK内外epoch一致、expected_total与本地一致、完成标记与缺片数一致、最多64片窗口及64个有序不重叠缺片区间、区间包含关系与缺片计数。无效高epoch不能提前推进上游状态；合法旧epoch返回StaleAck。上游输出Repair/WindowComplete/ReceiverDone，只表示对方报告的规划状态，不是消息持久化回执，不替代完整文件摘要与接收方落盘确认。

开发机重新编译真实Rust DLL并运行10项Flutter测试（本批新增3项，包含加密ACK后调用真实规划器、错误转移/高epoch不污染、释放与容量）全部通过；原生C ABI既有2项测试通过；定向analyze无问题。Android ARM64 release库交叉编译通过（2.92秒），本批未在手机执行新增ACK规划或覆盖安装App。

超时/发送队列/拥塞调度、落盘重组和完成确认仍未接通；不能把补传计划桥接算成丢包恢复已实测。主网源文件只读未修改，真实聊天传输未切换。
