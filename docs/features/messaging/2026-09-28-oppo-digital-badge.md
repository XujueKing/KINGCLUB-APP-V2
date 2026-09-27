# OPPO 数字角标接入与待咨询事项（2026-09-28）

## 已核实

- 用户要求保留数字模式，不改全局圆点设置。
- B：PKL110，ro.build.version.oplusrom=V15.0.0。系统数字模式开启；本应用通知渠道 mSupportNumBadge=false。
- 当前应用包名 com.lingmei.kingclub；OPPO 管理中心应用显示 KINGBAR，AppID 33364549，通知栏推送正式服务已开通。未查看或复制明文密钥。
- 官方文档已新增 ColorOS 16+ 自主数字角标：Manifest BADGE_DIGITAL 权限、ContentProvider setAppBadgeCount、用户主动授权。它与“数字角标默认开启”的特殊申请不同。不能沿用“所有版本一律白名单”的旧结论。
- 官方文档：
  https://open.oppomobile.com/documentation/page/info?id=13843
  https://open.oppomobile.com/documentation/page/info?id=13844

## 代码范围

- 添加 com.oplus.notification.permission.BADGE_DIGITAL。
- 对 OPPO/OnePlus/realme 调用公开的 content://com.android.badge/badge / setAppBadgeCount，Bundle app_badge_count；异常或 null 返回明确视为不支持/未启用，不伪报成功。
- 真实聊天未读回调同步计数；查看、标已读、清空导致计数变化时替换数值；退出账号清零。演示数据不写桌面。
- 只计聊天未读，未将营销、商品、金币、好友申请计入 OPPO 桌面数字角标。
- 尚未接通厂商离线 badge 字段以及跨设备离线已读清零；未取得 ColorOS 16 实机证据。
- B 的 ColorOS 15 不在新文档支持范围：安装新版 API 不等于 B 可以显示数字，需要厂家确认旧系统是否可开放。

## 待用户授权发送的客服咨询草稿（尚未发送）

您好，我们的应用 KINGBAR（产品内名称 KINGCLUB），包名 com.lingmei.kingclub，AppID 33364549，已开通 OPPO 通知栏推送。

我们需要为真实好友聊天与群聊的未读消息显示桌面数字角标，已对接标准通知并按最新文档开发 ColorOS 16 自主数字角标接口。测试机 PKL110 的系统版本为 ColorOS 15（V15.0.0），系统已选择数字角标，但本应用尚无数字角标支持。

请确认：
1. ColorOS 15 是否仍可申请本应用的数字角标权限？申请入口、适用条件和所需材料是什么？
2. 旧版本获准后支持哪些官方客户端设置/清零接口，是否仅支持 OPPO PUSH 下发？
3. 本应用正式通知栏推送已开通，数字角标权限是否必须另行开通？

我们希望保留用户的数字角标设置，不通过修改全局圆点模式规避问题。请提供目前有效的官方接入说明，谢谢。

## 本轮验证

- Dart analyze 通过，数字角标和后台生命周期 4 项定向测试通过；Android preview/profile 构建成功。
- A/B 已覆盖安装此版，无清除数据。B 原生调用日志记录实际计数 10→11，证明确实调用了官方接口；系统应用通知设置仍未显示本应用数字角标选项，不能把调用日志认定为桌面成功显示。
- B 仍保持数字模式，未开启/修改全局圆点。ColorOS 15 数字显示尚未解决；已向用户申请发送上述技术咨询的授权，收到明确授权前不发送。

## 旧版实机补查与结论修正

- 不能把 ColorOS 16 新文档的最低版本当作旧系统完全没有数字角标能力的证据。ShortcutBadger 的 OPPOHomeBader 在 2016 年已经调用相同 provider/method；更换该库并不会增加当前 A/B 的接口覆盖。
- 源码证据：https://github.com/leolin310148/ShortcutBadger/blob/master/ShortcutBadger/src/main/java/me/leolin/shortcutbadger/impl/OPPOHomeBader.java
- A（ColorOS 12.1）与 B（15）均实际存在 com.android.launcher/.BadgeProvider，authority=com.android.badge。
- 原先仅打印调用计数、吞掉异常的诊断不足。本次加入系统返回值和异常类型/原因记录，仅记录角标接口结果，不记录聊天或凭据。
- 原生 profile 构建通过，两端覆盖安装。保留现有 Flutter/媒体/传输二进制，安装前确认没有输入框草稿。
- 实机结果：A 04:43:27 count=6、B 04:42:42 count=11，provider 均返回 null，未抛出异常。该结果不能独立区分旧接口空返回约定、权限策略或桌面未更新，因此仍不标记适配成功，也不能声称已证明被白名单拒绝。
- 保留两端全局数字模式；未改系统权限数据库、未改其他 App、未发送客服咨询。下一步须查清旧版平台授权与通知计数路径，而不是仅继续重复同一调用。

## 后台通知计数修复

- 查明另一项独立缺陷：后台 Dart 调用 show 未传 unread，原生 Notification.number 恒为默认 1。现在从已鉴权会话行带入真实 unreadCount，替换同会话通知时替换计数，不按重试次数累加；来电 number=0，不充当未读消息。
- 加入真实计数 7→3 回归测试，相关 10 项测试通过。此修复不等于 OPPO 旧版数字角标授权或桌面展示已通过，也不等于厂商离线推送字段已完成。
- 查阅推送服务商第一方文档：腾讯云 https://cloud.tencent.com/document/product/548/43693 说明旧版数值展示仅对指定应用开启、需向官方申请；极光 https://docs.jiguang.cn/jpush/practice/set_badge 说明其 OPPO 厂商数字角标需申请权限并通过厂商下发。此证据支持继续核实平台授权，不应把接口存在视为应用自动有资格。
- 本轮代码测试通过后提交；尚未覆盖安装本轮 Dart 计数变更。客服咨询仍为草稿，未取得明确发送授权，未代用户发送。
