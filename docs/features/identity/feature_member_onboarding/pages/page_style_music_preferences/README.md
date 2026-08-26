# 着装与音乐偏好页

- Scope ID：`KC-P-007`
- 文档状态：`Approved for Development`
- 所属功能：[会员注册、资料初始化与准入](../../README.md)
- 旧版来源：`regist4`
- 路由语义：`StyleMusicPreferencesRoute`
- 设计版本：`Onboarding Wireframe v1 / Step 3`
- 最后更新：2026-08-25

## 用户任务

选择自己感兴趣的着装风格和音乐类型，或明确跳过；这些偏好用于体验推荐，不作为实名或会员审核硬门槛。

## 入口、出口与返回

- 入口：snapshot 允许 `preferences` 且图片步骤完成。
- 下一步：保存 optionId + catalogVersion，进入 KC-P-008。
- 跳过：保存两个空集合和明确 skipped 状态，再进入下一页。
- 返回：回图片页；当前选择在进程内保留，已保存选择从 snapshot 恢复。

## 线框

```text
[返回]                    步骤 3/4
你的风格偏好
可多选，稍后可在个人资料中修改

着装风格
[选项] [选项] [选项] ...

音乐类型
[选项] [选项] [选项] ...

[下一步]              [暂时跳过]
```

## 规则

- 选项来自版本化目录，UI 不硬编码旧中文字符串为业务主键。
- 多选顺序不代表排名；V1 不设置最少/最多数量，服务端可返回受控上限。
- 目录刷新后停用项不可新选；已失效选择以提示方式移除，不静默换成其他项。
- 旧版 HOUSE、TECHNO、HIP-HOP 等仅作为 Fake 目录参考，最终文字由运营确认。
- 状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)。

## 验收

见 [acceptance.md](acceptance.md)。当前使用版本化 Fake 目录实现 UI，真实目录仍保持阻断。
