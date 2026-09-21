# B 家庭 Wi-Fi 不同来源端口的入站对照

保留原网络。独立 Android shell 诊断 socket 先联系自有 STUN UDP 3478，随后保持同一个 socket；协调器通过 SSH 让同一服务器从临时端口发送三次随机 16 字节探测。手机只认同一服务器 IP、不同端口且 token 完全匹配的包。最后用原 socket 重做 STUN。

首次：服务器 sendto 成功，B 未收到异端口探测，前后 STUN 成功且映射一致。补充服务器出口抓包后再次执行：

- SERVER_SEND=true
- SERVER_EGRESS_CAPTURED=true（只匹配本次源端口/目标地址/目标端口，单包抓取至 /dev/null，不保留地址或载荷）
- baseline=true
- alternatePortReceived=false
- baselineAfter=true
- mappingStable=true

这将现象缩小到：服务器出口已经出现探测，而 B 的诊断 socket 未收到；原已联系端口的收发正常。与先前 A 的目标相关 IP/端口映射差异结合，符合“对方实际来源与预期不同，入站路径未放行”的可能性。

仍不能断言具体由家庭路由器或运营商哪一级丢弃，也不能排除协议识别过滤；未做完整 RFC 5780 分类，测试不是聊天 socket 抓包。没有把这一结果当成所有打洞方式都不可能的证明。实际公网 UDP 直连仍未通过，中继继续正常使用。

未修改路由器、防火墙或服务配置，没有新增公网监听；手机临时 dex 已清理。脚本仅输出布尔汇总，映射地址和随机 token 仅在子进程管道中用于本次协调。
