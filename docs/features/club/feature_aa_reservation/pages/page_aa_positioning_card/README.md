# AA 已揭晓卡座定位凭证页

- 所属功能：一起玩 AA 预订
- 文档状态：`UI Mock Implemented`
- M0 范围：`In Release Scope`（KC-P-027 已确认预订的后续页面）
- 旧版来源：`pages/ticket/ticket.wxml`、`ticket.wxss`、`ticket.js`
- 路由：`AaPositioningCardRoute`，`/club/aa/positioning-card`
- 设计版本：`Legacy Positioning Card Replica v1`
- 最后更新：2026-08-31

## 用户任务

已确认预订在营业日前一天进入揭晓窗口后，会员查看系统随机分配的本人卡座，并向工作人员出示动态二维码入场。

## 旧版视觉结构

```text
[返回]                 POSITIONING CARD

[紫色径向渐变大卡]
                888
          POSITIONING CARD
       2026-08-27 20:30-04:00
       [男女席位占位矩阵 2×5]

       [白底黑色动态二维码]
             K24500000299
              3880卡座套餐
             单人票价：388元

STORAGE INSTRUCTIONS:
1、着装邋遢，大量纹身外露会被拒绝进入；
2、套餐内无需再付费，套餐外点单需另付费；
3、此入场码只限当天使用，使用过后即作废；
```

## 复刻规则

- App 自有内容严格按用户提供的旧版截图和稳定源码复刻；不复制微信右上角胶囊和系统状态栏。
- 背景为深酒红径向渐变；主卡为 `#5A1E80 → #AD016A` 紫红径向渐变，圆角约 `20rpx`。
- `888` 使用大号白色衬线展示字；其余主卡文字为旧版浅粉金。
- 十席矩阵为两行五列，使用旧版 `man.png / man2.png / woman.png`，第一席为当前会员高亮，其余为半透明占位。
- 二维码为白底黑码，中心使用旧版 `kingLogo.png`；UI Mock 生成轮换 Fake token，不使用长期可复用生产值。
- 页面不显示“当前可入场”、倒计时、帮助按钮或通用状态胶囊，避免破坏旧版结构。
- 本页不能从新建预订、报价、待支付或未揭晓订单直接进入；未到 `revealAt` 时只展示待揭晓投影。

## 数据投影

- `tableLabel = 888`
- `serviceDate = 2026-08-27`
- `sessionTime = 20:30-04:00`
- `memberCode = K24500000299`
- `packageName = 3880卡座套餐`
- `unitPrice = 388元`
- `seatSlots = 10`，仅含性别图标与占用/本人状态，不包含真实同桌身份

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## UI Mock 实现记录

- AA 日期栏选择 `周四 08.27` 后显示旧版紫色 `888` 定位卡；其他日期保持未预订态。
- 点击定位卡进入 `/club/aa/positioning-card`，返回键回到 AA 预订列表。
- 完整凭证页已包含十席矩阵、动态 Fake 二维码、会员号、套餐、单人票价和旧版入场说明。
- Android 实机证据：`audit/2026-08-29/01-reservation-list-positioning-card.png`、`02-positioning-card-page.png`。
- 当前仍为 UI/Mock；真实订单查询、动态票据签发和门店核销保持阻断。
