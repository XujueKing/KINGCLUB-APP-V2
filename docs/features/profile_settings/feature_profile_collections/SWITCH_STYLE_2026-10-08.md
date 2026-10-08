# 全 APP 开关统一

用户要求会员状态及全部同类开关使用聊天详情“消息免打扰”的样式。本批以该控件为基准：Cupertino 胶囊轨道、白色圆形滑块，开启为绿色 `#07C160`，关闭为深灰 `#39393D`，使用原始尺寸，不在页面单独缩小、改色或显示滑块勾选图标。iOS 与 Android 均使用同一组件。

统一组件位于 `lib/src/core/design_system/king_switch.dart`。普通开关与带标题/说明的列表开关共享它。覆盖会员状态、单聊/群聊设置、好友权限、黑名单、组局招募/创建、门店日设置及后台接收消息设置。选项单选/多选及协议勾选维持各自语义。

保留现有值、权限、禁用/提交状态、确认弹窗和服务端动作，不因样式统一改变业务。全 lib 静态分析无问题；会员审核、聊天保存确认、群设置、关系权限、黑名单、组局、设置及付款恢复等现有交互回归共 86 项通过。全 lib 搜索不再有各页面直接创建的 Material/Cupertino 开关。

iPhone 第 171 版签名开发包构建成功，GitHub Actions 37679299223，源码 7c5f6c7d2fa2775b17ed9aaf618a03547906510c。工件摘要、IPA 完整性、Bundle ID、版本、签名资源和开发描述文件登记校验通过。2026-10-08 用户重新连接手机后 USB 安装成功，手机应用列表回读 `com.lingmei.kingclub`、`1.2.0`、`171`。不代表已上传 TestFlight，也不代表用户已完成真机视觉验收。

Android 第 171 版于 2026-10-08 构建成功，源码 `37ab309f8cbb4feefa9102f5a40a99c376ced484`。沿用 preview/profile、真实测试 API、腾讯地图、OPPO 客户端配置及已登记的 NovoRUDP 中继/ICE/LAN/文件传输配置；原生库使用已审查的 SUPERVM 固定版本。APK 回读包名 `com.lingmei.kingclub`、版本 `1.2.0-preview`、版本号 `171`，V2 签名及 Flutter/原生 ARM64 库检查通过。APK SHA256 为 `DBBE9CAE4374B0B968879878BE772A422D7770E04DBB599066AB485EBA9DB794`。构建日志在仓库外私有目录 `android171-build.log`，安装包保留在私有 `archived-apks/KINGCLUB-1.2.0-preview-171.apk`。

构建后安卓手机 USB 调试一度为 `unauthorized`，用户允许后确认设备为 OPPO PCLM50、ARM64，原安装第 153 版。使用 `adb install -r` 覆盖更新返回 `Success`，未卸载或清除账号和数据。随后系统包信息回读版本 `1.2.0-preview`、版本号 `171`，启动主页面成功。本轮为构建/覆盖安装与启动验证，不代替用户的具体业务及通知送达验收。
