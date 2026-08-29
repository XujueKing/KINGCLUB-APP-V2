# AA 卡座套餐详情页

- Scope ID：`KC-P-028`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[一起玩 AA 预订](../../README.md)
- 旧版来源：`order`
- 路由：`AaPackageDetailRoute`，`/club/aa/package`，`$extra: AaOfferRef`
- 设计版本：`AA Reservation Legacy Replica v2 / Package`
- 最后更新：2026-08-28

## 用户任务与旧版版式

理解所选营业日、卡座区域、套餐内容、服务端价格和活动规则，再决定是否进入确认订单。

```text
[旧版返回箭头]       POSITIONING CARD
[卡座字样/编号]
[营业日 20:30—04:00]
[套餐视觉区]
[套餐名称]
[两列套餐内容]
[套餐建议价]
[系统分桌与规则说明]

[米金固定底栏：当前报价]                   [深棕胶囊抢订]
```

- 复刻旧版 `order` 的居中内容、黑金径向背景、米金底栏和深棕“抢订”入口；页面禁止出现粉色、玫红或酒红主题色。
- 套餐视觉使用仓库内真实品牌素材；素材缺失时使用稳定图片错误态，不用空白占位框。
- 当前 Mock 主套餐固定复刻原版截图：`V5`、`2026-08-29 周六 20:30-04:00`、`3880卡座套餐`、10 人套餐、四档年龄价格、女神预订赠券说明、优惠价 `¥268.00` 与划线原价 `¥388.00`。
- 套餐海报使用从用户提供的原版截图提取的完整海报资产 `assets/legacy/aa/package_3880_v1.png`，禁止再用 King Logo、占位图或代码绘图替代。
- `POSITIONING CARD` 使用常规字重；卡座编号、日期、海报、套餐名、双列内容、建议价、年龄价格和两行说明按旧版纵向顺序与密度展示。
- “抢订”仅创建本地 Fake quote 并进入确认订单，不锁真实库存。

- 不展示旧版 18～23/24～29 等客户端计算价格表；只展示当前会员的服务端活动投影。
- 不展示颜值、同桌头像、性别比例或精确已订人数。
- 套餐内容、营业时间、政策和金额均可随刷新更新；页面不能承诺库存已锁定。
- 图片失败使用稳定占位，不阻塞阅读和继续。
- 长套餐内容、长规则和 200% 字体均纵向扩展；底部操作不遮挡正文。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## Android UI/Fake 实现证据

- 2026-08-27 已验证旧版 `POSITIONING CARD` 层级、卡座/时间、套餐视觉、内容网格、报价说明和粉金固定“抢订”底栏。
- 截图：[android_aa_package_legacy_replica_v2.png](android_aa_package_legacy_replica_v2.png)
- 刷新后价格变化：[android_aa_package_price_updated.png](android_aa_package_price_updated.png)
- 新价格已确认：[android_aa_package_price_acknowledged.png](android_aa_package_price_acknowledged.png)
- 刷新后售罄：[android_aa_package_sold_out.png](android_aa_package_sold_out.png)
- “抢订”只进入本地 Fake 确认订单，不创建真实 quote 或库存占位。
- 本轮验收截图：[2026-08-28 套餐详情主状态](../../qa/2026-08-28/02-package.png)；品牌素材、套餐内容、价格说明、固定底栏与返回路径均在当前构建重新验证。

## 刷新异常 Fake 状态补充

- 不增加常驻测试按钮，长按 `POSITIONING CARD` 标题打开本地验收状态面板。
- `priceUpdated`：显示粉金价格变化提示，底栏同步为新价格；用户必须先点“确认新价格”，按钮恢复“抢订”后再次点击才进入确认页。
- `soldOut`：详情正文保留只读，显示“刷新后该套餐已售罄”；底栏不再显示金额提交，按钮改为“返回列表”。
- 价格变化后进入确认页时只传递更新后的本地 Fake 套餐，不复用旧金额；真实接入后必须由报价引用替代。
- 状态面板、刷新与继续动作均不访问超级接口、库存或支付服务。
