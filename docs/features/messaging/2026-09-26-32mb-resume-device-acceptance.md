# 32MiB 实机中断续传

2026-09-26，A 使用新增 FileResume 观察日志的聊天预览包，B 沿用原包。A USB 授权恢复后，两机均在线；用户确认 B 独占聊天联调并完成登录。未操作第三台设备，未修改路由器或登录规则。

## 操作及结果

1. B 通过聊天“文件”入口选择生成的 `Resume-32MB-0926.bin` 并发送。文件大小 33,554,432 字节，A 收到卡片，B 显示已读。
2. A 开始读取。peer 阶段约 9,665ms 后超时，接收计数为零，然后进入 HTTP 路径。本轮没有公网直连成功证据。
3. 观察到 HTTP 分块 0、1 完整写入且保存后，关闭 A 移动数据并退出文件页。中断标记为 `TEST_INTERRUPTION data_disabled_and_page_closed_after_block_1`；读取系统设置确认移动数据为 0。
4. 恢复 A 移动数据，重新打开同一文件并读取。
5. 分块 0、1 均记录 `cached=true bytes=1048576`，其余分块由网络读取。最终日志：`FileResume phase=verified bytes=33554432 reusedBlocks=2 reusedBytes=2097152`。
6. A 页面显示“下载完成，文件校验通过”。确认复用 2MiB 已保存内容，而非从零重新下载整份文件。原文件 SHA256：`E09320C5B00B34BB704802136C599A95B3996332BA84D7C7F21112B6231B6BD0`。

结束时 A 移动数据、B Wi-Fi 均为开启，A 返回会话，未删除历史、未导出文件。测试文件及消息保留。

证据：本机忽略目录 `build/resume-interrupt-safe.log`、`build/resume-result-safe.log`、`build/a-resume-reopen.xml`、`build/a-resume-result.xml`。

## 限制

此次是 HTTP→中断并离页→HTTP 的完整分块复用实机验证，不是 peer→HTTP 的实机分块复用，也不是仅断网、不离页的自动恢复验证。剩余 30MiB 为成功组装的网络分块量，不声称精确线路流量（协议开销与可能的在途请求另计）。此前 8MiB 离线重启读取验证独立成立。

B 在进入文件选择器前后曾出现登录页，用户再次登录后本轮发送成功。现有日志没有保留明确的会话撤销原因，不能归因于文件选择器或其它预览应用，也没有以放宽会话安全规则来绕过。
