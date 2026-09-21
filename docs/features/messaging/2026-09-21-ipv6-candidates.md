# IPv6 候选路径

当前 IPv4 STUN 路径保留，额外绑定 IPv6 UDP socket。仅通过已认证成员通道通报最多两个全球单播 IPv6 地址及端口；旧端忽略新增字段。IPv6 与 IPv4 候选均需现有加密 challenge/response，先通过的健康路径保持使用，发送失败继续现有中继回退。本地接口地址变化清空旧候选与探测状态。IPv6 初始绑定失败不影响 IPv4。

不通报链路本地、ULA、组播、IPv4 mapped 和文档 IPv6；不需要 STUN 才能通报本机全球 IPv6，但全球地址本身不代表防火墙允许入站。该实现不是完整 ICE，也不宣称等同微信私有选路算法。

验证：IPv6 候选过滤、数量/端口边界、重复候选和未经回程确认不可用测试；现有原生安全会话端口学习、STUN、nonce 回归。IPv6 候选测试不向外部地址发送报文，不构成真实 IPv6 载荷传输证据。当前电脑与 B 手机都只有链路本地 IPv6，不能在这套拓扑完成双机全球 IPv6 验收。手机仍安装 e8175015，本次代码尚未安装。

后续仍需验证实际双端 IPv6 加密数据传输与网络接口切换；本次新增候选不能关闭公网直连验收项。

故障隔离补充：IPv6 socket 运行中关闭/报错，只撤回 IPv6 候选并使旧探测失效，继续保持 IPv4 socket 和成员安全会话；后续探测可恢复 IPv4。初始绑定失败和运行中关闭均有真实 socket 生命周期回归，不能因为可选 IPv6 故障关闭整个直连通道。

## 464b709b 双机安装

A、B 覆盖安装成功，profile APK SHA-256 为 `7eac9a30811dd34d95578e656ba9646d4ad9b04b5ec41bf794118cd629bbdb0c`。
双向实际消息 `398de3f3-0e4b-44c6-a157-9f8bb1aa6d6a` 与 `2adc5ec3-416c-4a23-8ef3-529b6029878d` 均进入两端 peer journal，A 界面显示两条测试标记。
两端直连 ready=false，不能算 UDP 验收。B 仍只有链路本地 IPv6；A 系统网卡有全球 IPv6，但 B 的候选诊断 ipv6Candidates=0，客户端 IPv6 发现/通报是否生效仍待定位。新增 profile 诊断只输出 socket 可用性、本地候选数量和错误码，不输出地址或内容。

## cb8f7fc7 诊断结果与 UDP 错误处理

两端已安装诊断版。实际消息 `d2065e94-0bc0-4730-aaf4-9d3eb8967079` 两端 peer journal 一致，发送端 delivered=1。
A 报告 ipv6Socket=true、localIpv6=2；B 报告 ipv6Socket=false、localIpv6=0。这排除了 A 未发现地址的猜测，但并不证明 IPv6 直连。

代码检查发现 RawDatagramSocket 的所有 onError 都会退役 socket，而 UDP 的 SocketException 也可能仅表示某个目的地 ICMP 不可达。改为保留 socket，必要时使当前路径不再被视为健康，按既有定时器重新探测；仅 closed/onDone 或非 socket 错误退役。增加注入 network-unreachable 错误后仍会探测新 IPv6 候选的回归，连同四项原有 IPv6 测试通过。B 实机恢复候选仍待新构建验证，不能仅由上述计数断言已捕获其具体系统错误。

## bcfb0f9b 实机纠正

两端安装 APK `245e294ec45d1c2e75a0cf0b8cfe1bc4fab885d64007036d7cc406a638f92115`。
双向消息 `30e13fa7-73bb-4254-8e1b-95d9d65a9ab0`、`a427b9c6-c597-48c1-8bd4-ac07f94a3c15` 两端 journal 一致，发送方 delivered=1。B 仍显示 ipv6Socket=false，上一版不能视为实机恢复通过。

检查当前 Dart SDK `_RawDatagramSocket` 发现其 error handler 在 addError 后主动关闭底层 socket。因此单纯应用 onError 不关闭并不能阻止 SDK 关闭；原来的注入测试只覆盖应用回调，没有覆盖 SDK 生命周期。

修正为无本机全球 IPv6 时不探测远端 IPv6；全局地址重新出现时，按已有接口刷新周期重新绑定失败的 IPv6 socket 并通报新端口。旧 socket 订阅及时移除，迟到回调不会复活旧路径。新增真实 IPv6 socket 关闭→重新绑定测试，保留 IPv4 端口不变；地址发现由测试注入，不宣称具有公网 IPv6。相关七项测试通过，仍待双机新构建验证。
