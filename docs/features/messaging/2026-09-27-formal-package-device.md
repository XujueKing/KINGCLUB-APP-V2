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
