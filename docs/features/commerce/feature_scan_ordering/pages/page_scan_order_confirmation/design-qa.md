# Design QA — 点单确认页

- source truth：旧版 `pages/shoping2/shoping2.wxml`、`.wxss` 与已批准的点单确认文档
- implementation evidence：`audit/2026-08-29-device/02-ready.png` 至 `10-reconciled-order-created.png`
- viewport：Xiaomi 14 Pro，1080 × 2400 px
- state：KINGBAR 湖南工大店、V8 桌，两件商品本地报价

## 可见结果

- 保留旧版黑棕径向背景、居中金色标题、棕金圆角信息卡、商品明细和固定底部金额/主操作区。
- 商品图片、名称、规格、单价、数量、小计、优惠与应付金额在同一纵向核对路径中，底部提交区保持固定。
- 按批准差异移除旧版客户端优惠券、金币和余额手填分摊；支付方式只说明订单创建后选择。
- 价格变化使用红色差异卡和明确勾选，报价过期与结果确认中使用顶部状态条，同时禁用提交按钮。

## 修正记录

- P1：底部和提交成功结果暴露 `Fake Quote`、内部假订单编号及测试说明。
- 修复：全部改为正式产品文案，内部 Fake 类型与引用只保留在代码和测试层。
- 回归：默认、待支付、价格变化、报价过期和结果未知路径完成 Android 真机验收；专项测试 6/6 通过。

## 风险与限制

- 当前金额、优惠、倒计时和订单创建均为本地投影；真实超级接口、库存、PaymentIntent 和支付 SDK 仍受全局门禁阻断。
- 已取得旧版同状态截图并完成 v3 排版对照；生产报价和支付权威仍未接入。
- 200% 系统字体、横屏与屏幕阅读器完整朗读顺序仍需在全局无障碍验收轮次复测。

## 2026-08-29 v3 rework status

- 用户已提供旧版 `shoping2` 同状态截图并指出当前实现的字号、字重、卡片高度和间距偏大。
- 已冻结“保留完善内容、严格恢复旧版排版”的 v3 规则；新实机证据完成前，本页视觉门禁重新打开。

## v3 comparison evidence

- source visual truth：用户本轮图二及旧版 `pages/shoping2/shoping2.wxml`、`shoping2.wxss`、`app.wxss`
- implementation screenshots：`audit/2026-08-29-legacy-v3/01-confirm-pass1.png`、`02-confirm-lower.png`
- viewport：Xiaomi 14 Pro，1080 × 2400，约 432 × 960 logical px，density 2.5
- state：KINGBAR 湖南工大店 / 888 / 两件商品 / 商品总价 3710 / 优惠 30 / 应付 3680
- intentional content delta：按用户要求保留 V2 已完善的报价剩余、优惠、应付金额、状态异常和“订单创建后选择支付方式”；只复刻旧版排版，不恢复客户端手填金币/余额或直接判定支付成功

### Required fidelity surfaces

- Fonts and typography：标题 16sp/400；店名 16sp/400；商品名 15sp/400；英文/规格/单价 11sp；数量 11sp、小计 17sp/400；移除了上一版大面积 600～800 粗体。
- Spacing and layout rhythm：正文左右 12dp、卡间 10dp、卡内 15 × 11dp、圆角约 9dp；商品图 44 × 70dp，商品信息与数量/小计恢复旧版左右关系。
- Colors and tokens：径向黑棕背景、`#C9B69E` 卡片、深棕正文和黑色固定底栏保持旧版。
- Image and asset fidelity：两件商品继续使用旧版透明瓶图 `contain`，无黑色方形占位、裁切或卡片内图片底板。
- Copy and content：标题恢复 `提交订单`；商品三行、单价、数量、小计、商品总价和底部应付顺序与图二一致，新增安全内容集中在后续同风格卡片。

## v3 findings and history

- earlier P1：标题仍为“确认点单”，卡片值、商品名、小计和底栏文字普遍过粗过大，重复优惠/原价行把商品卡拉长。
- fix：恢复旧版标题；统一普通字重；将商品信息拆成旧版四行；商品卡只保留商品总价，优惠/应付集中到报价卡；底栏移除额外返回修改按钮，以顶部返回承担修改出口。
- post-fix evidence：`01-confirm-pass1.png` 和滚动后的 `02-confirm-lower.png`；完善内容可达，固定底栏无裁切，未发现剩余 P0/P1/P2。
- P3：报价剩余、报价确认和支付说明属于用户要求保留的 V2 内容，因此页面比旧版原图多一个紧凑信息层级。

## 2026-08-29 v3.1 rework status

- 用户指出信息卡右列数值没有共用右边界，更多控制的文案、字重和分隔线仍未复刻旧版图五。
- v3.1 规则已回写并完成 Android 真机复核。
- implementation screenshot：`audit/2026-08-29-legacy-v3.1/01-confirm-alignment.png`
- 信息卡三项值已共用右内边界；商品控制恢复 `隐藏更多（共2件物品）`、左右细线、普通字重和小箭头。
- 专项测试 7/7、相关 Dart 静态检查与 `git diff --check` 通过。

final result: passed

## 2026-08-29 v3.2 more-divider evidence

- source visual truth：用户本轮图二及旧版 `pages/shoping2`。
- implementation screenshot：`audit/2026-08-29-legacy-v3.2/01-more-divider.png`
- 最后一件可见商品不再绘制底边，更多控制上方的独立整行横线已移除。
- 商品之间仍有分隔线；更多文案左右两侧保留唯一一组旧版细线。
- 专项测试 7/7、相关 Dart 静态检查通过。

final result: passed
