# 单设备原生 WebRTC 回环验证

目的：使用生产 CallMediaSession / NativeCallMedia 和安装版本 flutter_webrtc 的真实 Android SDK，在同一手机创建两个 peer。信令由本地合成仓库交换，不访问账号、聊天服务或真实联系人。capture 注入空 MediaStream，不调用 getUserMedia；calltest 独立包名且移除摄像头、录音与定位权限。

构建：`flutter build apk --profile --flavor calltest --target tool/call_loopback_main.dart --target-platform android-arm64`。生成 `build/app/outputs/flutter-apk/app-calltest-profile.apk`，仅安装到授权测试设备的 `com.lingmei.kingclub.calltest`，不得覆盖 preview 包。

验收证据必须同时包含本次进程的 `KINGCLUB_RTC_PROBE_INITIAL_BIDIRECTIONAL_PASSED`、`KINGCLUB_RTC_PROBE_RESTART_BIDIRECTIONAL_PASSED`、`KINGCLUB_RTC_PROBE_CLEANUP_FINISHED`，且无 FAILED。检查实际 offer 的 ICE ufrag 改变、双方代次递增、重启前后 data channel 双向消息可达且 peer/data channel/空流不重建。不得输出 SDP、ICE 地址或凭据。测试后移除独立探针包，保留原 preview 数据。

边界：没有声称音视频 RTP、音质、实际摄像、NAT 穿透、中继、公网网络切换或长通话已验证。中继配置变更使用本地不可用端口，host ICE 提供实际回环通路；该结果绝不是 TURN 可用性证据。

状态：profile arm64 构建成功，35.0 秒，133.4 MB；工具文件 analyze 无问题。APK SHA256 `78eb574dded90dfd95f05481abd62909583e964f63693a188db153615bec4a96`。aapt 核对包名正确，最终 APK 不含 RECORD_AUDIO/CAMERA/定位权限。

安装命令正在等待测试手机的系统安装确认，设备锁屏且前台为系统安装引导层；已请用户解锁确认。此时尚无安装 Success，也未获得回环 PASS 日志。不得把构建成功计为 SDK 实测。


## 2026-09-14 Android 实机回环结果
用户确认安装并打开独立 com.lingmei.kingclub.calltest。ADB 从该包当前进程读取固定测试标记：INITIAL_BIDIRECTIONAL_PASSED、RESTART_BIDIRECTIONAL_PASSED、CLEANUP_FINISHED 全部出现（设备日志 12:26:24），无本次失败标记。用户屏幕显示 CLEANUP_FINISHED，与释放连接后的最终状态一致。

证据范围：同一台 Android 的两个原生 WebRTC peer、DataChannel 双向字节传输及 ICE restart 后继续传输；测试使用合成信令与空媒体流，没有采集麦克风或摄像头。不是两台手机语音视频通话、真实公网 NAT/TURN、后台保活或主网 NovoRUDP 验收。测试资源关闭后清理独立测试包，正式 APP 保留。

## 2026-09-14 公网中继复核（晚间）

- 当前 kingclub-turn-test 进程存活，3478 UDP/TCP、5349 TCP 已监听；主机 UFW 已放行这些端口及 49160–49200 UDP。
- 服务器内部 TLS 检查保留主机名与证书链校验，Verification OK / Verify return code 0。
- Windows DNS 将 test.wuyexin.cn 解析到 198.18.0.33（代理地址），服务器解析与配置 external-ip 均为 47.103.59.206。代理路径仅 TCP connect 成功，但既有 probe-turn-public.py 收到 TCP EOF、TLS SSL EOF，UDP 超时；不能据 TCP connect 判定 TURN 可用。
- 将 TCP/TLS 的连接地址定向到配置公网 IP，同时仍使用 test.wuyexin.cn 校验 TLS 主机名：TCP 超时、TLS 连接重置；公网 IP UDP 超时。电脑代理仍可能影响路由，此结果不足以归因云安全组。
- 没有调整电脑代理、DNS、云安全组或服务器防火墙；没有生成/输出中继密钥，也没有发起真人通话。已询问测试手机是否启用 VPN/代理，双手机公网音视频仍未验收。
