# 旧版资产型“我的”页面复刻规范

- Scope ID：`KC-P-040`
- 文档状态：`Approved for Development`
- 设计版本：`Legacy Wallet Dashboard Replica v2`
- 用户视觉真值：2026-09-12 用户提供的“小程序我的页面”截图
- 源码依据：`KingClub-app / 5406b87 / 1.1.31` 的 `pages/index/index.wxml` 与 `index.wxss`
- 数据阶段：UI/Fake；不新增真实个人资料、资产或二维码接口

## 最新范围决定

用户于 2026-09-12 明确要求 Flutter “我的”页改成截图中的小程序样式，并包含页面内全部内容。本规范覆盖此前 `Legacy My Profile Replica v1` 的封面、头像、账号、统计、标签和作品/动态/相册布局；历史文档保留作审计记录，不再作为当前实现真值。

## 页面结构

1. 使用小程序原版顶部偏中的暖棕径向光晕背景，顶部只保留左侧设置齿轮；微信宿主右上胶囊不进入 Flutter App。
2. 居中显示 `总余额 (￥)` 与大号 `0.00`。
3. 双列显示 `钱包账户(元)`、`代金券账户(元)`，金额均为 `0.00`，中间使用细竖分隔。
4. 双列显示金币 `200` 与钻石 `0`，复用旧版 `gold.png`、`diamond.png`，中间使用细竖分隔。
5. 固定四行菜单：`我的二维码`、`我的个人信息`、`账单记录`、`关于KINGBAR`；复用旧版菜单图标和右箭头。
6. 页面由 App Shell 提供原版四项底栏（首页、消息、私人储物柜、我的），“我的”保持选中；页面自身不得复制第二套底栏。

## 750rpx 标尺

- 主内容宽度：`660rpx`，随页面宽度按 `width / 750` 换算。
- 顶部设置图标视觉尺寸：`42rpx`，点击区域不小于 48 逻辑像素。
- 标题：`30rpx`；总余额：`66rpx / 600`；分项金额：`36rpx`；分项说明：`24rpx`；菜单文字：`31rpx`。
- 资产图标：`36rpx`；右箭头：`12×19rpx`。
- 四行菜单不使用卡片底色或分割线，左右对齐一致，整行可点击。

## 入口映射

| 可见入口 | Flutter 目标 |
|---|---|
| 左上设置 | `SettingsRoute` |
| 总余额、钱包账户、代金券账户 | `AssetLedgerRoute(cashBalance)` |
| 金币 | `AssetLedgerRoute(goldCoin)` |
| 钻石 | `AssetLedgerRoute(diamond)` |
| 我的二维码 | `PersonalQrRoute` |
| 我的个人信息 | `EditProfileRoute` |
| 账单记录 | `AssetLedgerRoute(cashBalance)` |
| 关于KINGBAR | `AboutLegalRoute` |

## 状态与安全边界

- 当前金额和数量是截图验收用 Fake 数据，不冒充真实会员资产。
- 所有入口必须可打开、可返回，并回到“我的”Tab。
- 不展示永久账号、实名信息、颜值、关系统计或用户媒体。
- 不因本次 UI 改版新增 HTTP、WebSocket、支付、上传或生产 SDK。
- 小屏或大字体可纵向滚动，底栏不得遮挡最后一项菜单。
