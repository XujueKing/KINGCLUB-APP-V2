# Android 已接通通话后台服务

目标：为用户主动接听/发起后的单聊音视频采集提供 Android microphone/camera 前台服务；不用于后台唤起来电，也不改变已确认通话页面。

在 getUserMedia 权限通过后、建立媒体连接前启动前台服务，由原生 startForeground 成功后确认。服务启动要求 Activity 在前台；权限不足或启动失败终止本次媒体初始化并释放采集。挂断、登出、初始化失败统一停止服务。每次采集使用独立租约，旧通话清理不得停止新通话。

通知持续显示通话类型，点击返回 App；不显示对方私人资料。服务不自动重启，不在开机后启动，不恢复已结束的麦克风。服务声明 microphone/camera 与相应权限，Android 14+规则参考 https://developer.android.com/develop/background-work/services/fgs/declare 。

验证计划：租约取消/迟到启动测试、原生编译、手机通知/后台音频/挂断清理。未完成前不声称后台通话已交付；群通话及系统来电推送另行接入。

本次结果：实现已接入 NativeCallMedia；18项租约/媒体资源测试与定向静态检查通过，`:app:compilePreviewProfileKotlin`编译成功。尚未构建并安装本次手机包，Android12/15后台实测、通知权限体验及任务移除行为仍待验证。仅声明前台服务权限，没有把系统来电推送作为已完成能力。
