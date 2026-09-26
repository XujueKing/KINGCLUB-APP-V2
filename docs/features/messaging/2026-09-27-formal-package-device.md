# 正式包名联调准备

从主仓 e7a90e2c 的已提交文件同步到隔离目录 KINGCLUB-CHAT-ROUTE-PREVIEW，未带入 onboarding 工作区修改。构建使用 profile / preview / arm64，包名 `com.lingmei.kingclub`；不是签名发布版。

- API：https://test.wuyexin.cn/kingclub-v2
- Relay：wss://test.wuyexin.cn/supervm/relay，沿用已登记 Ed25519 peer pin。
- 启用 ICE、LAN、个人与群文件传输，STUN test.wuyexin.cn:3478；本轮没有重新证明跨网络直连成功。
- NovoRUDP 使用 SUPERVM-KINGCLUB-PINNED 的固定源码；构建脚本包名与 ARM64 库检查通过。
- APK SHA256：1B1D84EC57EA1A68BEF2432DB61089EB53B115011D91BA5D2FAFE3C68D691F5F。
- 构建日志：隔离目录 build/push-formal-package-build.log；Gradle 77.1 秒，APK 164.2 MB。

A（462606d8）ADB 安装返回 Success，启动正式包成功。系统弹出通知授权，已允许；此为实际观察，不证明厂商 token 注册成功或本轮自动授权触发逻辑已走通。当前停在首次协议入口，已请用户自行确认协议并登录原测试会员。旧 `.v2preview` 未卸载，跨包数据未迁移。

B 当前前台为 commerce，因此本轮没有安装或切换 B。另一个无关 USB 设备没有操作。

未注入 OPPO 客户端凭据，真实系统离线推送未验收。控制台申请页面连续读取超时，未提交申请、未重置凭据、未付款。正式签名、凭据配置、IM 分类审批、后端推送迁移部署及锁屏/系统回收通知验收仍待完成。

## A 登录与通知设置实机验收

用户完成登录后，正式包首页和个人资料确认是原 A 测试账号。设备 Android API 31，因此本轮不证明 Android 13 首次授权流程。

进入“我的→设置→通知权限”，显示系统通知已允许。点击打开系统设置，系统日志显示标准 APP_NOTIFICATION_SETTINGS 经 Android 设置转入 OPPO AppNotificationSettingsActivity，页面标题为当前应用、允许通知开启。第一次立即读取抓到旧页面，后续系统日志和可见页面确认已跳转，未据此改代码。

关闭系统通知，返回应用后列表显示“通知权限／已关闭”，弹框也显示系统通知已关闭；再次从应用打开系统设置，重新开启，返回后列表显示“通知权限／已允许”。结束时通知开启，账号未退出。这证明 A 的真实状态读取、设置跳转及前台恢复刷新通过，不代表真实推送送达。

服务端只读核对：SSH 可用，聊天运行容器镜像前缀 8d0431d3abef，与旧 peer-media 部署脚本固定前置镜像不一致；本轮未切换容器或执行迁移，避免覆盖其他工作。

## 普通通知通道真实注册（后续进展，覆盖上述准备状态）

用户决定使用既有普通通知通道，不申请 IM 分类。客户端 AppKey/AppSecret 已从已登录控制台取得，保存在仓库外受限目录，通过 `PushConfigFile` 构建，未写入 Git；MasterSecret 不进入客户端。

- 配置版 APK SHA256：`92AFD71838399700849E04D812B4AE7BD2757BBC14CC1391AD4D9A98FD9DE4FB`。
- `build/push-configured-build.log`：Gradle 78.3 秒，构建成功，164.2 MB。
- A 覆盖安装返回 Success，启动后仍进入已登录首页，没有卸载或清空账号数据。
- 服务端 `kingclubPushDevice` 只读查询已出现 OPPO / `com.lingmei.kingclub` 设备绑定，更新时间为 `2026-09-26T17:32:36.478Z`。不记录设备 token、密钥或会员标识。

这证明客户端厂商注册与服务端绑定链路已走通，不证明通知已经送达。服务端普通推送代码及迁移已增量部署（后端提交 bbcb0d4），发送开关仍关闭，服务端鉴权配置、锁屏收取和系统回收后通知仍未验收。B 本轮未操作。

## A 后台进程终止后的重新注册

服务端确认无进行中的单聊/群聊通话后，将 A 正式包退至桌面，通过 `am kill com.lingmei.kingclub` 结束后台进程；第一次紧接退后台执行时进程仍在，确认桌面已前台后再次执行，`pidof` 无结果，未使用 force-stop、清数据或卸载。

再次从启动入口打开，PID 从 14829 变为 14871，UI 直接为已登录首页，没有登录/验证码入口。服务端推送绑定仍为一条，更新时间由 `2026-09-26T17:32:36.478Z` 更新为 `2026-09-26T17:41:49.729Z`，证明重建进程后会重新注册并幂等绑定。

此为受控结束后台进程后重新打开的恢复测试，不等同于操作系统真实低内存回收，也不证明进程不存在时收到推送或锁屏来电。后者仍待服务端配置及实际送达验证。
