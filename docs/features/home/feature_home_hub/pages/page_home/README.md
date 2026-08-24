# 首页

- Scope ID：`KC-P-011`
- 文档状态：`In Review`
- M0 范围：`In Release Scope`
- 所属功能：[首页聚合](../../README.md)
- 旧版来源：`pages/index/index` 首页逻辑
- 路由语义：`HomeRoute`，`/home`，protectedShell/home 分支根
- 设计版本：`Home Wireframe v1`
- 最后更新：2026-08-25

## 用户任务

快速确认当前到店语境和最近行程，并在不浏览复杂菜单的情况下进入 AA、VIP、入场或扫码主任务。

## 入口、出口与返回

- 入口：App Shell 默认首页、点击首页 Tab、其他分支在根部按系统返回。
- 前置：authenticated + membership approved；不满足时由守卫 reset。
- 出口：批准的类型化 RouteIntent；未知活动动作不得导航。
- 返回：首页为分支根，不返回登录或准入；系统返回由 Shell 处理。

## 线框

```text
[KINGCLUB]                       [当前门店/城市]
晚上好，会员昵称

[一起玩 AA] [VIP 组局]
[入场凭证]  [安全扫码]

今晚行程
[状态 · 时间 · 标题                         >]

精选活动
[活动卡片] [活动卡片]

[服务提示 / 更新时间]
-------------------------------
首页  消息   [扫码]  发现  我的
```

## 视觉与布局

- 使用 Design System v1 黑曜石背景与香槟金强调色；金色只强调主动作/状态，不作为大段正文。
- 四个核心入口在 360px 宽度保持 2×2；200% 字体时允许纵向扩展，不截断任务名称。
- 精选活动图片使用固定比例和语义占位；减少动态效果时停止自动轮播。
- 页面不复制底部导航；线框中的底栏由 App Shell 提供。

## 页面组成

| 区域 | 内容 |
|---|---|
| Brand Header | 品牌、问候、非敏感当前门店/城市 |
| Primary Actions | AA、VIP、入场、扫码固定入口 |
| Upcoming Journey | 最相关的一条行程或空态 |
| Featured Cards | 0～5 个受控运营卡片 |
| Service Notice | 可选稳定类别提示与更新时间 |

## 数据与隐私

- 问候昵称不是授权依据；不展示 `userAccount`、手机号或实名。
- 埋点仅记录 `home_view`、模块结果分类、固定 actionId 和耗时桶；不记录资源标题、二维码或服务端原文。
- 缓存只含清洗后的展示投影，并按会话世代隔离。

## 验收

页面状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。当前仍不得实现 UI 或接真实首页数据。
