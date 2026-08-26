# 组件：运营 Banner

- 文档状态：`Approved for Development`
- 组件 ID：`HOME-C02`
- 旧版来源：`index.wxml` 的 `AD` Swiper、`ad_bindtap`

## 首图内容

- 画面：深蓝黑背景、女性侧脸、右侧水晶艺术字、KingClub 品牌标记。
- 棕色横条：`招募兼职探店品鉴官`。
- 英文：`RECRUITING PART-TIME WORKERS`。
- 水晶艺术字与所有装饰文字都保留在 Banner 位图内，Flutter 不重复叠字。

## 数据契约

```text
LegacyCampaignBanner
  id
  bannerImageRef
  contentBlocks[]
  accessibilityLabel
  show
```

旧版动态项至少使用 `bannerImg` 与 JSON `content`；V2 Fake 不保留任意 HTML/URL，只把内容转换为受控 `contentBlocks`。

## 视觉与轮播

- 容器旧尺寸 `690×417rpx`，距两侧约 `30rpx`。
- `autoplay=true`、间隔 4000ms、切换 500ms、循环轮播。
- 指示点普通色 `#C9B69E60`，选中色 `#C9B69E`。
- 图片等比显示，不拉伸；圆角以用户截图为准。
- 系统开启减少动态效果时停止自动轮播，仍允许手势切换。

## 点击与详情

旧版点击将当前图片从卡片位置放大到屏幕宽度，再从下方拉起内容面板；内容来自当前项 `content`，关闭后图片缩回原位。

V2 Mock 复刻为：

1. 点击当前 Banner；
2. 展开同图顶部视觉；
3. 弹出可滚动的受控内容面板；
4. 点击关闭或系统返回；
5. 回到首页原滚动位置和原轮播页。

不得打开动态 URL，也不得连接真实运营接口。

## 验收

- [ ] 首图文案、人物方向、整体色调和内容密度与截图一致。
- [ ] 轮播时序与指示点一致。
- [ ] 点击可完成展开、阅读、关闭、返回原位的完整 Fake 流程。
- [ ] 图片失败时显示等高占位和可读替代文本。
