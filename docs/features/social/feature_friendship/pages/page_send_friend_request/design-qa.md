# Design QA — 发送好友申请页

- source visual truth: 暂缺旧版 `createfriendinfo` 运行截图；当前只有 `pages/createfriendinfo/createfriendinfo.wxml` 与 `createfriendinfo.wxss`
- implementation screenshot: `android_send_friend_request.png`
- implementation pixels: `1080 × 2400`
- app viewport: Android API 37 模拟器，竖屏，系统字体缩放 100%
- state: 陌生人资料页点击“添加到通讯录”后，默认验证消息和默认备注已填充
- density normalization: 无法执行；旧版只有 rpx 结构样式，缺少同状态可视截图

## Full-view comparison evidence

- Android 实现截图已打开检查，页面无溢出、遮挡或持久操作区被隐藏。
- 从可验证的旧版源码结构看，实现保留了黑色背景、旧返回图标、居中标题、两组深灰输入框与底部宽“发送”按钮。
- 由于没有旧版同页截图，不能将两个可视产物组合后做 1:1 视觉比对。

## Focused comparison evidence

- Fonts and typography: 当前截图中层级清晰，文案与旧版 WXML 一致；字号和字重的最终一致性待旧截图确认。
- Spacing and layout rhythm: 实现使用等效 600rpx 内容宽度、90rpx 输入高度和大底部留白；精确垂直间距待旧截图确认。
- Colors and visual tokens: 黑色画布、`rgb(49,49,49)` 输入面、`#CCCCCC` 输入文字和 `#AAAAAA` 标签来自旧 WXSS；香槟金标题和按钮沿用已批准旧版全局语言。
- Image quality and asset fidelity: 返回图标直接复用旧版资产 `assets/legacy/friendship/back.png`，未使用手绘或占位图标。
- Copy and content: 标题、字段标签和“发送”均与旧版一致；隐私说明为 V2 安全补充，不改变主流程。
- Focused regions: 已检查标题/返回、两个输入框/计数器和底部按钮；因缺少旧版可视目标，未做像素差异判定。

## Findings

- [P2] 无法完成最终 1:1 视觉验收。
  - Location: 整个 KC-P-018 页面。
  - Evidence: 实现截图可用，但旧版同页运行截图不可用。
  - Impact: 无法证明字号、光学对齐和垂直间距已经像素级一致。
  - Fix: 补一张旧版 `createfriendinfo` 相同初始状态截图，然后与 `android_send_friend_request.png` 同帧比对并迭代。

## Comparison history

- Pass 1: 只完成 Android 实机模拟器截图检查和旧版 WXML/WXSS 结构核对。
- 未进入视觉修复循环：旧版同页可视真值缺失。

## Implementation Checklist

- [x] 旧版页面结构与文案
- [x] 旧版返回资产
- [x] 验证消息 0～80 字与备注 0～24 字
- [x] 防重复提交和本地 Fake 成功返回
- [x] 草稿放弃确认
- [x] 扫码好友资料→发送申请→等待验证路径
- [x] Android 竖屏截图
- [x] `flutter analyze`
- [x] Flutter widget tests

## Follow-up Polish

- 获得旧版页面截图后，重点检查标题基线、标签到输入框的间距和底部按钮位置。

final result: blocked
