# 大附件自适应下载与离线持久化

沿用两台手机已经安装的 e4311df5 聊天预览包，未重新安装、清除应用数据或更改路由器。B 使用家庭 Wi-Fi，A 使用移动数据。仅发送生成的测试文件。

## 实机结果

- B 发送 `Recovery-8MB-0925.bin`，大小 8,388,608 字节，A 收到文件卡片。
- 原文件 SHA256：`7D212B9C884F5C77896DE960AE17CC341CDA43B14D6A971F34CA29EBD4BADF7F`。
- A 点击“读取文件”后先尝试 peer 通道；日志出现 `PeerDownload slow-relay HTTP handoff`，随后 HTTP 完成下载，页面显示“下载完成，文件校验通过”。
- peer 阶段结束记录 `elapsedMs=12749`，`udpFrames=0 udpBytes=0 relayFrames=797 relayBytes=777872`。该耗时是 peer 阶段，不是完整下载耗时；relay 为旧的非 UDP 分类，不能凭这一行断言具体承载协议。
- peer 阶段收到的字节不足一个 1MiB 持久化分块。这轮证明慢路径自动回退及最终校验成功，**不证明实机复用了跨路径完整分块**，也不证明公网 UDP 直连成功。
- 关闭 A 的移动数据（Wi-Fi 原本关闭），强制停止并重新启动聊天应用。离线聊天列表和历史记录仍可打开；再次读取同一文件，页面显示“已从本地读取，文件校验通过”。这证明文件跨进程持久化可用，而非仅依靠进程内存。
- 完成后已恢复 A 移动数据，返回聊天页；B Wi-Fi 保持开启。没有导出到公共下载目录。

本机证据位于忽略目录 `build/`：`a-large-progress.xml`、`large-a-safe.log`、`a-offline-list.xml`、`a-offline-history.xml`、`a-offline-file-result.xml`。其中 a-large-progress.xml 是在线完成状态。

## 分块回归与边界

批量运行 `test/udp_http_handoff_test.dart` 和 `test/chat_download_resume_test.dart`，46 项全部通过，用时约 3 分 40 秒。日志：`build/handoff-resume-0926.log`。

这些测试检查实际请求的分块索引与最终文件字节，覆盖 peer→HTTP、HTTP→peer、慢中继回退、下载对象重建后的加密缓存恢复，以及损坏缓存、权限撤销和离开页面。媒体路径涵盖文件、图片、缩略图、语音、视频与 HEVC。测试通道与服务响应受控，不能冒充双机公网穿透或真实媒体播放验收。

仍待完成：双机传输中断后完整分块复用的实机证据、公网直连成功证据、锁屏及后台行为、各媒体播放与交互的完整实机验收。本轮未改动应用或 SuperVM 协议代码。
