# 入场凭证页

- Scope ID：`KC-P-033`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[入场凭证](../../README.md)
- 旧版来源：`ticket`
- 路由：`AdmissionTicketRoute`，`/club/admission`，`$extra: AdmissionRef + ScanContextRef?`
- 设计版本：`Admission Credential Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与线框

查看本人权威入场状态，在允许时间内向工作人员出示动态二维码，或对受控离场上下文作明确确认。

```text
[返回]              入场凭证              [帮助]

[状态：可入场 / 已入场 / 已离场 / 已失效]
8月25日 20:30—次日04:00
VIP 区 V11 · 套餐摘要

        [动态二维码]
       00:24 后更新
  请向工作人员出示，请勿截图或分享

[规则摘要]
仅限本人 / 有效时间 / 入场与再次入场说明

状态变体：
- 未到时间：将在 20:15 开放
- 已入场：21:03 已入场，不显示二维码
- 场内离场码：确认登记离场？      [取消] [确认离场]
- 离线/暂停：无法生成凭证         [请工作人员协助]
```

- 二维码区域之外必须有文本状态，读屏不朗读 token。
- 页面进入前台可请求临时提高亮度，退出后恢复；原生行为在 UI 阶段单独评审。
- 不提供截图、保存、分享、复制和显示永久编号。
- 200% 字体下二维码保持可扫描尺寸，其他信息纵向滚动，操作不遮挡状态。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
