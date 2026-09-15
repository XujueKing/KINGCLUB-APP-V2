# 原生聊天交付矩阵（2026-09-15当前核查）

## 2026-09-15 15:20 双机通话历史已补齐并实测

后端新增 112 通话历史迁移，结束事务同时生成持久聊天记录与双方通知。复用现有文本展示，兼容当前已安装 APK，无需重打包。完成接听后显示服务端计算的时长，未接听、取消、拒绝等显示对应结果；重复动作不重复生成，不改变好友许可或扣经验值。专用通话卡片与点击回拨尚未实现。

已核对并补回本日两次旧测试通话，旧连接时间没有保存，因此只显示通话已结束。修复发布后双机再次真实接通、挂断：双方聊天均显示“语音通话 · 00:15”和“视频通话 · 00:29”；B 会话预览和未读气泡更新，重新进入会话读取正常。后端 92 个文件共 378 项测试、隔离 MySQL 事务验证和在线运行检查通过。

发布回归曾发现基础 env 缺少旧容器的 TURN 覆盖参数；已恢复旧容器并修正发布脚本，最终完整继承有效运行配置，预检查中继配置后重新发布，并通过上述双机接通测试。

此前用户确认视频双向实时画面与声音正常；啸叫仅在两台手机靠近且同时外放时出现，属于本次测试的声学反馈条件，未据此声称所有降噪/回声场景验收完成。当前实测仍限同一 Wi-Fi、前台双机，不代表跨网络、后台、主网路由或群通话已验收。

## 2026-09-15 14:55 双机语音首次实测通过

A 从与 B 的会话发起语音，B 接听，两端显示通话中。用户明确确认“双方都能听到”。原生 WebRTC 日志显示远端轨道、DTLS 握手完成与 CONNECTED。B 挂断后返回通讯录，A 同步显示“通话已结束 · 01:03”。本次为两台已登录安卓、同一 Wi-Fi、前台语音；尚不代表跨运营商/弱网/后台/长通话完成。

同时观察到公网 TURN 候选连接超时，当前连接成功不能证明公网中继可用；也不能将 WebRTC 通话认定为 NovoRUDP 主网承载。视频通话随后进入实测，结果另记。

## 2026-09-15 14:52 角标修正版安装与重启复验

- 修正提交 `8d1cc6b` 已推送 XujueKing/main 并核对远端。Profile/preview ARM64 构建 96.1 秒，原生 ELF 检查通过；包含已有三处 onboarding 工作区修改，未将它们纳入本次提交。
- APK SHA256：`633c7fbf6c0a3ff1e5ac4adb905a007b2a3fd1a81a020ef01f0e6aebb6a93e72`。A 14:51:53、B 14:52:00 覆盖安装 Success，两端冷启动成功，当前进程 fatal/unhandled/native-link 错误匹配均为 0。
- 安装前 B 在真实会话发送 `TEST-B-TO-A-1451`，A 停留首页时底栏显示 1，会话列表同时显示未读 1。安装冷启动后 A 仍能读取三条历史，打开后未读清零；B 冷启动进入通讯录仍显示 A 的真实头像与资料。安装前两端通讯录都已确认列出对方。
- 待处理申请已经由用户接受，未为重新展示角标而删除好友或改写申请。新申请的顶部/底栏联动已通过定向自动化，但安装后的真实新申请角标仍待下一次申请复验。通话、群聊、去中心化路由验收不因本次文字通过而完成。

## 2026-09-15 14:47 双机扫码与首次消息

- 用户明确授权仅 A、B 测试会员之间执行好友申请、测试消息和通话邀请。B 扫描 A 个人二维码并发出申请，A 的“新的朋友”显示 1；用户在 A 点击接受后显示“已添加”。
- 双端截图确认 A 的“你好”到达 B，B 的表情回复到达 A，双方显示各自真实头像。仅证明这次在线双向消息，不等同于语音、视频、离线恢复或去中心化通道验收。
- 用户发现申请仅在“新的朋友”显示角标。修正为 ContactsController 同一个待处理入站申请数量同时更新通讯录标签与底栏消息总角标，处理/会话切换后清零；网络暂时失败保留最后确认数量，已处理和本人发出的申请不计入。
- 定向验证：联系人与 Shell 共 21 项测试通过，覆盖数量向上层传播及清零；本次修改尚待安装，不把自动化结果当成手机角标复验。
- 当前双机安装为 14:37 的字体适配版本，详见 app_layout/2026-09-15-text-scale.md；下文 14:25/12:29 是历史安装记录。

## 2026-09-15 14:25 A/B installation update

This entry supersedes earlier installation records. User designated the original PCLM50 as A and new PKL110 as B. Built the 55c57f4 worktree (including the three preserved, uncommitted onboarding edits) in profile/preview ARM64 mode with the real test API. Gradle took 69.1 seconds; APK size 157003848 bytes; SHA256 f4f5cdca82e75480ef365bcfd32e94633369e4954307afd8f20a171f0aea7d47. Native ARM64 packaging verification passed.

Explicit-serial ADB install -r returned Success on both devices. Package timestamps: A 14:24:54; B 14:25:24. Both start commands returned ok and both package processes were present. Startup error-pattern counts were zero for each current process. A data was preserved; B was a new preview installation. This is installation/startup evidence, not chat acceptance. B must log in with a separate test member before actual dual-account chat verification.

Both phones independently reached the actual local SUPERVM signed NAT observer and punch responder over Wi-Fi (responses verified on the computer). The App relay carrier also passed the actual WSS daemon test on the computer. Automatic App route selection, two-phone encrypted peer chat and media acceptance are still pending; new standalone transport classes are not claimed as active App routes.


## 2026-09-15 12:29 当前手机安装版本

本记录优先于下文历史安装状态。ec26f6c 工作区已构建并覆盖安装到测试安卓，保留 onboarding 三文件未提交修改。Profile/preview ARM64、真实测试 API；Gradle 65.7 秒，APK 157003848 字节，SHA256 3cbc23a7ac59c2cd1d4765b7dfe3a06636e64b3d2489241e3b81d16e9c9ce9d6，NovoRUDP ARM64 ELF 检查通过。

ADB install -r Success，lastUpdateTime 2026-09-15 12:29:59。首次 am start 返回 ok 后未查到进程，未据此判定启动验收；再次启动返回 ok，随后两次查到进程，当前进程日志 FATAL EXCEPTION / Unhandled Exception / UnsatisfiedLinkError 匹配数为 0。尚未验证实际页面交互与手机流畅度。

本包包含群通话摄像头切换、扬声器控制、邀请过期、TURN 续签、ICE 重连与媒体列表网络错误宽限等客户端修改。语音播放、视频发送生命周期、单人通话媒体回归合计 33 项通过；群媒体与会话相关 28 项通过。均不能替代真实双机验收。在线群通话服务仍未发布，视频本次新发送结果仍待确认。

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
| 群语音/视频通话 | 已接群成员选择、前台邀请接听/拒绝、原生媒体会话、静音、摄像头/免提控制及授权头像；服务端mediasoup及678–682信令在隔离环境验证 | 未交付：在线媒体服务/接口未启用，TURN与真实多机声音/视频未验证；后台持续通话、系统来电仍缺失。SDK替代对象测试不算实际媒体验收 |
| 语音转文字/语音输入 | 674本人录音、675单/群消息识别及编辑/查看入口已实现；隔离MySQL+加密HTTP+真实中文模型通过，隐藏/撤回拒绝已验证 | 未交付：在线服务未发布；手机入口已更新；长录音、自然噪声、并发容量及双机验收待补 |
| 金币/红包/礼物/卡券 | 部分展示入口，卡券分享暂未开放 | 真实资产事务及完整业务未完成，不算可用聊天附件 |
| 系统/锁屏来电推送 | 用户此前同意后置 | 仍未完成，保留在总目标中 |
| 加密与NovoRUDP | Rust签名/握手/AEAD、分片补传、设备绑定API；后台绑定入口已安装 | 手机登记结果未确认；高频worker、可信信令、NAT/中继/服务端自适应、跨进程续传未接齐，完整聊天端到端加密未完成 |

## 当前代码与手机版本

当前手机安装记录为2026-09-15 11:50:56，基于4f02f9b工作区的Profile/preview包，包含群通话前台入口、媒体收发与会话状态绑定。后续续租门控、摄像头/免提、邀请过期关闭、成员头像等修复已提交但尚未安装。APK SHA256为26a56ceb20733c9dd0940b22e4f361b2609c2a722096dbf50b253db687bec2e9；构建保留用户onboarding三文件未提交改动。安装和启动不代表实际聊天全流程验收。详细构建及逐项范围见[群通话接入记录](2026-09-15-group-call-client.md)。

本轮通过ADB重新核对上述更新时间；只读docker ps确认在线kingclub-v2-api仍使用kingclub-v2-api:network-keys-v1，未运行新群媒体服务。源代码截至ee41988。没有把隔离环境成功改写成在线发布成功；下文历史安装记录保留供追溯，当前版本以上段为准。

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

## Contacts loading regression check

Inspected the current ContactsPage/ContactsController/ContactGroupsRepository: first-entry UI does not use an artificial delay, relation groups and request counts load independently of the contact refresh, previous contact snapshots survive refresh failure, and group repository operation numbers reject stale responses after newer loads/saves. No additional loading or cache change was made without evidence of a defect.

Ran contacts_controller_test.dart, contacts_flow_test.dart and contact_groups_repository_test.dart: all 23 passed. Coverage includes account reset, incoming request count, private avatar lookup, alphabet drag, retained rows during partial failure and stale group-version rejection. Widget/demo and injected-API tests are not phone or live-interface acceptance. The earlier live SQL eligibility evidence remains separate; the user's actual missing-contact case is still awaiting handset observation.

## Unread badge display consistency

Bottom navigation now caps its visible unread number at 99, matching the conversation rows and the user requirement. Real-chat initialization already uses zero instead of demo counts; this inspection does not prove the earlier fixed badge or missing-message report resolved. Existing shell and mute widget regressions: 12 passed. No handset acceptance; not yet installed.

## Conversation refresh ordering

Conversation list requests now run sequentially. Repeated pagination shares the pending request; first-page refreshes arriving during a request are coalesced into a trailing refresh. This prevents overlapping offsets from invalidating one another and ensures updates observed while loading are fetched afterward. Existing account-generation guards remain in place.

Validation: new controlled widget test holds pagination pending, repeats load-more and tab activation, then verifies one pagination request followed by one fresh first page and replacement of old rows. Together with group routing and mute regressions, four tests passed; targeted analyze passed. This is injected API evidence, not real handset delivery. Not installed yet.

## 09:14 手机安装

- 51ea94f 工作区构建 Profile/preview ARM64，保留未提交 onboarding 三文件变更。真实测试 API；NovoRUDP ARM64 ELF 检查通过。Gradle 60.7 秒，149.2MB。
- APK SHA256: abca640b6cbfed659f1a6522d45d96b35b4401a930304d1be40950a4da6a050e。
- adb install -r Success；lastUpdateTime 2026-09-15 09:14:14；am start Status ok，WaitTime 3026ms；近期 AndroidRuntime/flutter error 过滤无输出。
- 包含顺序刷新/分页、底栏 99 上限、晚到 WebSocket 清理、缓存清除 generation 修复及 NovoRUDP 接收队列/同进程续传修复。仅设备身份绑定已接客户端，实际聊天尚未选择 UDP。
- 手机检查时处于休眠；安装启动不等于用户视频成功发送、语音可听或双机验收。在线表情云/ASR发布限制仍未解除。

## Interrupted offline catch-up regression

Added a controller test starting with sequence 1, catching up through 51, failing the next page, then resuming at 51 and completing through 131. All 131 sequences appear exactly once; an intermediate network error retains the known send permission and clears after successful catch-up. Existing implementation passed without a production code change. Direct/group controller suites: 21 passed; targeted analyze passed.

This is controlled repository-response evidence only. It does not prove actual mobile WebSocket delivery, offline server retention or the historical friend-removal report resolved.

## Invalidated native stream cleanup

NativeCallMedia now catches track enumeration failure during release and continues stream disposal, peer close/dispose and speaker reset. The cleanup error is still reported; inability to enumerate tracks is not counted as proven capture shutdown. A controlled invalidated-stream test verifies the remaining resources are released. Native media/state controller suites: 23 passed, targeted analyze passed. Not yet installed or tested on a live call.

## Retry transient history opening failure

Direct/group controllers now discard a failed history-opening Future, allowing the next synchronization to reopen storage. Successful initialization remains shared. Account checks, encryption, hidden-history revisions and existing files are retained; persistent corruption is still reported rather than silently deleting or bypassing history.

Validation: 17 history tests passed, including new first-open failure then successful synchronization and encrypted real SQLite persistence for both direct and group histories. Targeted analyze passed. Injected open failure/server replies are not Android storage failure acceptance. Not yet installed.

## Profile privacy late-response check

Added a widget regression holding an authorized content response pending, delivering a settings change with contentVisible=false, then completing the old content response. Old works remain absent, the restricted-content notice remains and private chat remains available. All five public profile tests passed. No production change was needed; this verifies client generation handling with injected replies/events, not server privacy enforcement or two-device acceptance.

## Video upload copy recovery

Video retry now checks the cached upload copy is present and nonempty before reuse. A missing or empty copy reruns preparation from the retained source; cancellation is rechecked after filesystem access. Original media is unchanged. Twelve optimizer/send-lifecycle tests passed, including actual filesystem deletion/truncation with an injected native encoder, and analyze passed. This does not establish the cause of the user's earlier interrupted upload or measure native codec quality. Not yet installed.

## 09:32 原生压缩回调与安装

ChatVideoUpload.finish 在 cancel 编码器之前递增 generation，作废已排队的旧 worker/native 回调，正常完成与失败也采用同一收尾。原生 acceptable 已验证缓存文件非空、较源文件小、时长差<=300ms及音轨存在性一致。此处为源码核查，不代表完整解码或真实音质验收。

当前工作区 Profile/preview ARM64 构建成功，Gradle87.9秒、149.2MB；真实API及ARM64库检查通过。SHA256 ee25ef156de3856cb325c28af6cb33d96ed1c9abec01a5d0f03a448d549f01e0。adb覆盖安装Success，lastUpdateTime2026-09-15 09:32:32，启动Status ok。包括群成员搜索、缓存打开重试、通话清理和视频副本恢复；仍包含未提交onboarding三文件。真实发送、播放和双机通话未验收，在线ASR/表情云未发布。

## Pending messages before history restoration

Direct/group initialization now restores the account outbox before opening history. A temporary history failure no longer prevents pending messages from appearing. Recovery tests include a pending message and prove subsequent matching history acknowledgement reconciles it once and removes its queue entry. Thirty-eight history/controller tests passed; targeted analyze passed. Existing membership checks remain. Not yet installed; controlled storage/API fixtures are not handset restart delivery acceptance.
