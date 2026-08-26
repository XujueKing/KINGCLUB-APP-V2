# 我的主页

- Scope ID：`KC-P-040`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[个人中心与资料](../../README.md)
- 旧版来源：`pages/index/index` 的“我的”分支
- 路由语义：`MyProfileRoute`，`/me`，protectedShell/me 分支根
- 设计版本：`Profile Center Wireframe v1 / Me / Legacy My Profile Replica v1`
- 最后更新：2026-08-26

## 用户任务

查看旧版会员主页信息，并进入资料编辑、个人二维码、等级、统计、资产和设置 Fake 流程。

## 入口、出口与返回

- 入口：App Shell“我的”Tab；重复点击当前 Tab 时回到顶部。
- 前置：authenticated + membership approved；不满足时由全局守卫 reset。
- 出口：`openEditProfile`、`openPersonalQr` 以及订单、资产、储物柜、设置的固定 RouteIntent。
- 返回：本页是“我的”分支根；系统返回由 App Shell 统一处理，不返回登录或准入页。

## 视觉基准

页面按 [旧版完整 UI 复刻规范](legacy_ui_replication.md) 和用户截图实现；不再使用此前的 Profile Center Wireframe v1 卡片式线框。

## 页面组成

| 区域 | 内容与约束 |
|---|---|
| Cover | 上海夜景封面、二维码、设置与 EXP |
| Identity | 空白头像、昵称、青铜等级、Fake 账号与复制 |
| Social | 获赞、关注、互关、粉丝以及编辑主页 |
| Assets | Fake 余额、金币和钻石入口 |
| Tags | 年龄、颜值、地区、星座、情感与灵根标签 |
| Content | 作品、动态、相册三项旧版内容区 |

## 显示边界

- 按已批准截图显示 Fake 账号、统计、颜值及资产样式，不读取真实个人数据。
- 手机号、实名、生日和真实统一身份标识仍不显示。
- 页面内账号、余额、金币和钻石均为固定 Fake 演示值。
- 真实服务接入前重新评审这些旧版展示字段，不把本轮 UI 批准视为生产授权。

## 视觉与无障碍

- 以旧版截图为视觉真值，使用上海夜景与深棕黑面板；不开放背景封面上传。
- 头像按用户确认保持无人物图像的纯空白圆形。
- 200% 字体下资料动作和服务入口允许改为单列，文本不得截断。
- 页面不复制 App Shell 底栏；线框底栏仅表示上下文。

## 数据与隐私

- 只消费清洗后的 `MyProfileSnapshot` 展示投影，不把服务端原始对象直接绑定 UI。
- 埋点只记录 `me_view`、固定 actionId、结果类别和耗时桶；不记录昵称、简介、城市、职业或头像 URL。
- 离线缓存按会话世代隔离，登出、账号切换或会话失效时清除。

## 验收

页面状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。本页离线 UI Mock 已完成；仍不允许真实服务接入。

## 2026-08-26 范围变更审计

用户已提供旧版运行截图并确认头像留空、其他功能全部复刻。当前 UI 以 [旧版完整 UI 复刻规范](legacy_ui_replication.md) 为准；范围与隐私变更记录见 [旧版完整内容复刻再审计](legacy_full_content_reaudit.md)。本轮仅授权离线 UI Mock，真实接入前重新评审敏感字段。
