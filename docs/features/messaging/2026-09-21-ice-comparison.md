# 同网络 ICE 对照

复用实际聊天通话的 WebRTC 连接与既有信令，不增加另一套身份、测试账号或媒体上传入口。profile 构建每五秒读取已选 transport 的 candidate pair，仅输出候选类型、协议、状态和双向字节计数；不输出地址、端口、SDP、凭据或会员标识。release 不启动诊断定时器。结束通话停止采样，诊断失败不影响媒体流程。

只有已选中的 pair 才记录；仅 collected、nominated 或 succeeded 的未选候选不作为连接证据。双方计数增长与候选类型共同判断该次连接走 direct 或 relay。该结果仅代表本次 WebRTC 链路，不能作为 NovoRUDP 已直连证据；ICE 对照尚待安装联调。

## 9168c33b 双机实测

22 项定向测试通过，定向 analyze 无问题。两端安装 profile APK SHA-256 `2a07f68780aa80a0236c7d444ab711bbdc00fd1e5ad600726bf09c38c084397d`。A Wi-Fi 关闭、B Wi-Fi 开启，保持当前跨网络条件；通过实际会话的通话入口由 B 呼叫 A 并接听，没有替换信令或强制 relay 策略。

2026-09-21 18:25:00 至 18:25:25 的已选 transport 统计：

| 端 | 本地/远端 candidateType | 协议 | bytesSent | bytesReceived |
|---|---|---|---|---|
| A | relay / srflx | udp | 26850 → 145025 | 27568 → 154922 |
| B | srflx / relay | udp | 31034 → 157839 | 29739 → 146269 |

此区间双方 pair state=succeeded。结束后已点挂断。证明现有实际通话的 WebRTC ICE 在本次网络及服务器配置下选用中继，并且双向有传输；不是直连证据，也没有证明所有 NAT 穿透方式均不可行。未由真人确认本轮听感，不冒充音质验收。首两次操作因 A 停留在已结束页未及时接听，没有统计结果；这些失败不作为 ICE 失败样本。

当前 NovoRUDP 原始 UDP 路径仍 ready=false。下一步应比较候选收集/实际映射和双方探测收发，而不是因 WebRTC 使用 relay 就把自研路径认定为完整。现有 WSS 加密中继与 HTTP 降级继续承担可用性，不能标记公网直连验收完成。
