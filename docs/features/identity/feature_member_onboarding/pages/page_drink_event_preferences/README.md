# 酒类与活动偏好页

- Scope ID：`KC-P-008`
- 文档状态：`Approved for Development`
- 所属功能：[会员注册、资料初始化与准入](../../README.md)
- 旧版来源：`regist5`
- 路由语义：`DrinkEventPreferencesRoute`
- 设计版本：`Onboarding Wireframe v2 / Step 4 / Adaptive Pill Catalog`
- 最后更新：2026-08-30

## 用户任务

选择酒类和活动偏好，复核提交说明，并以一次幂等动作提交完整会员申请；用户也可跳过偏好。

## 入口、出口与返回

- 入口：snapshot.stage=`preferencesRequired|readyToSubmit|changesRequired(preferences)`。
- 成功：服务端建立同一申请后 reset KC-P-009，不允许返回编辑栈。
- 返回：最终提交前回 KC-P-007；提交中禁止离开制造重复申请。
- 结果未知：拉取 snapshot；pending/已提交即进入 KC-P-009，否则恢复可提交状态。

## 线框

```text
[返回]                    步骤 4/4
完善兴趣偏好

酒类偏好（可多选/可跳过）
[选项] [选项] ...

希望参加的活动
[选项] [选项] ...

提交后资料将进入会员审核
[提交会员申请]        [跳过偏好并提交]
```

## 规则

- optionId、catalogVersion 和 draftVersion 一起保存，拒绝旧目录的未知选项。
- 两个提交按钮共用单一 SingleFlight 和 idempotencyKey；按钮 loading 保持原宽度。
- 提交前服务端检查实名、两张图片、目录版本和申请状态；客户端不自行宣布完整。
- 不因酒类选择推导饮酒资格；成年结论来自实名核验，所有页面仍遵循理性饮酒文案。
- Fake 目录必须完整覆盖旧版 regist5 的 8 项酒类、8 项活动，并补充 V2 常用分类；当前展示标签为：
  - 酒类：无酒精、威士忌、白兰地、伏特加、红葡萄酒、白葡萄酒、日本清酒、香槟、鸡尾酒、啤酒。
  - 活动：高级小礼服舞会、Cosplay 化妆舞会、明星见面会、网红狂欢舞会、校园社团专场、车友会专场、韩式小清新 Party、怀旧经典专场、现场音乐、DJ 主题夜、酒类品鉴、好友聚会。
- 每个选项使用稳定的 Fake optionId；展示标签不作为业务主键。
- 选项沿用 Step 3 的自适应流式胶囊，统一高度、自然换行、无前置圆圈的黑金选中态，不复刻旧版固定两列网格。
- “提交会员申请”主按钮使用完整胶囊圆角，与 Step 1～3 的主操作保持一致。
- 状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)。

## 验收

UI Mock 的状态流转说明必须位于“提交会员申请”和“跳过偏好并提交”两个正式操作之后，不得插入偏好选择与主按钮之间。

见 [acceptance.md](acceptance.md)。当前只实现 Fake 提交与审核跳转，不得调用真实提交接口。
