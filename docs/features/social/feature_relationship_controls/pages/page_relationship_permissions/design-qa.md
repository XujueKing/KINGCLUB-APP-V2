# Design QA — KC-P-020 关系权限页旧版复刻

- source visual truth: `C:\Users\Poplar\Desktop\KingClub-app\pages\friendinfo3\friendinfo3.wxml`、`friendinfo3.wxss` 与旧版资产
- implementation screenshot: `android_relationship_permissions.png`
- implementation pixels: `1080 × 2400`
- viewport/state: Android API 37，竖屏，标准互动，三个开关关闭
- density normalization: 旧版 rpx 按 750rpx 设计宽度换算；Flutter 截图按 1080px 设备宽度检查相对比例

## Full-view comparison evidence

- 黑色画布、左上返回、居中“权限”、设置权限/朋友圈和状态分组及破坏性操作顺序与旧版源码一致。
- 标准/仅聊天单选、两个内容开关、黑名单开关和红色删除联系人均完整位于首屏。
- V2 增加的二次确认只在用户触发破坏性动作后出现，不改变默认页面外观。

## Focused comparison evidence

- Fonts and typography：标题 17sp、列表 15sp、分组 13sp，中文未换行。
- Spacing and layout rhythm：54 logical px 行高、10px 独立组间隔和 46px 左边距对应旧版比例。
- Colors and visual tokens：黑金列表、绿色开启开关和 `#FF7373` 删除文字与旧版定义一致。
- Image quality and asset fidelity：返回复用旧版资产；勾选和 Switch 使用 Flutter 平台图标控件，无自绘图形。
- Copy and content：保留旧版可见文案；确认弹层补充已批准的拉黑/删除后果。

## Findings

- Android 实现截图未发现 P0/P1/P2 布局问题。
- 阻塞项：没有旧版同状态运行截图，无法完成“旧版运行图 + Flutter 实现图”的并排视觉比较。

## Primary interactions tested

- 标准互动/仅聊天互斥切换、两个内容开关和黑名单开关可点击。
- 拉黑与删除分别显示不同确认文案，取消不会改变关系。
- 破坏性确认后的本地结果可回传用户主页；未访问真实关系服务。

## Comparison history

- 初次专项测试发现整行点击黑名单未触发 Switch。
- 已将整行纳入同一点击区域；修复后专项测试和全量测试通过。

final result: blocked
