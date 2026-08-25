# WebSocket Mock/Fake 场景

| ID | 场景 |
|---|---|
| RT-M01 | 前台建立单连接并收到 ready |
| RT-M02 | 重复 connect 复用同一 SingleFlight |
| RT-M03 | 网络断开、指数退避、重连和 cursor 补拉 |
| RT-M04 | 进入后台停止，回前台重新鉴权恢复 |
| RT-M05 | 心跳协商与连续超时断线 |
| RT-M06 | 重复 eventId 只消费一次 |
| RT-M07 | 乱序消息事件经 API 版本收口 |
| RT-M08 | 未授权/过期 ChannelRef 被拒绝 |
| RT-M09 | session revoked 停止重连并 reset |
| RT-M10 | 旧 generation 迟到 ready/event 被丢弃 |
| RT-M11 | 推送点击后重新鉴权和补拉 |
| RT-M12 | 日志和错误报告脱敏 |
