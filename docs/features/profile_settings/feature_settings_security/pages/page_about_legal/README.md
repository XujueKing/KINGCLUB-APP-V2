# 关于与法律文档页

- Scope ID：`KC-P-046`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[设置与账号安全](../../README.md)
- 旧版来源：`about/aggreement`
- 路由：`AboutLegalRoute`，`/me/settings/about`，可选 `$extra: DocumentRef`
- 设计版本：`Settings Wireframe v1 / About & Legal`
- 最后更新：2026-08-25

## 线框

```text
[返回]             关于 KingClub
[Logo] KingClub  v2.x.x (build xx)
用户协议                         >
隐私政策                         >
第三方 SDK/权限说明               >
账号注销与数据处理说明             >
运营主体 / 联系方式 / 备案信息

文档阅读态：标题 · 版本 · 生效日期 · 正文
```

目录与正文来自权威 DocumentRef；版本号来自构建元数据。状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
