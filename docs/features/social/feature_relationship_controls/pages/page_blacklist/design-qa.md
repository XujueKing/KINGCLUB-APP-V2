# Design QA — 黑名单页

- source visual truth: 旧版 `pages/blacklist/blacklist.wxml`、`blacklist.wxss` 和 `app.wxss` 可用；旧版同页运行截图暂缺
- implementation screenshot: `android_blacklist.png`
- implementation pixels: `1080 × 2400`
- app viewport: Android API 37 模拟器，约 `411 × 891` logical px，竖屏
- state: 列表就绪，3 个 Fake 用户，switch 均为开启
- density normalization: 无法执行；旧版只有 rpx 源码而缺少同状态可视截图

## Full-view comparison evidence

- Android 实现截图已打开检查：顶部栏、3 行列表、分隔线和 switch 全部可见，无溢出、裁切或 App Shell 底栏残留。
- 从旧版 WXML/WXSS 可核对的结构看，顺序、行组成、颜色和真实图标资产均已对应。
- 旧版运行截图不可用，无法把源视觉和实现截图放入同一比较输入，因此不声称已达到像素级 1:1。

## Focused comparison evidence

- Fonts and typography: 实现保留了香槟金标题、白色昵称、深灰日期和半透明白签名的旧版层级；精确光学字重待旧截图确认。
- Spacing and layout rhythm: 顶栏对应旧 690rpx 横排结构，列表行对应 120rpx，头像、文字和 switch 的左右关系清晰；像素间距待源截图确认。
- Colors and visual tokens: 黑背景、`#C9B69E` 全局文字、`#300716` 分隔线和 `#FBAFDA` switch 来自旧版源码。
- Image quality and asset fidelity: 顶栏返回/添加、通讯录黑名单图标和列表默认头像均直接复用旧版 PNG，未使用占位形状重画。
- Copy and content: 页面标题与旧版一致；用户数据明确为 Fake，不包含真实账号和隐私字段。
- Focused regions: 已单独检查顶栏图标/标题、首行头像/文字基线和 switch/分隔线；缺少源截图，未做像素差分。

## Findings

- [P2] 最终 1:1 视觉证据不完整。
  - Location: KC-P-021 整页。
  - Evidence: 旧版结构和样式源码可用，但没有旧版运行截图；Computer Use 本轮无法连接 Windows native pipe，未能从旧客户端补捕。
  - Impact: 无法严格证明字体光学尺寸、宿主状态栏差异和所有 rpx 间距已像素级一致。
  - Fix: 补一张旧版黑名单“列表就绪”同状态截图，然后与 `android_blacklist.png` 同帧对比并迭代。

## Comparison history

- Pass 1: 完成 Android 实现截图观察、旧版 WXML/WXSS 结构核对和真实资产核对。
- 当前未能进入有效视觉迭代：源截图缺失是唯一阻塞项。

## Implementation Checklist

- [x] 旧版顶栏和真实图标
- [x] 旧版列表密度、文字层级、分隔线与 switch
- [x] 通讯录黑名单入口
- [x] `blockedByMe` 用户资料路径
- [x] 解除后果确认与防重入
- [x] 本地 Fake 移除、刷新和空态
- [x] Android 竖屏截图
- [x] `flutter analyze` 和 Widget 测试

## Follow-up Polish

- 获得旧版截图后重点核对标题基线、首行起始高度、头像尺寸和 switch 缩放。

final result: blocked
