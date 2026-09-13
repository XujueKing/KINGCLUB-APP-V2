# 原生通话接入进度

完整目标仍包括真实音视频、来电/忙线/挂断/重连、后台与双机验收，本文件记录增量实现，不代表交付完成。

## Flutter 接口层

CallRepository 复用账号绑定的 MessagingRepository，接入 643 发起、644 操作、645 当前/指定通话、646 信令发送、647 游标补收。CallSnapshot 校验当前账号参与、媒体/阶段、版本和结束状态一致性；指定通话响应不允许串号。请求编号由通话操作持有，重试必须复用，不在每次网络调用时生成新编号。打开接口层不会自动拨号、接听或启动麦克风。

CallSignal 保留不可变请求字段，补收拒绝逆序/重复序号、跨通话/代次和无效游标；SDP/ICE 长度基本检查，完整信令语义仍交由服务端及原生 WebRTC。没有将服务器回执当作已建立媒体连接。

5 项客户端接口契约测试通过：失败后相同拨号请求重试、当前无通话及串账号拒绝、操作携带版本及回退拒绝、终态字段验证、信令不可变及分页游标检查。使用注入返回验证客户端逻辑，不能替代双机或真实 WebRTC；后端加密 HTTP/MySQL 验证见服务端 069 记录。

尚未完成：App 通话控制器和页面、WebRTC 插件、TURN 配置与直连回退、心跳/后台来电、共享测试部署及双机验收。原视频通话按钮仍未开放，未伪造成功状态。


## NativeCallMedia 原生媒体实现

固定 flutter_webrtc 1.6.2+hotfix.1（Android 底层 io.github.webrtc-sdk:android:150.7871.01），新增 NativeCallMedia。对象构造不采集；明确 open 后 getUserMedia，请求音频回声消除/降噪/自动增益，视频目标前摄 720p/24fps、最高 30fps；音频通话不请求视频。Unified Plan/addTrack、offer/answer、远端 SDP、最多 256 个等待 SDP 的 ICE 候选、静音、远端流和连接事件已封装。ICE 服务器由调用方注入，未硬编码公共 STUN 或长期 TURN 密钥。

close 等待正在打开的资源并停止全部媒体轨道、释放 stream、close/dispose PeerConnection；关闭后迟到采集结果释放而不建立连接。7 项媒体生命周期和接口测试通过，变更静态分析通过。测试注入模拟原生接口验证竞态与释放，不能代表麦克风/摄像头采集或双机连通已实测。Android 补 CAMERA/MODIFY_AUDIO_SETTINGS，摄像头硬件非必需；蓝牙路由和后台服务尚待专项接入。

官方参考：https://pub.dev/packages/flutter_webrtc 和 https://flutter-webrtc.org/docs/flutter-webrtc/api-docs/rtc-peerconnection/ 。目前未接通页面和控制器，TURN 未配置，实际降噪效果及前后台资源行为还需真机验证。
