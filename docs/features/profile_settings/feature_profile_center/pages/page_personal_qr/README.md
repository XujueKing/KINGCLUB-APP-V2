# 个人二维码页

- Scope ID：`KC-P-042`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[个人中心与资料](../../README.md)
- 旧版来源：`pages/mycode/mycode`
- 路由语义：`PersonalQrRoute`，`/me/qr`，protectedShell/me 子路由
- 设计版本：`Mini Program Permanent Personal QR v2`
- 最后更新：2026-09-12

## 用户任务

向另一位 KingClub 用户出示与小程序一致的长期个人好友二维码，不显示时效或刷新入口。

## 已确认决定

- 用户于 2026-09-12 明确要求二维码“不需要时效，也要和小程序一样”。
- 该决定废止 2026-08-25 的短期邀请码方案；历史方案只保留在 `legacy_ui_replication.md` 供追溯，不再约束当前 UI。
- 当前只交付 UI/Fake 固定码，不接真实签发、刷新、撤销或好友关系接口。

## 入口、出口与返回

- 入口：我的主页“我的二维码”；路由不携带账号、token 或外部地址。
- 前置：authenticated + membership approved。
- 出口：仅返回我的主页；本页不承担扫码、好友预览或自动加好友。
- 生命周期：进入后台、恢复前台和普通页面重建都不改变二维码内容。

## 页面结构

```text
[返回]              我的二维码

          [头像] 会员号

       ┌────────────────────┐
       │                    │
       │    长期个人二维码   │
       │                    │
       └────────────────────┘

     扫一扫上面的二维码图案，加我成为朋友
```

## 二维码契约

- UI/Mock 阶段使用稳定的固定字符串生成二维码；页面重建与前后台切换后内容不变。
- 页面不显示倒计时、刷新、过期、离线或后台隐藏状态。
- 不提供保存到相册、系统分享、复制载荷、扫码或自由跳转入口。
- 真实好友二维码的数据格式、扫码解析和权限校验仍待接口契约批准后接入。

## 视觉与无障碍

- 身份区宽 `480rpx`，头像 `80rpx`，只显示会员号；二维码白底画布宽 `500rpx`，黑色码区约 `412rpx`，保留旧版四模块静区。
- 标题、身份区、二维码和说明文案按旧版 `pages/mycode` 的纵向节奏排列。
- 二维码中心仅使用 King Club 原始品牌素材，不以文字、Emoji 或手绘图形替代。
- 读屏描述说明这是“用于添加好友的个人二维码”，不朗读二维码原始内容。

## 当前验收

详细复刻规格见 [permanent_mini_program_qr_replication.md](permanent_mini_program_qr_replication.md)，页面状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
