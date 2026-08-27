# KC-P-046 旧版 UI 复刻规格

状态：Approved for Development（仅 UI / Fake）

## 复刻基线

- 旧版页面：`pages/about/about` 与 `pages/aggreement/index`。
- 关于页保留顶部标题、KingClub 标志、版本信息、说明文字、协议入口和主体信息。
- 法律文档阅读态保留旧版白色标题、灰白正文、分级章节和纵向滚动结构。

## 目录

- 用户协议
- 隐私政策
- 第三方 SDK 与权限说明
- 账号注销与数据处理说明

## UI/Fake 边界

- 目录、版本、生效日期和正文使用本地 Fake `DocumentRef`，不硬编码为生产权威文本。
- 页面明确标注“UI Mock，发布前以权威目录为准”。
- 不执行 HTML、脚本、任意 scheme 或外部链接；返回键从文档态回目录。
