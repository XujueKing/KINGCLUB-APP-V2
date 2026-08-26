# 首页组件内容复刻总表

- Scope ID：`KC-P-011-CONTENT`
- 文档状态：`Approved for Development`
- 设计版本：`Legacy Home Component Content v1`
- 复刻基线：旧版 `master / 505d222 / 1.1.37` + 用户提供的首页截图
- 最后更新：2026-08-26

## 目的

本轮不改变已批准的首页布局，只补齐首页每个组件内部的真实内容、字段、素材、状态和点击结果。本文档及五个组件文档获用户确认前，暂停继续修改首页 Flutter UI。

## 证据优先级

1. 用户提供的旧版首页截图：视觉、首屏文案与内容密度的最终基线。
2. 旧版 `pages/index/index.wxml`、`index.wxss`、`index.js`：字段、条件、尺寸、动画和点击行为的最终基线。
3. 旧版真实 PNG：Logo、性别、认证、资产、入口纹样与底栏图标的最终素材。
4. 动态 Banner/海报原图不在仓库内；现阶段可用生成图只属于 `mock/generated`，不得视为原运营定稿。

## 组件目录

| 顺序 | 组件 | 文档状态 | 内容重点 |
|---|---|---|---|
| 1 | [会员头部](component_member_header/README.md) | Approved for Development | 昵称、性别、等级、EXP、认证、金币、钻石、进度 |
| 2 | [运营 Banner](component_campaign_banner/README.md) | Approved for Development | 首图文案、轮播、展开详情 |
| 3 | [三联快捷入口](component_quick_actions/README.md) | Approved for Development | 一起玩、组局玩、扫码的原文与原顺序 |
| 4 | [运营内容瀑布流](component_promotion_masonry/README.md) | Approved for Development | 纯海报、图文、视频三种内容模式 |
| 5 | [旧版底部导航](component_legacy_bottom_navigation/README.md) | Approved for Development | 五个目的地、图标、徽标与选中态 |

## 首屏固定 Mock 内容

| 区域 | 固定内容 |
|---|---|
| 会员头部 | 昵称 `青铜`、男性图标、等级 `L-0`、`EXP:50`、金币 `50`、钻石 `0` |
| Banner | `招募兼职探店品鉴官`、`RECRUITING PART-TIME WORKERS`，水晶字主视觉按截图保留在图片内 |
| 快捷入口 | `一起玩 / TOGETHER PLAY`、`组局玩 / EXCLUSIVE SEATS`、二维码底纹 + 扫码框 / `SCAN QR`；第三项不加中文“扫码” |
| 海报 1 | `谁是最帅小哥哥`、`投稿有奖`、`HANDSOME MAN` |
| 海报 2 | `AI卡颜局`、`男女会员1:1随机组局`、`新玩法` |
| 海报 3 | `生日有礼`、截图中的会员生日权益副标题 |
| 海报 4 | `玩音乐能赚钱` |
| 底栏 | 首页、消息与通讯录、内容、私人储物柜、我的；只显示旧图标，不新增文字标签 |

> 海报/Banner 内艺术字属于图片像素，不在 Flutter 上重复叠文字。第三张海报的小字因截图清晰度不足，列为实机/原图待核验，不允许凭猜测定稿。

## 已确认事实

- Flutter App 不绘制微信右上角胶囊，也不绘制设备外框、系统状态栏或 Home Indicator。
- 首页仍使用旧版顺序：会员头部 → Banner → 三联入口 → 两列内容流。
- 中央白底粉色爱心是“内容”Tab，不是扫码。
- 当前只做 UI/Fake；不调用旧超级接口、新超级接口、WebSocket、相机、支付或生产 SDK。

## 当前建议

- 首个 `ready` 场景严格固定为用户截图中的内容，避免随机数据影响视觉验收。
- 旧版 `mode=0` 图文卡和 `mode=2` 视频卡保留为后续 Mock 场景，以验证组件完整性；首屏截图仍使用四张 `mode=1` 纯海报。
- Banner/海报点击先复刻“图片展开 + 内容面板 + 关闭返回原位”的 Fake 详情，不直接跳任意网页。

## 待核验

- 动态运营 Banner 与四张海报的原始无损图片。
- 第三张生日海报副标题的精确文字。
- 旧线上 `tabData` 每个目的地的实际 `src/src_choose` 返回顺序；本地可先按截图和旧 PNG 映射。
- Computer Use 本地管道当前不可用，尚未完成实机逐项点击取证。

## 批准门禁

用户于 2026-08-26 明确确认：按旧版样式使用 Fake 内容先完善 UI，整套 UI 完成后才接服务器。该确认批准本组件内容版本进入 UI/Mock 开发。

用户确认本总表和五个组件文档后：

1. 文档改为 `Approved for Development`；
2. 首页恢复 UI/Mock 实现；
3. 每完成一个组件都用同一视口截图与参考图对照；
4. 组件内容全部通过后，再恢复首页整体 `design-qa`。
