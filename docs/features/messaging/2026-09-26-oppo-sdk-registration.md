# OPPO 设备注册基础接入（未端到端完成）

使用已核实的官方 SDK 3.7.1 AAR，来源及 SHA-256 记录于 android/app/libs/README.md。未初始化即不注册，只有前台明确调用 kingclub/push-registration/register 才初始化 SDK 并尝试注册；限定 com.lingmei.kingclub。SDK 日志关闭，AppKey/AppSecret 由调用方另行传入，不包含真实凭据，不接收服务端 MasterSecret。

注册请求互斥，15 秒超时；回调检查包名、空 miniPackageName、成功码和 token，销毁后丢弃迟到结果。原生服务入口按官方要求由厂商签名权限保护。Flutter 桥接校验 provider/token，错误保留为失败。没有把 SDK 回调当成会员授权；后续必须通过当前登录态向服务端绑定。

验证：隔离工作树 APK 构建成功，包名校验和 NovoRUDP ARM64 检查通过（build/oppo-sdk-build.log）。Flutter 桥接 3 项测试通过；静态检查见 build/push-registration-analyze.log。APK 尚未安装，未提供真实客户端凭据、未真实注册、未发送推送。构建验证包含原生桥接，Flutter 新接口尚未接入业务调用。

仍需：客户端安全配置供应、推送 token 与当前设备会话绑定/解绑、可靠服务端发送、消息分类与通道、点击后的会话鉴权与路由、通知权限交互、来电过期处理及锁屏/进程回收实测。正式签名和预览跨包数据迁移也未解决。不得将此节点描述为离线通知已可用。
