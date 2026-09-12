# 页面动画、媒体缓存、个人二维码

用户本轮授权真实接入。所有整页路由统一 MaterialPage / MaterialPageRoute，与注册一致；弹窗、底部面板、底栏切换保持各自语义。
媒体静态素材内置，远程文件先落磁盘再解码；图片200MB、视频800MB LRU，私有文件按会员隔离，退出清理，签名变化用不可变fileId复用。禁止直接网络图片/视频加载。
个人码由服务端加密签发，10分钟有效、绑定会员及签发会话；无每秒数据库写入。扫描仅接受KINGCLUB会员码，服务端检查双方会员状态及签发会话后返回最小公开资料。不是登录码或核销码，不自动添加好友、不执行支付。原生扫码预览返回真实昵称/头像/签名，完整好友申请流程后续独立接入。刷新保留旧有效码直到新码替换，白底连续；过期/后台不展示码。

验证：Flutter analyze无问题；缓存/原二维码/注册导航13项通过。后端185项通过，035已部署，线上health/ready/runtime全部通过；主机真实会话签发与解析返回本人、昵称与头像成功。原生扫码按 mobile_scanner 官方生命周期接入（https://pub.dev/packages/mobile_scanner），iOS未打包、双机相机扫码待实际验证。APK已构建，安装状态见后续记录。

用户追加旧版还原：依据pages/mycode/mycode.wxml/.wxss及app.wxss，480rpx身份行、80rpx头像/8rpx圆角、20rpx文字间距、40rpx下距、500rpx二维码、24rpx灰说明及30rpx上距。整体垂直居中，短屏滚动；姓名#BBB/账号及说明#747474；不显示额外大段说明和倒计时，到期前60秒续期，有效旧码连续保留。文案如实表达目前资料预览能力。

新增3项通过：旧版二维码尺寸、刷新期间旧码保留、短屏无溢出、全库路由/媒体旁路检查（后两项分别在独立测试中）。最终analyze无问题。

最终安装：preview profile APK覆盖安装Success并冷启动成功，OPPO真机打开个人二维码，已确认真实昵称、会员号、缓存头像及真实码展示；截图仅保存忽略的build目录。

密度修正：服务端改37字符Redis短期引用；App使用旧assets/legacy/aa/kingLogo.png黑色圆底白字Logo替换透明文字。新包覆盖安装Success，真机确认稀疏短码及Logo显示。2项布局测试通过，服务端185项及runtime通过；双机光学扫码仍待实测。

用户要求Logo按旧版比例放大：从68rpx改100rpx，占500rpx二维码20%；二维码及布局不变，保留H级纠错。

二维码切换反馈：手机3项动画倍率均1.0，路由本为Material；二维码异步加载时默认快照可能只捕获空背景。个人码路由明确MaterialPage并关闭快照，使用实时页面参与原生动画；不更改系统动画倍率。

设置页同类反馈：全局Android显式ZoomPageTransitionsBuilder(allowSnapshotting:false)，其余平台沿用SDK默认。2项测试验证设置和个人码进入/返回动画处于中间进度且实际存在非单位缩放；analyze通过，APK构建并覆盖安装Success。视觉原因仍需用户确认，不将静态截图视为动态体验验收。

最终用户纠正：全部普通整页右入右退，注册/设置/二维码共享全局KingSlidePageTransitionsBuilder；取消之前Zoom解释和实现。个人码进入我的提前获取并合并并发请求，会话内用Stopwatch跟踪TTL且扣除网络耗时；session变化清除缓存及阻止迟到结果，二维码不持久化。8项测试通过（横向进入返回、缓存复用/失效/过期、布局、媒体路由检查），analyze无问题。首次网络未完成仍允许加载，不承诺离线首次签发。

速度微调：统一进入240ms、返回220ms；SettingsRoute显式MaterialPage且allowSnapshotting:false，与PersonalQrRoute一致。两页进退动画测试和analyze通过。
