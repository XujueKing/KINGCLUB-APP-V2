# Design QA — KC-P-017 用户主页旧版复刻

- source visual truth: `C:\Users\Poplar\Desktop\KingClub-app\pages\friendinfo\friendinfo.wxml`、`friendinfo.wxss` 及旧版 `images/` 资产
- implementation screenshot: `android_user_profile.png`
- implementation pixels: `1080 × 2400`
- app viewport: Android API 37 模拟器，竖屏，好友 `contact-lucas` 状态
- state: 从通讯录进入 / 好友 / 无弹层

## Full-view comparison evidence

- 实现已按旧版源码复刻黑色画布、左上返回、方形头像与右侧三行资料、朋友资料、朋友权限、发消息三段结构。
- 旧版 `600rpx` 内容宽度映射为左右约 46 logical px；`120rpx` 头像映射为 64 logical px；菜单 `100rpx` 高度映射为 54 logical px。
- Android 平台状态栏和底部 Home Indicator 属于平台框架，不纳入 App 内容比较。

## Focused comparison evidence

- Fonts and typography：名称 18sp、菜单 16sp、次要资料 13sp，层级和旧版 34/30/24rpx 对应；中文回退字体正常，无截断。
- Spacing and layout rhythm：头像资料区、43px 组间距、7px 菜单间隔均按旧版 100/80/14rpx 比例映射。
- Colors and visual tokens：主色使用旧版 `#C9B69E`，次要信息使用 50% 透明度，菜单使用旧版低透明黑金面板。
- Image quality and asset fidelity：头像、返回、右箭头和聊天图标均复用旧版项目资产，不使用临时占位图。
- Copy and content：保留“朋友资料”“朋友权限”“发消息”原文；按已批准隐私决策将永久会员号行改为公开昵称。

## Findings

- 当前实现截图未发现布局溢出、裁切、错误间距或不可用主动作。
- 阻塞项：旧版 `friendinfo` 的同状态运行截图当前不可获得，因此无法把“旧版运行截图 + Flutter 截图”放入同一视觉比较输入，不能宣称完成最终 1:1 视觉验收。

## Primary interactions tested

- 通讯录点击好友进入用户主页。
- 朋友资料打开本地公开资料弹层。
- 陌生人添加申请在 450ms Fake 提交后原子切换为等待验证。
- 返回路径有效；未请求真实资料、关系、消息或媒体服务。

## Comparison history

- 初次实机截图发现聊天图标使用通用 Material 图标。
- 已改为复用 `assets/legacy/navigation/tabBar_chat.png` 并重新截图；该资产差异已消除。

## Implementation Checklist

- [x] 旧版页面结构和尺寸比例
- [x] 旧版黑金色与图标资产
- [x] 好友和陌生人 Fake 主动作
- [x] 永久账号与敏感字段隐藏
- [x] Android 实机截图
- [x] Flutter analyze 与 widget tests
- [ ] 补充旧版同状态运行截图后完成并排视觉验收

final result: blocked
