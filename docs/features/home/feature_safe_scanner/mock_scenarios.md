# 安全扫码 Mock/Fake 场景

- 文档状态：`In Review`

| ID | 场景 | 预期 |
|---|---|---|
| SCAN-M01 | 首次进入未授权 | 显示用途说明，用户点击后请求 Fake 权限 |
| SCAN-M02 | 相机已授权 | 相机占位进入 active，只启动一个实例 |
| SCAN-M03 | 临时拒绝 | 显示重试和返回，不循环请求 |
| SCAN-M04 | 永久拒绝 | 仅系统设置和返回；Fake 可模拟设置回来 |
| SCAN-M05 | 扫到好友码 | resolve 后产生一次好友预览意图，不自动加好友 |
| SCAN-M06 | 扫到桌台点单码 | 只交付 scanContextRef，不信任桌名/价格 |
| SCAN-M07 | 扫到入场上下文码 | 打开入场页，不直接登记入场/出场 |
| SCAN-M08 | 员工/代理/群聊/核销码 | 显示 wrongApp/unsupported，不导航 |
| SCAN-M09 | 普通网页或动态 route | 拒绝，不打开浏览器/WebView |
| SCAN-M10 | 过期/已使用码 | 显示稳定原因，可重新扫码或返回 |
| SCAN-M11 | 离线/超时/服务不可用 | 不猜测类型；重试或重新扫码 |
| SCAN-M12 | 快速重复识别同一码 | 单一 resolver、单一导航 |
| SCAN-M13 | 解析中返回/进后台 | 取消或失效 attempt，迟到响应不导航 |
| SCAN-M14 | session/会员状态失效 | 清理 payload 和相机，全局 reset |
| SCAN-M15 | 补光灯与减少动态效果 | 状态可读；无闪烁依赖和强制动画 |
| SCAN-M16 | 200% 字体、TalkBack/VoiceOver | 说明、错误和动作完整可达 |

所有 payload、二维码画面、账号和业务对象均为合成数据。
