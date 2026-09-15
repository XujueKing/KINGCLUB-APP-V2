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


## 磁盘接收与完整性校验

新增NovoRudpFileReceiver，调用方必须提供账号私有目录及经可信信令绑定的session/stream/object、总大小、SHA256；只能喂入安全通道已认证帧。每片976字节，最后一片精确余数，空文件仍需一个零字节已认证分片。分片最多1000000个，内存只保存接收标记，内容串行按偏移写临时文件；拒绝错作用域、错kind、越界及长度不符，重复分片不重复记数/覆盖。最后一片后flush并流式校验总大小和摘要，通过前不提供文件和完成ACK。

ACK使用主网结构及递增epoch，报告首个缺片起始的最多64片窗口；如果缺片区间JSON太大，缩短窗口直到载荷不超过976。已验证完整文件才receiver_done。文件由接收器持有，调用方必须在close之前复制到持久媒体目录并执行自己的账号权限校验；close/会话事件清理本接收器独立临时目录，代次变化阻止迟到读写/结果。当前无断点持久化，不把临时文件误当作已完成媒体。

4项开发机真实Rust加解密+真实文件测试通过：32片逆序丢3片、重复片、生成并消费主网Repair、补齐后逐字节一致和ReceiverDone；错误object与摘要拒绝；130片交替缺失ACK预算及上游接受；空文件与退出清理。测试是确定性省略分片，不宣称真实公网丢包恢复或超时调度已完成。定向静态检查通过。本批未启用正式聊天、未打包或安装App。


## 分片发送调度与丢包验证

NovoRudpFileSender校验源文件大小及SHA256后发起单次传输，使用空DONE帧询问当前ACK（KINGCLUB载体约定，不是远程强制完成命令）。接收器只在作用域匹配且请求为空时回应自己的真实ACK；最终ACK丢失后同样可以再次查询。发送端以认证ACK交给原生规划器，按返回的缺片区间、复制数、批次和暂停读取文件并发送；ACK只保留最新候选，不积攒无界队列。

每次重发重新seal，使用新的AEAD序号。socket未接受的发送有限重试；ACK超时重新询问，连续无进展减少批次、增大间隔；默认最多8次停滞及5分钟总时限。可以取消并唤醒ACK等待；会话失效/通道关闭退出并关闭文件和规划器。收到ReceiverDone仅代表对端已校验临时文件，不表示聊天业务记录持久化。没有伪装成完整拥塞控制/带宽估计，也未实现跨进程断点续传。

真实UDP集成测试：两个安全通道通过本机UDP转发器，按序号丢弃部分前向密文，并专门丢弃第一次最终ACK；71片数据最终精确恢复且接收端至少两次完成ACK。另验证无响应超时、取消唤醒及同大小源内容改变时发送前失败。加密使用实际SUPERVM Rust DLL，文件使用临时磁盘，不是Mock传输。范围仍是开发机loopback：未证明手机公网、NAT、蜂窝弱网或真实用户文件体验。

App业务路由、可信manifest/会员设备目录、worker、NAT/中继及自动fallback仍未接通，未安装新App或改动已确认UI。


## 会员设备绑定证明前置

原生bindingProof只对固定域`kingclub-device-binding-v1`+零字节+scope32+nonce32+本机Ed25519公钥32签名，不开放任意消息签名。Dart从会话身份调用，检查32字节输入及生命周期，输出64字节签名；密钥不经过JSON返回。scope和nonce必须来自已认证服务端挑战，不能让陌生对端任意要求签名。

后端device-binding-proof.ts签发90秒随机挑战并验证签名。实际Rust原生合成签名公开向量已用于Node测试；Dart独立Ed25519验证及域篡改/关闭失效测试通过。挑战的一次性消费、设备目录/好友权限和密钥更新撤销仍未实现，本批不是公钥注册API交付；没有启用P2P或覆盖安装App。


## 客户端设备绑定协调

后端14032d5已部署099及670..673，真实隔离HTTP/MySQL验证通过。客户端新增NovoRudpDeviceBinding，生产open复用MessagingRepository加密会话并从NovoRudpDeviceIdentityStore加载本账号身份；校验账号代次、本机公钥、challenge格式及90秒有效期结构，调用固定域原生签名后登记。使用单调时间控制本地待重试挑战，避免依赖手机与服务器时钟完全一致。

并发ensure合并；每次新操作重新读取本人目录，不把之前缓存当作当前授权。注册失败保留同一挑战/签名，注册成功但响应丢失可通过下一次本人目录恢复。目录条目校验UUID、公钥及peerId一致性/重复/最多8项，不缓存好友公钥；服务端仍是好友关系与撤销权威。撤销先关闭本机原生身份及全部通道，再请求673；网络失败允许重试，不自动轮换或抹掉本机持久密钥。

4项协调测试通过：实际Rust身份和签名由独立Dart Ed25519核验、并发合并/重读目录、相同挑战重试、错误返回与账号切换拒绝、撤销关闭及请求重试。HTTP在本批协调测试中为受控响应，不能称手机端到端绑定已验收；后端真实HTTP结果见其独立记录。静态检查通过。原生库打包、worker、入口及手机绑定联调仍待接，未覆盖安装或启用真实P2P。


## Android原生库打包

新增scripts/build-novorudp-android.ps1，固定审查过的SUPERVM提交12c1f3b40b544fda6f776ae437c325fa917341ee并拒绝两份协议源未提交修改；cargo --offline --locked构建ARM64/API24库，输出至被忽略的build/novorudp-jni。build-chat-preview默认先构建库，临时设置KINGCLUB_NOVORUDP_JNI_DIR供Gradle收集，结束恢复环境；显式SkipNovoRudp才跳过。其他构建未指定该环境变量时不悄悄拾取旧库。构建后检查APK内对应ARM64 ELF；跳过时反而拒绝遗留库。

本批实际profile/preview ARM64构建37.8秒，APK162.2MB。包内lib/arm64-v8a/libkingclub_novorudp.so为803712字节；库LOAD段均0x4000对齐（16KB），最低NDK API24与App一致。APK SHA256为04f6fec1b3464fab91408140beb73d30294337f8d8a8ddae60c2eb3169eca9dd。已通过adb install -r保留数据覆盖安装并成功启动，设备报告lastUpdateTime 2026-09-15 05:59:38。包含工作区原有onboarding三文件改动，本节点没有编辑/提交它们。

这是打包与安装验证，不是手机Dart FFI完整绑定验收；直连运行入口仍未启用，未替用户登记网络身份或发送聊天。iOS、其他Android ABI打包尚未完成。


## Android后台设备绑定入口

真实MessagingRepository.open成功后启动NovoRudpBindingRuntime，不等待登记完成再展示聊天。仅Android ARM64且KINGCLUB_NOVORUDP_DEVICE_BINDING开启时加载本机库；build-chat-preview默认启用，SkipNovoRudp明确关闭。使用已有安全存储身份与670..673接口完成本人公钥登记，不创建UDP socket、不切换聊天传输、不发送聊天消息。

进程内合并初始化；登录代次变化释放原生身份，迟到结果不进入新会话。失败仅输出无账号/密钥的错误分类，五分钟内后续open不重复发起；五分钟后再次open才重试，当前不含独立定时重试。成功记录NOVORUDP_DEVICE_BINDING_READY。

定向analyze通过；登录/会话更新两项回归通过；真实Rust身份的四项绑定协调测试通过（这些测试HTTP为受控响应）。本批profile/preview构建64.6秒、149.0MB，APK SHA256 f21ad8738b30f9aed690fc2ecf30f58d19d25ce1b82076ee3116910a3dd74f06；原生ARM64 ELF包内校验通过，adb install -r Success并启动Status ok。包含工作区原有onboarding改动，本节点未编辑或提交它们。

安装后暂未观察到手机绑定完成标记，待用户解锁进入聊天触发；不能把构建/受控测试记作手机端到端登记已通过。自动直连/中继、原生worker及公网验收仍未完成。

## Persistent native packet worker

SecureChannel.seal/open and repair ACK processing now dispatch to one persistent isolate per secure-session owner, with at most 64 outstanding requests. Replies are correlated by local request number. The bridge uses same-process native function addresses and Rust mutex-protected handles; no library file is downloaded or selected from network data. Identity/handshake creation and explicit handle release remain synchronous and are not claimed as migrated. Session/channel checks after awaited native replies prevent late data returning after logout or closure.

Worker close rejects waiting callers and sends a graceful stop, allowing native finally blocks to release allocated input/output memory. Packet read events are paused during the async UDP receive drain and re-enabled afterward. Without that pause, readiness notifications starved completion callbacks in the actual Windows UDP test after moving decrypt off the main isolate; this was reproduced and corrected.

Validation: 11 tests passed with the actual locally built Rust DLL (not skipped), including authenticated 1200-byte UDP socket packets, tamper/replay/source rejection, repair ACK decisions, logout rejection, and 32 concurrent 800-byte frame round trips with matching replies. Targeted analyze passed. This does not prove Android worker performance, NAT traversal, public relay, trusted handshake signaling or automatic route selection. Installed app still performs device binding only; packet transport is not yet selected for real chats. Not packaged in the 08:29 APK.

## Large-file first-pass transmission

The new 18MiB encrypted loopback loss test exposed a 90-second deadline failure: the sender had no initial data pass and used ACK repair windows to transfer the entire file, including redundant repair copies. After validating the source digest, it now sends each initial data fragment once, conservatively paced at 16 packets / 10ms pause; the existing authenticated ACK repair planner handles remaining loss. Source validation still precedes any datagram. This pacing is not a complete congestion controller.

Validation on the actual local debug Rust DLL and Windows UDP sockets: four sender tests passed, including 18,874,368 bytes with deterministic injected loss and a dropped final ACK. Large-file result: 70,064ms, 25,476 relay packets, 3,593 dropped, exact final file byte equality and final-ACK recovery. The 68,341-byte test completed in 469ms with 97 packets / 14 dropped. Targeted analyze passed. Before the change the large case failed at 90 seconds; that failed experiment is not counted as successful transfer. This is a loopback synthetic-file result, not a performance claim for the user's video, mobile hardware, mainnet or public NAT traversal. Not installed or enabled as a chat route.

## Probe receiver progress before sending file bytes

Sender now requests an authenticated, native-validated ACK before its initial data pass. A live receiver with retained fragments goes directly to repair of missing ranges; a verified completed receiver finishes without retransmitting file data. An unreachable receiver fails after bounded probes rather than receiving a blind full-file pass. Digest validation still precedes all datagrams. This does not persist receiver state across process death or establish a new trusted secure session.

Validation: analyze passed; five real Rust/encrypted UDP sender tests passed. A new case sends 40 of 80 fragments, then creates a new sender and verifies only missing indices are repaired, no new data pass occurs, the final bytes match and another sender does not resend the completed object. Full 18MiB loss regression: 69,871ms, 25,484 relay packets, 3,595 dropped, exact bytes verified. These remain Windows loopback debug-library measurements, not phone/mainnet delivery. Not yet packaged or used by live chat routing.

## Bounded pending fragment writes

Receiver accepts at most 256 pending fragment writes and rejects oversized fragment payloads before retaining their disk-write closures. Additional data packets are dropped under load, remain absent from the received bitmap and therefore remain requested by authenticated ACK repair. This bounds queued data payloads to 256 * 976 bytes (plus object overhead); it is not a total-process or control-message memory bound.

Validation: analyze passed; five real-native receiver tests passed, including a saturated duplicate backlog where the next fragment stays missing and only a later authenticated retry completes the exact file. Four focused encrypted UDP sender regressions passed (small-file loss/final ACK, partial resume, unreachable/cancel and changed source). The 18MiB benchmark was not repeated for this node, and prior throughput numbers are not a new measurement. Not yet installed or selected as a real-chat transport.

## Member-bound native handshake

Added startPeer/respondPeer and a single-use BoundNetworkHandshake on the device-binding coordinator. They require the local key registration and current authorized peer directory before selecting the expected native identity. Completion rechecks the same binding ID/public key, rejects revocation, and releases its pending native handle on failure or cancellation; cancelling during the directory read cannot create a late channel.

Validation: five device-binding tests passed using the existing real Rust debug DLL, including matching negotiated session IDs, a withdrawn peer binding, and cancellation during completion. Directory HTTP is injected in these tests, not a live two-member handshake. Static analysis passed. This is a callable trust boundary for upcoming rendezvous integration, not a connected chat route. Offer/answer exchange, endpoint discovery, NAT traversal, durable message acknowledgement, public relay and adaptive server fallback remain unimplemented; no savings or mainnet delivery claim. Not installed.

## Typed rendezvous client

Added NetworkRendezvousRepository for actual interface 683, bound to the messaging account, two distinct device binding IDs, peer and local login generation. It supplies offer/read/answer/cancel calls, preserves caller-supplied exchange IDs for retries, bounds payloads to 8192 UTF-8 bytes, verifies returned pair/ID/direction/content and unchanged answer expiry, requires cancellation acknowledgement, and discards late responses after close. NetworkExchange stores serialized payloads and returns independent decoded copies. No socket or media starts from construction.

Targeted analyze passed; five injected-HTTP tests passed for retry parameters, late close, wrong bindings/ID, payload bounds, answer role/content/expiry, cancellation and expiration. These are client contract tests, not real native-over-HTTP or phone delivery. Native handshake orchestration, endpoint negotiation and attachment fallback remain to be integrated; 683 remains disabled online. Not installed.

## Native handshake plus rendezvous orchestration

NovoRudpPeerHandshake now connects the typed 683 repository and member-bound native identity. Outgoing retries retain the same exchange ID and native offer; incoming retries retain the same native response and channel until the server acknowledges. It rejects mixed roles and changed exchanges, owns pending handles, observes login changes, closes locally on cancellation/expiry, and caps pending negotiation at 45 seconds. Completion stops the negotiation deadline; ongoing channel authorization and routing are separate unfinished work. Local close releases resources and leaves any remote offer to its server TTL (it does not yet send a remote cancel).

BoundNetworkHandshake now preserves a pending native handle only when its pre-completion directory query fails with NETWORK_ERROR. A native completion attempt, denied key, cancellation or other terminal failure still consumes/releases it.

Validation: six tests passed with the real Rust DLL, including orchestration through an injected rendezvous mailbox with lost offer response, lost answer response, transient directory failure, matching session IDs, actual seal/open of payload bytes, replay rejection and closed-channel rejection. Targeted analyze passed. The mailbox is not live HTTP and no UDP socket/NAT traversal is part of this test. Existing independent backend encrypted HTTP/Redis evidence does not turn this into end-to-end public-network delivery. Not installed or wired to attachment sending.

## Real encrypted HTTP plus native handshake verification

The new opt-in native_rendezvous_http_test.dart passed against an actual isolated API, MySQL and Redis via a loopback SSH tunnel, using KingclubSecureClient (not an HTTP stub) and the existing Rust DLL. Two short-lived synthetic accounts registered newly generated native public keys through 670/671, read authorized 672 directories, exchanged native offer/answer through 683, established matching native session IDs, sealed/opened payload bytes, rejected replay and acknowledged remote cancellation. No microphone/camera or real member messages were used.

Fixture host: backend tests/scripts/native-rendezvous-host.mjs, hard-gated to kingclub_chat_test_20260913, 300-second lifetime; temporary container port published only at server 127.0.0.1:39183, tunnel workstation 127.0.0.1:39184. Credentials were kept in a temporary non-committed fixture file and removed after the test. Container/tunnel stopped. A subsequent independent SQL check proved active native-rendezvous-device test sessions = 0 and interface 683 enabled = 0. Targeted Dart analyze passed.

Scope: this joins the previously separate real native and real HTTP/Redis evidence. Payload encryption was exercised locally after server negotiation, not over public UDP. NAT traversal, public data relay, sustained authorization after handshake and automatic chat attachment fallback are still unfinished. No phone update or online API replacement.
