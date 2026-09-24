# 消息与附件的 ICE 数据通道

此前 WebRTC ICE 仅用于通话，普通消息和附件只尝试自有 UDP。现在 `NovoRudpRelayFrameLink` 增加可选 `NovoRudpIceRoute`，所以既有文字、文件、图片、语音、视频的共用帧路径均可使用数据通道，无需发起通话或申请麦克风/摄像头。

启用方式：聊天预览构建传 `-EnableIce`，对应 `KINGCLUB_NOVORUDP_ICE=true`。原有 NovoRUDP 原生 UDP 优先，其次为已建立的 RTCDataChannel，最后走原 SuperVM WSS；上层业务仍保留 HTTP 回退和持久化回执。ICE 协商在后台进行，未完成时发送不等候协商。

使用项目已固定的 flutter_webrtc 依赖。当前数据 ICE 使用同一批配置的 STUN 观察点；没有借用通话专属 TURN 凭据，也未新增 TURN 凭据接口。需要中继时仍由现有 SuperVM 路径承担，不把它写成 RTC TURN 传输。此接入没有消除账号、关系权限及现有信令的服务端依赖，不代表完全去中心化部署。

双方在已授权、已加密的 peer lane 中交换 hello，按公钥字典序选择唯一 offerer。协商使用独立保留 stream，SDP/候选先分片再由原生通道加密；数据通道里的业务帧也继续使用原生加密信封及共享重放防御。每条协商消息最多 32 KiB，分片512字节，四条未完成重组、10秒过期、有界重复ID记录。SDP/候选不写磁盘、不输出日志。

初始 SDP 最多等待五秒收集，随后新候选可分批继续交付；每轮最多64个候选。协商超时20秒后关闭该轮，30秒冷却重试。数据通道仅承载二进制帧，发送缓存超过64 KiB便回退；原生发送等待有界，业务停滞回馈关闭该通道并进入冷却。账号/父通道结束时关闭和释放原生 peer，迟到创建结果也释放。诊断仅记录已选 candidate pair 类型、协议及计数，未知类型不标记为 direct。

## 检查

本次13项检查通过：信令乱序/重复/冲突/过期/容量与非法输入，创建期间关闭后释放迟到原生对象，以及真实 NovoRUDP 原生加密信令协商、二进制业务帧、跨载体共享重放拒绝、迟到候选、发送拥堵和异常回退；包含既有路由重建、文件停滞检查。数据通道测试的 RTC 对象是可控替身，用于验证编排；没有把这些结果当作手机 WebRTC/NAT 穿透实测。最终构建与双机结果另记。

参考：[W3C RTCDataChannel](https://www.w3.org/TR/webrtc/#rtcdatachannel)、[flutter_webrtc 数据通道 API](https://flutter-webrtc.org/docs/flutter-webrtc/api-docs/rtc-data-channel/)。

## A/B 安装与首轮实机检查

代码 d33661c5 的 arm64 profile 预览包已在隔离工作树构建，并以覆盖方式安装到 A/B；未清除用户数据。APK SHA256：`63C59849A01E1C3BEB00D14F35893756BB1F3F4886BCDD8FC82C864B570C5E1D`。启用原生 UDP、ICE、SuperVM WSS、点对点附件及群附件，沿用既有测试接口和信任公钥。

B 完成原测试会员登录后，A 移动网络、B 家庭 Wi-Fi 双向发送 `ICE-A-0925-0435` / `ICE-B-0925-0436`；两端均看到对方测试消息，发送端显示已读。历史消息保留。此结果证明新版消息可用，不证明使用 ICE 直连。

B 原生日志显示数据 ICE 候选收集启动，但约25秒后关闭，随后重试；没有已选成功 candidate pair 的证据。继续补充仅阶段/错误类型的预览诊断，定位协商停点；不将当前网络标为直连成功，不重复更改光猫/AP。
