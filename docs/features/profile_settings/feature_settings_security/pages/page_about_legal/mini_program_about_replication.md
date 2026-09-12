# 小程序关于 KINGBAR 复刻规格

- 文档状态：`Approved for Development`
- 用户视觉基准：2026-09-12 会话截图
- 旧版依据：`pages/about/about.wxml`、`about.wxss` 与 `images/logo_2.png`、`images/klztext.png`
- 交付范围：Flutter UI + 本地法律文档阅读态；不接真实 K107、外链或生产 SDK

## 固定视觉

- 黑色页面使用顶部偏中的暖棕径向光晕。
- 64dp 标题栏显示标准返回键与居中 `关于KINGBAR`。
- King Club 标志、品牌副标题、两段说明和备案信息均按旧版 `750rpx` 比例响应式换算。
- 《隐私政策》《用户协议》使用浅蓝色并带下划线；其余正文使用 80% 香槟金。

## 固定内容

技术支持、2025 版本号、软著认证、电子版权认证、APP/小程序 ICP 备案和软件开发商逐行展示，允许窄屏纵向滚动，不允许横向溢出。

## 原版法律阅读态

- 隐私政策标题栏固定为 `KINGBAR隐私政策`，正文首项为居中的 `《KINGBAR 隐私政策》`；用户协议标题栏固定为 `KINGBAR用户协议`，正文首项为居中的 `《KINGBAR 服务条款和规则》`。
- 正文容器宽 `650rpx`。主标题 `40rpx / 600 / white`，章节标题 `35rpx / white`，普通段落 `30rpx / #CCCCCC`，强调项目 `30rpx / 600 / #CCCCCC`。
- 主标题上 `60rpx`、下 `40rpx`；章节标题上 `45rpx`、下 `20rpx`；普通/强调段落上下各 `20rpx`。保持截图中的自然换行，不使用卡片、版本徽章或额外说明。
- 正文内容以旧版 `pages/aggreement/index.js` 的 `privacyConcat` 与 `userConcat2` 为本地视觉真值，并完整支持纵向滚动。
