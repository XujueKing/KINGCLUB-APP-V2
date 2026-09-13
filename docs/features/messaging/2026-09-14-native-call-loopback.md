# 单设备原生 WebRTC 回环验证

目的：使用生产 CallMediaSession / NativeCallMedia 和安装版本 flutter_webrtc 的真实 Android SDK，在同一手机创建两个 peer。信令由本地合成仓库交换，不访问账号、聊天服务或真实联系人。capture 注入空 MediaStream，不调用 getUserMedia；calltest 独立包名且移除摄像头、录音与定位权限。

构建：`flutter build apk --profile --flavor calltest --target tool/call_loopback_main.dart --target-platform android-arm64`。生成 `build/app/outputs/flutter-apk/app-calltest-profile.apk`，仅安装到授权测试设备的 `com.lingmei.kingclub.calltest`，不得覆盖 preview 包。

验收证据必须同时包含本次进程的 `KINGCLUB_RTC_PROBE_INITIAL_BIDIRECTIONAL_PASSED`、`KINGCLUB_RTC_PROBE_RESTART_BIDIRECTIONAL_PASSED`、`KINGCLUB_RTC_PROBE_CLEANUP_FINISHED`，且无 FAILED。检查实际 offer 的 ICE ufrag 改变、双方代次递增、重启前后 data channel 双向消息可达且 peer/data channel/空流不重建。不得输出 SDP、ICE 地址或凭据。测试后移除独立探针包，保留原 preview 数据。

边界：没有声称音视频 RTP、音质、实际摄像、NAT 穿透、中继、公网网络切换或长通话已验证。中继配置变更使用本地不可用端口，host ICE 提供实际回环通路；该结果绝不是 TURN 可用性证据。

状态：profile arm64 构建成功，35.0 秒，133.4 MB；工具文件 analyze 无问题。APK SHA256 `78eb574dded90dfd95f05481abd62909583e964f63693a188db153615bec4a96`。aapt 核对包名正确，最终 APK 不含 RECORD_AUDIO/CAMERA/定位权限。

安装命令正在等待测试手机的系统安装确认，设备锁屏且前台为系统安装引导层；已请用户解锁确认。此时尚无安装 Success，也未获得回环 PASS 日志。不得把构建成功计为 SDK 实测。
