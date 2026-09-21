# A 的相邻端口预测前提检查

沿用原网络与已授权服务器，对 3478/41000 做四次独立 socket 对照。每次
同 socket 先查 STUN、发送三个随机诊断包到 41000、回查 STUN；服务器按
随机标记匹配入站包，仅输出端口差值区间，不输出端点。

四次均实际收到诊断包，sameAddress=true、samePort=false，端口绝对差值
均为 over1024，baselineAfter=true、mappingStable=true。临时 dex 已清理，
没有修改 A/B 网络、安装包、服务器入口或中继。

结论只限于：样本不支持围绕 STUN 端口 ±8/±64 扫描就能命中的假设。
没有验证同一 socket 连续多个目标的分配序列，不声称所有分配都是随机，
也不声称服务器目标的 IP 能代表 A 面向 B 的公网 IP。

下一可评估方向是协调多套接字/随机探测（birthday-style），而非无限增大
当前单套接字重试频率。它要求双方交换经认证的候选、限定目标与总预算、
只有双向挑战通过才采用路径、失败彻底清理并保留中继。A 面向不同目标会
出现不同公网 IP，仍是这种方法的重要限制。本节点未实现此方法，未宣称
实际聊天直连成功。

技术依据（方案说明不等于对本拓扑的成功保证）：
https://tailscale.com/blog/how-nat-traversal-works （The benefits of birthdays）。
