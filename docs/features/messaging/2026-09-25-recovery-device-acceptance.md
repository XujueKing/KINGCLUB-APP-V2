# A/B 恢复与小附件实机验证

2026-09-25，将代码 e4311df5 的隔离聊天预览包覆盖安装到 A、B，两个安装均成功，未清空应用数据。B 安装前由用户重新登录，安装后两端均保留会话历史。包为 Flutter profile、原生 Rust release。

APK SHA256：`F4169252BF73554C212CFA677ABEE403A9A5DAE5D03E07800811B6FB0D0E99CF`。

| 操作 | 实际结果 | 证据与边界 |
|---|---|---|
| B 发送 Recovery-route-0925 | A 收到并落盘，B 收到持久化回执 | A `received_persisted carriers=supervmRelay`，B `durable_receipt carrier=supervmRelay`，随后 `service_response carrier=ccsop`。不是纯直连，也不是完全绕过服务端 |
| 关闭 B Wi-Fi 后发送 Recovery-offline-0925 | B 显示等待网络恢复；打开 Wi-Fi 后自动补发，A 显示消息，B 显示已读 | 此次补发有 CCSOP 返回，没有对应的 peer 落盘日志，不能将其归因于中继重连唤醒 |
| 恢复后 B 再发送 Recovery-online-0925 | A 显示消息，B 已读；SuperVM 中继重新可用 | 再次出现 A 中继落盘、B 中继持久化回执及 CCSOP 返回 |
| B 选择并发送生成的 Recovery-file-0925.txt，A 点击读取文件 | A 显示“下载完成，文件校验通过” | 文件 39,000 字节；`PeerReceive routes udpFrames=0 udpBytes=0 relayFrames=40 relayBytes=39000`。旧统计中的 relay 包括非直连分类，未进一步断言具体载体 |

B Wi-Fi 已恢复开启，A 返回聊天页。仅使用生成的测试文本文件，没有选择用户私人图片或视频。测试消息与文件保留作验收证据。

断网期间 B 出现 `NOVORUDP_RELAY_CONNECT_FAILURE AuthFailure`，现有日志只提供异常类，不能判断是网络失败还是具体鉴权拒绝；后续正常恢复无需再次登录。本轮没有记录准确的恢复延迟，不能宣称秒级恢复。小文件通过不等于大附件或断点续传的实机验收通过。

未完成的验证：A/B 公网直连、大附件跨路径续传、锁屏/系统后台行为、各种媒体的批量实机验收。此前本机 18MB release 回归与本次手机小文件测试必须分别报告。
