# 首页

- Scope ID：`KC-P-011`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[首页聚合](../../README.md)
- 旧版来源：`pages/index/index` 首页逻辑
- 路由语义：`HomeRoute`，`/home`，protectedShell/home 分支根
- 设计版本：`Legacy Home Replica v1 / Component Content v1`
- 最后更新：2026-08-26

## 用户任务

先忠实复刻旧微信小程序首页的视觉与主要 Mock 交互，让旧用户在 Flutter App 中获得熟悉的首页体验；复刻验收后再单独评审改版。

## 入口、出口与返回

- 入口：App Shell 默认首页、点击首页 Tab、其他分支在根部按系统返回。
- 前置：authenticated + membership approved；不满足时由守卫 reset。
- 出口：批准的类型化 RouteIntent；未知活动动作不得导航。
- 返回：首页为分支根，不返回登录或准入；系统返回由 Shell 处理。

## 当前复刻方案

- 完整视觉、素材、布局、Fake 数据与验收规则见 [旧版首页 UI 复刻规范](legacy_ui_replication.md)。
- 每个组件内部内容、字段、图片文案和点击流程见 [首页组件内容复刻总表](components/README.md)。该内容包已获批准。
- 用户于 2026-08-26 撤回“先做新版首页”的实施顺序，要求先复刻旧版 UI，再考虑改版。
- 原 `Home Wireframe v1` 作为历史设计结论保留，不再作为当前实现依据。

## 视觉与布局

- 使用旧版纯黑背景、香槟金资产区、三联入口、两列海报瀑布流和悬浮胶囊底栏。
- 页面不绘制手机外框和微信宿主控件；底栏仍由 App Shell 提供，并复刻旧版五 Tab 视觉与语义。
- 360～430dp 宽度保持原比例；200% 字体时核心动作仍须可达。

## 页面组成

| 区域 | 内容 |
|---|---|
| Legacy Member Header | Logo、认证、等级、EXP、金币、钻石、进度条 |
| Hero Banner | 旧版比例的运营轮播图 |
| Legacy Quick Actions | 一起玩、组局玩、扫码三联入口 |
| Promotion Masonry | 两列运营海报流 |
| Legacy Shell Navigation | 五图标悬浮胶囊底栏 |

## 数据与隐私

- 问候昵称不是授权依据；不展示 `userAccount`、手机号或实名。
- 埋点仅记录 `home_view`、模块结果分类、固定 actionId 和耗时桶；不记录资源标题、二维码或服务端原文。
- 缓存只含清洗后的展示投影，并按会话世代隔离。

## 验收

页面状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。整体布局、组件内容与旧版五 Tab 语义已经确认，当前恢复 UI/Mock 开发；真实首页数据继续阻断。
