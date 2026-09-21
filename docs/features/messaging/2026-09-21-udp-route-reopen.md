# UDP socket 关闭后的自动恢复

IPv4 socket closed/onDone 会关闭 NovoRudpLanRoute。此前父级成员通道只在建立时打开一次该对象，因此 WSS 继续工作时无法再次尝试直连。现在父级每五秒检查一次，仅对缺失或已关闭的路由重新绑定；正在打开时不会并发重试，健康路由保持原样。重建重新通报端点并执行既有认证 challenge/response，不沿用旧 ready 状态。

会话关闭取消重试；迟到的 open 结果立即关闭，不重新通报。仍复用原有成员加密会话和 WSS 回退，不改变身份、业务数据、UI 或 SuperVM 共识。此修复解决 socket 生命周期恢复，不等于当前公网 NAT 穿透已通过。

验证：重建与迟到关闭的父级生命周期测试，加上 IPv6 生命周期、真实原生 AEAD 端口学习和 STUN 备用端点测试，共 12 项通过；定向 analyze 无问题。父级测试注入关闭的路由及绑定失败，验证不并发打开、健康路由不重建、保留安全会话、退出后迟到结果关闭。手机尚未安装此节点，因此尚无手机 IPv4 socket 强制关闭后的恢复证据。

## 原生 socket 恢复回归发现并修复候选回告延迟

新增父级 FrameLink 集成测试，使用真实 UDP socket、原生 AEAD 和真实成员安全会话；只有中继控制载体为内存测试替身，不宣称覆盖公网 WSS 或手机 NAT。

测试先建立双向 UDP，等待九秒越过启动通报，再关闭一侧 route。第一条数据通过控制载体回退送达，父级定时重建。修复前重建端 candidates=0、unknownAddresses 持续增加，十五秒内无法恢复：对端收到新端点后没有回告自己的候选，只能等三十秒周期通报。

修复：已认证端点发生变化时立即回告本机端点；端点未变不回应，避免通报循环。回告失败仍执行原有探测。修复后同一测试通过，第二条数据由真实 UDP 送达，receivedRoutes.direct=true；整个测试约十秒（包含九秒预等待）。连同父级生命周期、IPv6 和原生端口学习共十一项通过，定向 analyze 无问题。手机仍安装 bf74a7fd，本次端点回告修复尚未部署到双机。

## 5d099f5e 双机部署

A、B 覆盖安装 profile APK，SHA-256 `d72473e008b052b5d8b6a63d2ede9daa8106c2b6b7b88e42b7ec2513ab74631b`。
实际消息 `0d88ecac-0550-47f9-bdb8-684965d5f87d` 在双方 peer journal 一致，发送端 delivered=1。两端 mapped=true、ipv6Socket=true，A localIpv6=2、B localIpv6=0；本次仍 pingReceives=0、pongReceives=0、ready=false。
该安装验证消息正常送达，不替代手机强制 socket 故障恢复或公网直连验收。真实 UDP 自动重建/回退/恢复的证据范围仍为上文的宿主机原生集成测试。

本节点合并回归：udp_http_handoff、peer_cancel_resume、download_stall、download_receipt、route_probe、public_discovery 六个测试文件，共 54 项全部通过（约 3 分 11 秒）。覆盖共用块与缺失块续传、损坏块拒绝、各媒体超时/不可用回退、慢中继切换及反向恢复；模拟传输计数不视为双机公网 UDP 数据证据。
