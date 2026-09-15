# 群已读同步与语音播放

服务端group-messages.ts的read、hideMessage、settings均发送chat.group.read。旧客户端收到当前群该事件立即stop，因此另一个端的正常已读同步也会打断语音。不能直接忽略事件，否则隐藏消息不会终止播放。

客户端改为对当前消息调用已有voiceMedia权限接口；授权仍有效时不重启/停止播放器，拒绝或网络失败则停止。相同播放代次并发核验合并；迟到失败不停止下一段语音。群成员/关系变化原有立即停止逻辑保留，无关群事件仍忽略。服务端无需升级。

8项播放控制器测试通过，新增用例确认同群已读保留播放、隐藏后的权限拒绝停止。测试使用受控接口/音频输出，不是双机扬声器验收。定向analyze通过。本批代码待下一次安装包交付，未宣称解决此前源录音静音问题。

补充并发修复：请求进行时的新事件只增加修订号，当前请求结束后若修订号改变则再核验一次；连续事件合并但不丢失最新权限变化。新增测试固定旧授权响应延迟，期间发送两次隐藏同步，确认不会并发堆积且旧授权返回后重新核验并停止。当前9项测试与analyze通过，仍待随包安装。

安装更新：59b0bf4代码对应profile/preview ARM64包已adb install -r Success并启动Status ok；构建63.2秒、149.0MB，SHA256 0169e74acaea6bc36f9d51e2ccc63f604054d2ce96a72b60d62ee4365ae7235f。包含群语音权限同步修复及实际视频上传大小提示；此前待安装状态以本记录为准。实机发送/播放验收仍未确认。

## Direct conversation event scope

Playback now receives its conversationId from the active chat controller. Scoped direct settings/relationship events for another conversation no longer stop the current direct or group audio. The backend outbox includes conversationId for these direct events. Matching events still stop immediately; unscoped events keep the conservative existing behavior. Group access events, session changes and permission rechecks remain unchanged.

Validation: targeted analyze passed; all 11 playback tests passed. Added direct/group cases prove unrelated direct events preserve playback and matching access events still stop it. This fixes an identified interruption path; it does not establish that this caused the user's earlier silent recording, nor prove native audio audibility or route behavior. Not included in the installed 08:29 APK.

## Rejected audio cache recovery

If native play throws, stop the partially started output and evict only that account's immutable voice cache entry. A later tap follows the normal authorization and download flow again; it cannot bypass access checks or indefinitely reuse the rejected file. Cache eviction derives the internal hashed path from scope/content identity/media kind, waits for that entry's active load and respects cache-generation changes. It does not accept an arbitrary path. Permission/network failures before play do not evict media.

Validation: analyze passed and 18 playback/cache tests passed. New coverage verifies decoder failure, stop, targeted eviction, a successful re-authorized retry, and preserving another account's cached audio. This is recovery behavior, not evidence that the user's prior silent clip was corrupted or that native audio routing is correct. Not yet installed.
