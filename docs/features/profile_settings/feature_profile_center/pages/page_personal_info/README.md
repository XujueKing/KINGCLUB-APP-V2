# 我的个人信息页

- Scope ID：`KC-P-047`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[个人中心与资料](../../README.md)
- 旧版来源：`pages/myinfo/myinfo`
- 路由：`PersonalInfoRoute`，`/me/settings/personal-info`
- 设计版本：`Mini Program Personal Info Replica v1`
- 最后更新：2026-09-12

## 用户任务

从“我的”页或设置页进入同一张小程序式个人信息页，查看自己的会员资料、公开评分、能量等级、账号信息，并进入允许修改的昵称、签名和支付密码流程。

## 页面结构

标准返回键与居中标题下方显示圆形头像；列表依次为会员称呼、签名、年龄/性别、颜值、能量值｜等级、灵根、手机号码、会员号、修改支付密码。仅会员称呼、签名和修改支付密码显示右箭头。“我的个人信息”不得再进入旧编辑封面页。

本期使用固定 Mock 投影复刻 UI。头像必须可点击选择系统相册图片、在页面内圆形裁切预览并保存到 App 私有目录；当前只做本地 UI/Fake 持久化，不上传服务器。交互见 [interactions.md](interactions.md)，状态见 [states.md](states.md)，验收见 [acceptance.md](acceptance.md)。
