# 原生聊天交付矩阵（2026-09-15当前核查）

不能把有入口、实现了控制器、受控HTTP测试通过或APK安装成功等同于双机真实交付。下表保留全部目标范围；“待验收”不是完成。普通聊天免费，不扣经验值，已确认UI保持。

| 功能 | 当前实现证据 | 未完成或未验收项 |
| --- | --- | --- |
| 文字单聊 | direct_chat_controller.dart含发送、同步、历史、重试、已读 | 两端实时到达、退后台/重进、断网重试与角标最终一致仍须真实验收 |
| 好友资料/头像 | 资料入口及头像相关页面/测试存在 | 用户反馈默认头像及好友丢失的双端复验未闭环 |
| 扫码加好友/互关 | qr_friend_request与friendship流程及服务端实现 | 已接受扫码关系不得变回单向；用户案例根因和双机复验未闭环 |
| 备注/分组/拉黑/仅聊天 | 联系人仓库与real_friend_remark、real_relationship_groups等测试 | 名称含real的Flutter测试仍可使用注入HTTP，不能作为真实接口证明；双端权限/作品可见性验收待补 |
| 建群/邀请/扫码申请/审核 | create_group、group_invitations、group_join_request/review页面 | 实际多账号全流程、过期/重复申请/退出重入验收待补 |
| 群管理/公告/转让/退群 | group_details、announcement、transfer/departure相关实现和测试 | 真实权限变化及跨端同步验收待补 |
| 单聊/群聊历史、撤回、隐藏 | 两个controller均有历史分页、hideMessage、recall、读游标 | 重连与多端隐藏/撤回完整验收待补 |
| 表情/图片 | 现有发送和自定义表情入口；GIF/WebP处理已有验证记录 | 自定义表情云同步代码及隔离真实 SQL/加密 HTTP/双 WebSocket 通知验证通过；在线接口尚未发布，双机恢复及手机视觉验收待补 |
| 文件 | 上传/保存/转发及续传流程存在，用户反馈File Test SAVED | 多设备完整发送下载、异常重试结果不能仅凭SAVED认定 |
| 位置 | picker、lookup、location消息及单/群队列 | 真机定位权限/选择/发送/地图打开全流程待验收 |
| 语音录制/播放 | capture、playback、draft以及单/群队列 | 用户无声问题未闭环；预览生命周期修复已装，群已读不打断修复已装，用户实机复验待补 |
| 视频消息/压缩 | 发送页调用optimizer与服务端prepare；原生编码已实现 | 用户18MB新发送结果未确认；实际压缩大小提示c3d34ab已装，尚未取得这次新视频结果 |
| 单人语音/视频通话 | native_call_media调用getUserMedia/createPeerConnection，含静音/路由/摄像头及ICE重启 | 双机真实音视频未验收；公网TURN/中继仍未验证，不把DataChannel测试算音视频完成 |
| 人声处理 | WebRTC请求echoCancellation/noiseSuppression/autoGainControl | 设备是否实际生效及噪声/回声/蓝牙场景未验收 |
| 群语音/视频通话 | 当前入口明确提示尚未接通 | 未完成 |
| 语音转文字/语音输入 | 674本人录音、675单/群消息识别及编辑/查看入口已实现；隔离MySQL+加密HTTP+真实中文模型通过，隐藏/撤回拒绝已验证 | 未交付：在线服务未发布；手机入口已更新；长录音、自然噪声、并发容量及双机验收待补 |
| 金币/红包/礼物/卡券 | 部分展示入口，卡券分享暂未开放 | 真实资产事务及完整业务未完成，不算可用聊天附件 |
| 系统/锁屏来电推送 | 用户此前同意后置 | 仍未完成，保留在总目标中 |
| 加密与NovoRUDP | Rust签名/握手/AEAD、分片补传、设备绑定API；后台绑定入口已安装 | 手机登记结果未确认；高频worker、可信信令、NAT/中继/服务端自适应、跨进程续传未接齐，完整聊天端到端加密未完成 |

## 当前代码与手机版本

当前手机已安装 8915937 工作区对应 Profile/preview ARM64 包，包含头像失败重试、视频校验和分块加密后台计算、通话失败清理修复及表情云同步客户端。表情云同步在线接口尚未发布，本机表情仍本地保留。构建时保留了用户尚未提交的 onboarding 三文件改动，因此不是纯 Git 提交快照。安装成功与启动正常不代表实际聊天全流程验收通过。

## 后续执行顺序

1. 合并安装当前群语音/视频大小修复，核对设备后台登记；重现用户18MB发送及收到语音的真实表现。
2. 用两测试账号闭环扫码互关、头像、消息到达、重进保留、角标与历史同步；优先解决用户已报告问题。
3. 完成单人音视频实际媒体及公网TURN连通验收，随后推进群通话与语音转文字真实实现。
4. 完成剩余资产消息、表情同步和系统推送，推进NovoRUDP可信会话/worker/自适应集成，不以普通服务器聊天可用替代完整目标。

本矩阵依据当前源码入口、控制器与已记录验证范围，不宣称逐行端到端通过。后续每一项以真实验收证据更新，不给虚假完成百分比。

安装更新：59b0bf4代码对应profile/preview ARM64包已adb install -r Success并启动Status ok；构建63.2秒、149.0MB，SHA256 0169e74acaea6bc36f9d51e2ccc63f604054d2ce96a72b60d62ee4365ae7235f。包含群语音权限同步修复及实际视频上传大小提示；此前待安装状态以本记录为准。实机发送/播放验收仍未确认。

## 语音识别接入进展

客户端bc597c8包含录音识别草稿、加号语音输入、消息长按转文字；后端db1b35c包含本人及消息识别接口102及真实隔离测试。Linux CPU单核合成短句识别4451ms，仅是该短句基准。数字全零静音绕过模型已实现，完整VAD和识别准确率仍未验收。详细证据见2026-09-15-transcription-integration.md及服务端同名开发记录。

在线发布命令被自动审批审查拒绝，返回blocked by policy且无具体原因，命令未执行。不能将独立测试容器跑通视为在线发布；该段为历史发布记录，手机当前版本以本文件最新安装记录为准。


## 07:38 手机更新实证

- 2ba651b 工作区构建：Gradle 61.4 秒、149.0 MB，Profile/preview ARM64；NovoRUDP ARM64 ELF 检查通过。
- APK SHA256：c6b2e0af74e8a563c90ed36a5ac60a8fb2528ef8924d1c58bc8243ce75dddcd3。
- adb install -r 返回 Success；包 lastUpdateTime 为 2026-09-15 07:38:17；启动 Status ok。
- 新进程启动日志未匹配 FATAL EXCEPTION / Unhandled Exception；尚未观察到设备绑定 READY，不据此宣称登记成功。
- 本次未修改在线服务。语音识别仍未发布，视频本次发送成功与压缩结果仍未确认；手机号、消息内容和媒体不写入此记录。


## 08:29 手机更新实证

- a058292 工作区构建：Gradle 63.2 秒、149.2 MB，Profile/preview ARM64；真实测试 API 配置及 NovoRUDP ARM64 ELF 检查通过。
- SHA256：1944a45c7d433e4b922367a1c56e97c7316a1ecc88ab727c205e9f26e36944dc。
- adb install -r 返回 Success；包 lastUpdateTime 为 2026-09-15 08:29:58；启动 Status ok。近期启动错误日志未匹配 FATAL EXCEPTION / Unhandled Exception。
- 构建使用现有工作区，包含未提交 onboarding 三文件修改，未更改或提交这些修改。
- 分块校验/HMAC/AES-GCM 后台计算及失败通话资源释放已在包内。手机当时锁屏，尚未取得新的视频发送、帧流畅度或音视频通话验收。
- 表情云同步客户端已在包内；676/677 及迁移103–105仅隔离测试通过，在线服务仍未发布。语音识别同样未在线发布，不算可用功能。

## 扫码关系当前只读复核

线上数据库聚合查询：现有1条accepted扫码申请对应的关系lowFollows=1、highFollows=1，双方blocked=0。关联两侧会员均为active/approved，账号active，双方kingclubChatMemberState行均存在。当前记录满足contacts查询中的互关、未拉黑、会员可用及状态行条件。本次只读，不修改关注、好友或会员记录，不输出账号及个人资料。

源码复核：resolve在同一pair事务中同时置双方follow=true；事务结束没有用旧pair对象回写关注状态。通讯录筛选同一对follow字段；客户端监听friend-request.changed和重连事件，并在回到前台刷新。资料页unfollow需要确认后显式提交。以上不能还原此前异常发生时的状态，不能宣称历史根因已修复，也不能替代手机收到列表的验证；下一步以新包中的实际通讯录显示和请求结果判断客户端问题。


## 08:50 手机更新实证

- 8915937 工作区构建 Profile/preview ARM64 成功：63.4秒、149.2MB，真实测试API地址及ARM64 NovoRUDP库检查通过；保留未提交onboarding三文件修改，不将构建称为纯提交快照。
- SHA256：13fd7360a3145943b6525d2ef98295f60e043eb0d7286538969857e6aa6ef867。
- adb install -r Success；lastUpdateTime 2026-09-15 08:50:34；启动Status ok。近期启动日志未匹配FATAL EXCEPTION / Unhandled Exception。
- 包含无关会话事件不打断语音、播放失败清除对应缓存并重新鉴权重试、表情同步记录恢复，以及NovoRUDP后台封包/解包和首轮文件发送代码。设备绑定相关10项真实DLL回归通过；UDP仍未被选为实际聊天传输。
- 手机仍处于锁屏状态，未自动录音/拍摄/发消息。语音可听性、实际视频发送和新代码手机运行效果仍待用户操作及双机验收。在线ASR/表情云接口未发布状态不变。

## WebSocket timeout ownership

The production reconnect path now owns the original native handshake after its 10-second timeout. If that handshake later succeeds, its socket is closed instead of remaining an unobserved authenticated connection. A late native failure/close failure is consumed; early failures still reach the existing bounded reconnect policy. The signed URL, encrypted event codec and old-epoch checks are unchanged.

Validation: targeted analyze and five controlled connection lifecycle tests passed (success, delayed success, delayed success with close failure, delayed failure and early failure). These tests use a socket fake to control timing, not a phone/network outage simulation. The change is not yet installed and does not by itself prove multi-device message delivery or resolve the earlier missed-message report.

## Actual delayed WebSocket upgrade check

Added an actual localhost HttpServer/WebSocket upgrade test. The server receives the HTTP request but holds its upgrade until the production connector times out; after release, the server observes the client's late socket close. No fake WebSocket is used in this case. Six connection tests and analyze pass. This validates native socket cleanup, not TLS, CCSOP authentication, handset reconnect or message catch-up.

## Cache-clear generation at request entry

MediaCache.get now captures the cache generation before asynchronous key derivation and propagates it through lookup/download. Old work is rejected before directory creation/network work and again before returning a cached file or shared pending result. Previously a request could begin before clear but adopt the new generation afterward; the cache-hit branch also lacked the final check.

Validation: 20 cache/playback tests passed; analyze passed. Added cases pause an existing private-file lookup while clearing and clear immediately after get before any network call; both old requests reject and no old cache file is returned. Controlled filesystem/network fixtures are not handset logout acceptance. Not yet installed.
